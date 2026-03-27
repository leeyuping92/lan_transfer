import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';
import '../utils/constants.dart';
import '../utils/network_utils.dart';

/// 设备发现服务 - 多重发现机制
/// 解决 LocalSend 找不到设备的问题
class DeviceDiscoveryService {
  // 单例
  static final DeviceDiscoveryService _instance =
      DeviceDiscoveryService._internal();
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._internal();

  // 发现回调
  final StreamController<Device> _onDeviceFound =
      StreamController<Device>.broadcast();
  final StreamController<Device> _onDeviceLost =
      StreamController<Device>.broadcast();

  Stream<Device> get onDeviceFound => _onDeviceFound.stream;
  Stream<Device> get onDeviceLost => _onDeviceLost.stream;

  // 已知设备列表
  final Map<String, Device> _devices = {};

  // 服务状态
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // 本机信息
  String? _localIp;
  int _localPort = AppConstants.discoveryPort;

  // UDP 广播套接字
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  // mDNS 相关（简化版，使用 DNS-SD 查询）
  HttpServer? _mdnsServer;

  // 当前配置
  bool _enableMdns = true;
  bool _enableUdp = true;
  String? _deviceId;
  String? _deviceName;
  String? _deviceType;

  /// 启动发现服务
  Future<void> start({
    required String deviceId,
    required String deviceName,
    required String deviceType,
    int port = AppConstants.discoveryPort,
    bool enableMdns = true,
    bool enableUdp = true,
  }) async {
    if (_isRunning) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _deviceType = deviceType;
    _localPort = port;
    _enableMdns = enableMdns;
    _enableUdp = enableUdp;

    _localIp = await NetworkUtils.getLocalIp();
    if (_localIp == null) {
      throw Exception('无法获取本地 IP 地址');
    }

    _isRunning = true;

    // 启动各项发现服务
    if (_enableUdp) {
      await _startUdpDiscovery();
    }

    // 启动定期广播（让其他设备知道我们在线）
    _startBroadcastTimer();

    // 启动清理定时器（移除超时设备）
    _startCleanupTimer();

    // 立即广播一次
    await _broadcastAnnounce();
  }

  /// 停止发现服务
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    _mdnsServer?.close();

    _udpSocket = null;
    _mdnsServer = null;
    _broadcastTimer = null;
    _cleanupTimer = null;
    _devices.clear();
  }

  /// 更新配置
  void updateConfig({
    bool? enableMdns,
    bool? enableUdp,
  }) {
    if (enableMdns != null) _enableMdns = enableMdns;
    if (enableUdp != null) _enableUdp = enableUdp;
  }

  // ========== UDP 发现实现 ==========

  /// 启动 UDP 发现
  Future<void> _startUdpDiscovery() async {
    try {
      // 绑定 UDP 端口用于接收广播
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _localPort,
        reuseAddress: true,
        reusePort: true,
      );

      _udpSocket!.broadcastEnabled = true;

      // 监听数据
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleUdpMessage(datagram);
          }
        }
      });

      print('[UDP] 监听端口: $_localPort');
    } catch (e) {
      print('[UDP] 启动失败: $e');
      // 尝试使用随机端口
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        _udpSocket!.broadcastEnabled = true;
        _udpSocket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _udpSocket!.receive();
            if (datagram != null) {
              _handleUdpMessage(datagram);
            }
          }
        });
        print('[UDP] 使用随机端口: ${_udpSocket!.port}');
      } catch (e2) {
        print('[UDP] 完全失败: $e2');
      }
    }
  }

  /// 处理 UDP 消息
  void _handleUdpMessage(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final message = jsonDecode(data) as Map<String, dynamic>;

      final type = message['type'] as String?;
      final remoteIp = datagram.address.address;

      // 忽略自己的消息
      if (message['id'] == _deviceId) return;

      switch (type) {
        case 'ANNOUNCE':
        case 'DISCOVERY':
          // 发现新设备
          final device = Device.fromMessage(message, remoteIp);
          _addOrUpdateDevice(device, DeviceSource.udp);
          break;

        case 'PING':
          // 响应 ping
          final port = message['port'] as int?;
          if (port != null) {
            _sendPong(remoteIp, port);
          }
          break;

        case 'PONG':
          // 收到 pong，说明设备在线
          final device = Device.fromMessage(message, remoteIp);
          _addOrUpdateDevice(device, DeviceSource.udp);
          break;

        case 'OFFLINE':
          // 设备离线
          final deviceId = message['id'] as String?;
          if (deviceId != null && _devices.containsKey(deviceId)) {
            final device = _devices[deviceId]!;
            _devices.remove(deviceId);
            _onDeviceLost.add(device);
          }
          break;
      }
    } catch (e) {
      // 忽略无效消息
    }
  }

  /// 添加或更新设备
  void _addOrUpdateDevice(Device device, DeviceSource source) {
    // 过滤掉自己
    if (device.id == _deviceId) return;

    // 检查设备是否已存在
    if (_devices.containsKey(device.id)) {
      // 更新最后在线时间
      final existingDevice = _devices[device.id]!;
      if (!existingDevice.isTimeout) {
        // 如果设备没有超时，只更新时间戳
        _devices[device.id] = existingDevice.copyWithUpdate();
      }
    } else {
      // 新设备
      _devices[device.id] = device;
      _onDeviceFound.add(device);
      print('[发现] 新设备: ${device.name} (${device.ip}) 来源: $source');
    }
  }

  /// 广播设备公告
  Future<void> _broadcastAnnounce() async {
    if (_udpSocket == null || _localIp == null) return;

    final message = {
      'type': 'ANNOUNCE',
      'id': _deviceId,
      'name': _deviceName,
      'port': _localPort,
      'deviceType': _deviceType,
      'protocolVersion': AppConstants.protocolVersion,
      'source': DeviceSource.udp.name,
    };

    final data = utf8.encode(jsonEncode(message));

    // 获取广播地址
    final broadcastIp = await NetworkUtils.getBroadcastAddress() ?? '255.255.255.255';

    try {
      _udpSocket!.send(
        data,
        InternetAddress(broadcastIp),
        _localPort,
      );
    } catch (e) {
      print('[广播] 失败: $e');
    }
  }

  /// 发送 PING
  Future<void> _sendPing(String targetIp, int port) async {
    if (_udpSocket == null) return;

    final message = {
      'type': 'PING',
      'id': _deviceId,
      'name': _deviceName,
      'port': _localPort,
      'deviceType': _deviceType,
    };

    try {
      _udpSocket!.send(
        utf8.encode(jsonEncode(message)),
        InternetAddress(targetIp),
        port,
      );
    } catch (e) {
      // ignore
    }
  }

  /// 发送 PONG
  Future<void> _sendPong(String targetIp, int port) async {
    if (_udpSocket == null) return;

    final message = {
      'type': 'PONG',
      'id': _deviceId,
      'name': _deviceName,
      'port': _localPort,
      'deviceType': _deviceType,
    };

    try {
      _udpSocket!.send(
        utf8.encode(jsonEncode(message)),
        InternetAddress(targetIp),
        port,
      );
    } catch (e) {
      // ignore
    }
  }

  // ========== 广播定时器 ==========

  /// 启动广播定时器
  void _startBroadcastTimer() {
    // 每隔几秒广播一次，让其他设备发现自己
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: AppConstants.discoveryInterval),
      (_) => _broadcastAnnounce(),
    );
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    // 定期清理超时设备
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupTimeoutDevices(),
    );
  }

  /// 清理超时设备
  void _cleanupTimeoutDevices() {
    final timeoutDevices = <Device>[];
    for (final entry in _devices.entries) {
      if (entry.value.isTimeout) {
        timeoutDevices.add(entry.value);
        _devices.remove(entry.key);
      }
    }

    for (final device in timeoutDevices) {
      _onDeviceLost.add(device);
      print('[清理] 移除超时设备: ${device.name}');
    }
  }

  // ========== 公共方法 ==========

  /// 手动添加设备
  Future<Device?> addManualDevice(String ip, int port) async {
    if (!NetworkUtils.isValidIp(ip)) {
      throw Exception('无效的 IP 地址');
    }

    if (!NetworkUtils.isValidPort(port)) {
      throw Exception('无效的端口号');
    }

    // 尝试 ping 设备获取信息
    _sendPing(ip, port);

    // 创建一个待确认的设备对象
    final device = Device(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: '手动添加 ($ip)',
      ip: ip,
      port: port,
      deviceType: 'unknown',
      source: DeviceSource.manual,
    );

    _addOrUpdateDevice(device, DeviceSource.manual);
    return device;
  }

  /// 获取所有已发现设备
  List<Device> getDevices() {
    return _devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 根据 ID 获取设备
  Device? getDevice(String id) {
    return _devices[id];
  }

  /// 获取本地 IP
  String? get localIp => _localIp;

  /// 获取本地端口
  int get localPort => _localPort;

  /// 扫描特定 IP（尝试连接）
  Future<Device?> scanIp(String ip, int port) async {
    if (_udpSocket == null || !NetworkUtils.isValidIp(ip)) {
      return null;
    }

    // 发送 PING 并等待响应
    final completer = Completer<Device?>();

    // 设置超时
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    // 发送 ping
    _sendPing(ip, port);

    // 监听响应
    final subscription = onDeviceFound.listen((device) {
      if (device.ip == ip && device.port == port) {
        if (!completer.isCompleted) {
          completer.complete(device);
        }
      }
    });

    return completer.future.whenComplete(() => subscription.cancel());
  }

  /// 广播离线消息
  Future<void> broadcastOffline() async {
    if (_udpSocket == null || _deviceId == null) return;

    final message = {
      'type': 'OFFLINE',
      'id': _deviceId,
    };

    try {
      final broadcastIp = await NetworkUtils.getBroadcastAddress() ?? '255.255.255.255';
      _udpSocket!.send(
        utf8.encode(jsonEncode(message)),
        InternetAddress(broadcastIp),
        _localPort,
      );
    } catch (e) {
      // ignore
    }
  }
}