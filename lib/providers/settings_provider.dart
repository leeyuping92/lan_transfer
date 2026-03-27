import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/storage_service.dart';

/// 设置提供器
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  AppSettings _settings = AppSettings(
    deviceId: '',
    deviceName: 'My Device',
    deviceType: 'desktop',
  );
  bool _isLoading = true;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  String get deviceId => _settings.deviceId;
  String get deviceName => _settings.deviceName;
  String get deviceType => _settings.deviceType;
  bool get autoAccept => _settings.autoAccept;
  bool get saveToGallery => _settings.saveToGallery;
  String get downloadPath => _settings.downloadPath;
  bool get enableMdns => _settings.enableMdns;
  bool get enableUdp => _settings.enableUdp;
  bool get darkMode => _settings.darkMode;

  /// 初始化
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _storage.init();
    _settings = await _storage.getSettings();

    // 如果设备名称是空的，使用默认值
    if (_settings.deviceName.isEmpty) {
      _settings = _settings.copyWith(
        deviceName: _getDefaultDeviceName(),
      );
      await _storage.saveSettings(_settings);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 获取默认设备名称
  String _getDefaultDeviceName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    return 'My Device';
  }

  /// 更新设备名称
  Future<void> setDeviceName(String name) async {
    _settings = _settings.copyWith(deviceName: name);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 更新设备类型
  Future<void> setDeviceType(String type) async {
    _settings = _settings.copyWith(deviceType: type);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置自动接受
  Future<void> setAutoAccept(bool value) async {
    _settings = _settings.copyWith(autoAccept: value);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置保存到相册
  Future<void> setSaveToGallery(bool value) async {
    _settings = _settings.copyWith(saveToGallery: value);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置下载路径
  Future<void> setDownloadPath(String path) async {
    _settings = _settings.copyWith(downloadPath: path);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置启用 mDNS
  Future<void> setEnableMdns(bool value) async {
    _settings = _settings.copyWith(enableMdns: value);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置启用 UDP
  Future<void> setEnableUdp(bool value) async {
    _settings = _settings.copyWith(enableUdp: value);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 设置深色模式
  Future<void> setDarkMode(bool value) async {
    _settings = _settings.copyWith(darkMode: value);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 获取主题模式
  ThemeMode get themeMode =>
      _settings.darkMode ? ThemeMode.dark : ThemeMode.light;
}