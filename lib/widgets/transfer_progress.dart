import 'package:flutter/material.dart';

import '../models/transfer_task.dart';

/// 传输任务卡片
class TransferTaskCard extends StatelessWidget {
  final TransferTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  const TransferTaskCard({
    super.key,
    required this.task,
    this.onCancel,
    this.onTap,
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIcon(colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.fileName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${task.direction == TransferDirection.send ? '发送给' : '来自'} ${task.deviceName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(colorScheme),
                ],
              ),
              if (task.status == TransferStatus.transferring) ...[
                const SizedBox(height: 12),
                _buildProgressBar(colorScheme),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${task.formattedTransferred} / ${task.formattedSize}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      task.speed,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (task.status == TransferStatus.completed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已完成',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      task.formattedSize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              if (task.status == TransferStatus.failed ||
                  task.status == TransferStatus.rejected) ...[
                const SizedBox(height: 8),
                Text(
                  task.errorMessage ?? (task.status == TransferStatus.rejected
                      ? '对方拒绝了传输'
                      : '传输失败'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              if (task.canCancel) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    final isSend = task.direction == TransferDirection.send;
    final isReceive = task.direction == TransferDirection.receive;

    IconData icon;
    Color bgColor;
    Color iconColor;

    if (task.status == TransferStatus.failed ||
        task.status == TransferStatus.rejected) {
      icon = Icons.error_outline;
      bgColor = colorScheme.errorContainer;
      iconColor = colorScheme.error;
    } else if (task.status == TransferStatus.completed) {
      icon = isSend ? Icons.upload_file : Icons.download_done;
      bgColor = colorScheme.primaryContainer;
      iconColor = colorScheme.primary;
    } else if (task.status == TransferStatus.transferring) {
      icon = isSend ? Icons.upload : Icons.download;
      bgColor = colorScheme.primaryContainer;
      iconColor = colorScheme.primary;
    } else {
      icon = Icons.hourglass_empty;
      bgColor = colorScheme.surfaceContainerHighest;
      iconColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildStatusBadge(ColorScheme colorScheme) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (task.status) {
      case TransferStatus.pending:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        label = '等待中';
        icon = Icons.hourglass_empty;
        break;
      case TransferStatus.connecting:
        bgColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        label = '连接中';
        icon = Icons.sync;
        break;
      case TransferStatus.transferring:
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        label = '${task.progress.toStringAsFixed(0)}%';
        icon = Icons.swap_vert;
        break;
      case TransferStatus.completed:
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        label = '完成';
        icon = Icons.check_circle;
        break;
      case TransferStatus.failed:
        bgColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        label = '失败';
        icon = Icons.error;
        break;
      case TransferStatus.cancelled:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        label = '已取消';
        icon = Icons.cancel;
        break;
      case TransferStatus.rejected:
        bgColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        label = '已拒绝';
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: task.progress / 100,
        minHeight: 6,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
      ),
    );
  }
}