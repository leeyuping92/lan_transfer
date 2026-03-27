import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/device_discovery_service.dart';

/// 设备状态提供器
class DevicesProvider extends ChangeNotifier {
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();

  List<Device> _devices = [];
  bool _isDiscovering = false;
  bool _hasPermission = false;
  String? _localIp;
  String? _errorMessage;

  StreamSubscription<Device>? _foundSubscription;
  StreamSubscription<Device>? _lostSubscription;

  List<Device> get devices => _devices;
  bool get isDiscovering => _isDiscovering;
  bool get hasPermission => _hasPermission;
  String? get localIp => _localIp;
  String? get errorMessage => _errorMessage;

  /// 初始化
  Future<void> init({
    required String deviceId,
    required String deviceName,
    required String deviceType,
    bool enableMdns = true,
    bool enableUdp = true,
  }) async {
    // 订阅设备发现事件
    _foundSubscription = _discoveryService.onDeviceFound.listen((device) {
      _addOrUpdateDevice(device);
    });

    _lostSubscription = _discoveryService.onDeviceLost.listen((device) {
      _removeDevice(device);
    });
  }

  /// 启动发现
  Future<void> startDiscovery({
    required String deviceId,
    required String deviceName,
    required String deviceType,
    int port = 41270,
    bool enableMdns = true,
    bool enableUdp = true,
  }) async {
    if (_isDiscovering) return;

    _errorMessage = null;
    _isDiscovering = true;
    notifyListeners();

    try {
      await _discoveryService.start(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        port: port,
        enableMdns: enableMdns,
        enableUdp: enableUdp,
      );

      _localIp = _discoveryService.localIp;
      _hasPermission = true;
      _isDiscovering = true;
      _devices = _discoveryService.getDevices();
    } catch (e) {
      _errorMessage = e.toString();
      _isDiscovering = false;
    }

    notifyListeners();
  }

  /// 停止发现
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    await _discoveryService.broadcastOffline();
    await _discoveryService.stop();

    _isDiscovering = false;
    _devices = [];
   notifyListeners();
  }

  /// 更新配置
  void updateConfig({
    bool? enableMdns,
    bool? enableUdp,
  }) {
    _discoveryService.updateConfig(
      enableMdns: enableMdns,
      enableUdp: enableUdp,
    );
  }

  /// 刷新设备列表
  void refreshDevices() {
    _devices = _discoveryService.getDevices();
    notifyListeners();
  }

  /// 手动添加设备
  Future<Device?> addManualDevice(String address) async {
    try {
      final parts = address.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 41271 : 41271;

      final device = await _discoveryService.addManualDevice(ip, port);
      if (device != null) {
        _addOrUpdateDevice(device);
      }
      return device;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 扫描特定 IP
  Future<Device?> scanIp(String ip, {int port = 41270}) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final device = await _discoveryService.scanIp(ip, port);
      if (device != null) {
        _addOrUpdateDevice(device);
        return device;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    notifyListeners();
    return null;
  }

  /// 添加或更新设备
  void _addOrUpdateDevice(Device device) {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
    } else {
      _devices.add(device);
    }
    notifyListeners();
  }

  /// 移除设备
  void _removeDevice(Device device) {
    _devices.removeWhere((d) => d.id == device.id);
    notifyListeners();
  }

  /// 获取设备
  Device? getDevice(String id) {
    try {
      return _devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _foundSubscription?.cancel();
    _lostSubscription?.cancel();
    super.dispose();
  }
}