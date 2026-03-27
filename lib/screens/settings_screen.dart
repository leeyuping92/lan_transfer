import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// 设置屏幕
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            children: [
              // 设备信息
              _buildSectionHeader(theme, '设备'),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('设备名称'),
                subtitle: Text(settings.deviceName),
                onTap: () => _showEditNameDialog(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('设备 ID'),
                subtitle: Text(
                  settings.deviceId.isEmpty ? '未设置' : settings.deviceId,
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const Divider(),

              // 发现设置
              _buildSectionHeader(theme, '发现设置'),
              SwitchListTile(
                secondary: const Icon(Icons.wifi_tethering),
                title: const Text('UDP 广播发现'),
                subtitle: const Text('通过局域网广播发现设备'),
                value: settings.enableUdp,
                onChanged: (value) => settings.setEnableUdp(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.dns),
                title: const Text('mDNS 发现'),
                subtitle: const Text('通过 mDNS/Bonjour 发现设备'),
                value: settings.enableMdns,
                onChanged: (value) => settings.setEnableMdns(value),
              ),

              const Divider(),

              // 传输设置
              _buildSectionHeader(theme, '传输设置'),
              SwitchListTile(
                secondary: const Icon(Icons.download),
                title: const Text('自动接收'),
                subtitle: const Text('自动接收来自信任设备的文件'),
                value: settings.autoAccept,
                onChanged: (value) => settings.setAutoAccept(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.photo_library),
                title: const Text('保存到相册'),
                subtitle: const Text('自动将图片和视频保存到相册'),
                value: settings.saveToGallery,
                onChanged: (value) => settings.setSaveToGallery(value),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('下载目录'),
                subtitle: Text(
                  settings.downloadPath.isEmpty
                      ? '默认目录'
                      : settings.downloadPath,
                ),
                onTap: () {
                  // 打开文件选择器选择下载目录
                },
              ),

              const Divider(),

              // 外观
              _buildSectionHeader(theme, '外观'),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('深色模式'),
                subtitle: const Text('使用深色主题'),
                value: settings.darkMode,
                onChanged: (value) => settings.setDarkMode(value),
              ),

              const Divider(),

              // 关于
              _buildSectionHeader(theme, '关于'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('LanTransfer'),
                subtitle: Text('版本 1.0.0'),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.deviceName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '设备名称',
            hintText: '输入新名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                settings.setDeviceName(name);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}