import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';

/// 本地存储服务
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _settingsKey = 'app_settings';
  static const String _deviceIdKey = 'device_id';
  static const String _historyKey = 'transfer_history';

  SharedPreferences? _prefs;
  static final _uuid = const Uuid();

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取设备 ID（如果没有则生成）
  Future<String> getDeviceId() async {
    await _ensureInitialized();
    String? deviceId = _prefs!.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await _prefs!.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  /// 获取设置
  Future<AppSettings> getSettings() async {
    await _ensureInitialized();
    final json = _prefs!.getString(_settingsKey);
    if (json != null) {
      try {
        return AppSettings.fromJson(jsonDecode(json));
      } catch (_) {}
    }

    // 默认设置
    final deviceId = await getDeviceId();
    return AppSettings(
      deviceId: deviceId,
      deviceName: _getDefaultDeviceName(),
      deviceType: await _getDeviceType(),
    );
  }

  /// 保存设置
  Future<void> saveSettings(AppSettings settings) async {
    await _ensureInitialized();
    await _prefs!.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// 获取设备类型
  Future<String> _getDeviceType() async {
    // 这里可以通过 platform_info 或其他方式检测
    // 默认返回 desktop
    return 'desktop';
  }

  /// 获取默认设备名称
  String _getDefaultDeviceName() {
    // 尝试获取设备名称
    // 在实际应用中可以使用 platform_info 获取
    return 'My Device';
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs!.clear();
  }

  /// 保存传输历史
  Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    await _ensureInitialized();
    await _prefs!.setString(_historyKey, jsonEncode(history));
  }

  /// 获取传输历史
  Future<List<Map<String, dynamic>>> getHistory() async {
    await _ensureInitialized();
    final json = _prefs!.getString(_historyKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        return list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return [];
  }

  /// 添加历史记录
  Future<void> addHistoryItem(Map<String, dynamic> item) async {
    final history = await getHistory();
    history.insert(0, item);
    // 只保留最近 100 条
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    await saveHistory(history);
  }

  /// 清除历史记录
  Future<void> clearHistory() async {
    await _ensureInitialized();
    await _prefs!.remove(_historyKey);
  }
}