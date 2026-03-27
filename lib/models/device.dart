import 'dart:convert';

/// 设备模型
class Device {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String deviceType;
  final int protocolVersion;
  final String? fingerprint;
  final DateTime lastSeen;
  final DeviceSource source;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.deviceType,
    this.protocolVersion = 1,
    this.fingerprint,
    DateTime? lastSeen,
    this.source = DeviceSource.udp,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// 从 JSON 创建
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      deviceType: json['deviceType'] as String? ?? 'desktop',
      protocolVersion: json['protocolVersion'] as int? ?? 1,
      fingerprint: json['fingerprint'] as String?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      source: DeviceSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => DeviceSource.udp,
      ),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'deviceType': deviceType,
      'protocolVersion': protocolVersion,
      'fingerprint': fingerprint,
      'lastSeen': lastSeen.toIso8601String(),
      'source': source.name,
    };
  }

  /// 从网络消息创建
  factory Device.fromMessage(Map<String, dynamic> message, String ip) {
    return Device(
      id: message['id'] as String,
      name: message['name'] as String,
      ip: ip,
      port: message['port'] as int? ?? 41271,
      deviceType: message['deviceType'] as String? ?? 'desktop',
      protocolVersion: message['protocolVersion'] as int? ?? 1,
      fingerprint: message['fingerprint'] as String?,
      source: DeviceSource.values.firstWhere(
        (e) => e.name == message['source'],
        orElse: () => DeviceSource.udp,
      ),
    );
  }

  /// 创建公告消息
  Map<String, dynamic> toAnnounceMessage() {
    return {
      'type': 'ANNOUNCE',
      'id': id,
      'name': name,
      'port': port,
      'deviceType': deviceType,
      'protocolVersion': protocolVersion,
      'fingerprint': fingerprint,
    };
  }

  /// 复制并更新时间
  Device copyWithUpdate() {
    return Device(
      id: id,
      name: name,
      ip: ip,
      port: port,
      deviceType: deviceType,
      protocolVersion: protocolVersion,
      fingerprint: fingerprint,
      lastSeen: DateTime.now(),
      source: source,
    );
  }

  /// IP:Port 标识符
  String get address => '$ip:$port';

  /// 是否是移动设备
  bool get isMobile => deviceType == 'mobile';

  /// 是否超时
  bool get isTimeout {
    return DateTime.now().difference(lastSeen).inSeconds > 15;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device($name, $ip:$port)';
}

/// 设备发现来源
enum DeviceSource {
  mdns,   // mDNS/Bonjour 发现
  udp,    // UDP 广播发现
  manual, // 手动输入
}