import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/devices_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化设置提供器
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // 初始化设备提供器
  final devicesProvider = DevicesProvider();
  await devicesProvider.init(
    deviceId: settingsProvider.deviceId,
    deviceName: settingsProvider.deviceName,
    deviceType: settingsProvider.deviceType,
    enableMdns: settingsProvider.enableMdns,
    enableUdp: settingsProvider.enableUdp,
  );

  // 初始化传输提供器
  final transferProvider = TransferProvider();
  await transferProvider.init(
    deviceId: settingsProvider.deviceId,
    deviceName: settingsProvider.deviceName,
    downloadPath: settingsProvider.downloadPath,
    autoAccept: settingsProvider.autoAccept,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: devicesProvider),
        ChangeNotifierProvider.value(value: transferProvider),
      ],
      child: const LanTransferApp(),
    ),
  );
}

/// 应用主组件
class LanTransferApp extends StatelessWidget {
  const LanTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'LanTransfer',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const HomeScreen(),
        );
      },
    );
  }

  /// 浅色主题
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  /// 深色主题
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}