/// 应用设置模型
class AppSettings {
  final String deviceName;
  final String deviceId;
  final String deviceType;
  final bool autoAccept;
  final bool saveToGallery;
  final String downloadPath;
  final bool enableMdns;
  final bool enableUdp;
  final bool darkMode;

  AppSettings({
    required this.deviceName,
    required this.deviceId,
    required this.deviceType,
    this.autoAccept = false,
    this.saveToGallery = true,
    this.downloadPath = '',
    this.enableMdns = true,
    this.enableUdp = true,
    this.darkMode = false,
  });

  /// 从 JSON 创建
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      deviceName: json['deviceName'] as String? ?? _defaultDeviceName(),
      deviceId: json['deviceId'] as String? ?? '',
      deviceType: json['deviceType'] as String? ?? 'desktop',
      autoAccept: json['autoAccept'] as bool? ?? false,
      saveToGallery: json['saveToGallery'] as bool? ?? true,
      downloadPath: json['downloadPath'] as String? ?? '',
      enableMdns: json['enableMdns'] as bool? ?? true,
      enableUdp: json['enableUdp'] as bool? ?? true,
      darkMode: json['darkMode'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'autoAccept': autoAccept,
      'saveToGallery': saveToGallery,
      'downloadPath': downloadPath,
      'enableMdns': enableMdns,
      'enableUdp': enableUdp,
      'darkMode': darkMode,
    };
  }

  /// 复制并更新
  AppSettings copyWith({
    String? deviceName,
    String? deviceId,
    String? deviceType,
    bool? autoAccept,
    bool? saveToGallery,
    String? downloadPath,
    bool? enableMdns,
    bool? enableUdp,
    bool? darkMode,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      autoAccept: autoAccept ?? this.autoAccept,
      saveToGallery: saveToGallery ?? this.saveToGallery,
      downloadPath: downloadPath ?? this.downloadPath,
      enableMdns: enableMdns ?? this.enableMdns,
      enableUdp: enableUdp ?? this.enableUdp,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  static String _defaultDeviceName() {
    // 获取设备默认名称
    return 'My Device';
  }
}