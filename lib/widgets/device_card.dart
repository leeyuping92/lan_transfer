import 'package:flutter/material.dart';

import '../models/device.dart';

/// 设备卡片组件
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIcon(colorScheme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.ip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSourceBadge(colorScheme),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    IconData icon;
    Color bgColor;

    if (device.isMobile) {
      icon = Icons.smartphone;
      bgColor = colorScheme.primaryContainer;
    } else {
      icon = Icons.computer;
      bgColor = colorScheme.secondaryContainer;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: colorScheme.onPrimaryContainer,
        size: 24,
      ),
    );
  }

  Widget _buildSourceBadge(ColorScheme colorScheme) {
    Color badgeColor;
    String label;

    switch (device.source) {
      case DeviceSource.mdns:
        badgeColor = colorScheme.tertiary;
        label = 'mDNS';
        break;
      case DeviceSource.udp:
        badgeColor = colorScheme.primary;
        label = 'UDP';
        break;
      case DeviceSource.manual:
        badgeColor = colorScheme.secondary;
        label = '手动';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}

/// 空设备状态组件
class EmptyDevicesView extends StatelessWidget {
  final bool isDiscovering;
  final VoidCallback onAddManually;

  const EmptyDevicesView({
    super.key,
    required this.isDiscovering,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDiscovering ? Icons.radar : Icons.devices_other,
              size: 80,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              isDiscovering ? '扫描中...' : '未发现设备',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDiscovering
                  ? '正在搜索局域网内的设备'
                  : '确保设备在同一网络下',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!isDiscovering)
              FilledButton.icon(
                onPressed: onAddManually,
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
              ),
          ],
        ),
      ),
    );
  }
}