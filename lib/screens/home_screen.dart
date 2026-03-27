import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/devices_provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/transfer_progress.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// 主屏幕 - 设备列表
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DevicesTab(),
          _TransfersTab(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_outlined),
            selectedIcon: Icon(Icons.swap_vert),
            label: '传输',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 设备标签页
class _DevicesTab extends StatefulWidget {
  const _DevicesTab();

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    final devicesProvider = context.read<DevicesProvider>();
    final transferProvider = context.read<TransferProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // 启动设备发现
    await devicesProvider.startDiscovery(
      deviceId: settingsProvider.deviceId,
      deviceName: settingsProvider.deviceName,
      deviceType: settingsProvider.deviceType,
      enableMdns: settingsProvider.enableMdns,
      enableUdp: settingsProvider.enableUdp,
    );

    // 启动传输服务
    await transferProvider.start(
      deviceId: settingsProvider.deviceId,
      deviceName: settingsProvider.deviceName,
      downloadPath: settingsProvider.downloadPath,
      autoAccept: settingsProvider.autoAccept,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网传输'),
        actions: [
          Consumer<DevicesProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.isDiscovering ? Icons.radar : Icons.radar_outlined,
                ),
                onPressed: provider.isDiscovering ? null : _initServices,
                tooltip: '刷新',
              );
            },
          ),
        ],
      ),
      body: Consumer2<DevicesProvider, TransferProvider>(
        builder: (context, devicesProvider, transferProvider, _) {
          // 显示待接收请求
          if (transferProvider.pendingRequests.isNotEmpty) {
            _showReceiveDialog(transferProvider.pendingRequests.first);
          }

          if (devicesProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    devicesProvider.errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _initServices,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final devices = devicesProvider.devices;

          if (devices.isEmpty) {
            return EmptyDevicesView(
              isDiscovering: devicesProvider.isDiscovering,
              onAddManually: _showAddDeviceDialog,
            );
          }

          return Column(
            children: [
              // 本机信息
              if (devicesProvider.localIp != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '本机 IP: ${devicesProvider.localIp}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

              // 设备列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DeviceCard(
                        device: device,
                        onTap: () => _selectFiles(device),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDeviceDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动添加设备'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP 地址',
            hintText: '例如: 192.168.1.100:41270',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final address = controller.text.trim();
              if (address.isNotEmpty) {
                final provider = context.read<DevicesProvider>();
                await provider.addManualDevice(address);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFiles(Device device) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;

        final transferProvider = context.read<TransferProvider>();

        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();

        if (paths.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取文件路径')),
          );
          return;
        }

        // 发送文件
        await transferProvider.sendFiles(
          filePaths: paths,
          targetDevice: device,
        );

        if (mounted) {
          // 导航到传输页面
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  void _showReceiveDialog(dynamic request) {
    // 显示接收确认对话框
    // 这里简化处理，实际应该使用 Navigator
  }
}

/// 传输标签页
class _TransfersTab extends StatelessWidget {
  const _TransfersTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输'),
        actions: [
          Consumer<TransferProvider>(
            builder: (context, provider, _) {
              final completedCount = provider.completedTransferCount;
              if (completedCount > 0) {
                return IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: provider.clearCompleted,
                  tooltip: '清理已完成',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, _) {
          final tasks = provider.activeTasks;

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无传输任务',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择一个设备开始传输文件',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TransferTaskCard(
                  task: task,
                  onCancel: task.canCancel
                      ? () => provider.cancelTransfer(task.id)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}