import 'dart:io';

/// 传输任务模型
class TransferTask {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String deviceId;
  final String deviceName;
  final TransferDirection direction;
  final TransferStatus status;
  final int transferredBytes;
  final DateTime startTime;
  final DateTime? endTime;
  final String? errorMessage;

  TransferTask({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.deviceId,
    required this.deviceName,
    required this.direction,
    this.status = TransferStatus.pending,
    this.transferredBytes = 0,
    DateTime? startTime,
    this.endTime,
    this.errorMessage,
  }) : startTime = startTime ?? DateTime.now();

  /// 从 JSON 创建
  factory TransferTask.fromJson(Map<String, dynamic> json) {
    return TransferTask(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      direction: TransferDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => TransferDirection.send,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.pending,
      ),
      transferredBytes: json['transferredBytes'] as int? ?? 0,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'direction': direction.name,
      'status': status.name,
      'transferredBytes': transferredBytes,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// 复制并更新
  TransferTask copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? deviceId,
    String? deviceName,
    TransferDirection? direction,
    TransferStatus? status,
    int? transferredBytes,
    DateTime? startTime,
    DateTime? endTime,
    String? errorMessage,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 进度百分比 (0-100)
  double get progress => fileSize > 0 ? (transferredBytes / fileSize) * 100 : 0;

  /// 格式化文件大小
  String get formattedSize => _formatBytes(fileSize);

  /// 格式化已传输大小
  String get formattedTransferred => _formatBytes(transferredBytes);

  /// 传输速度估算
  String get speed {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed <= 0) return '0 B/s';
    final bytesPerSecond = transferredBytes / elapsed;
    return '${_formatBytes(bytesPerSecond.round())}/s';
  }

  /// 预计剩余时间
  String get eta {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed <= 0 || transferredBytes <= 0) return '--';
    final remainingBytes = fileSize - transferredBytes;
    final bytesPerSecond = transferredBytes / elapsed;
    if (bytesPerSecond <= 0) return '--';
    final remainingSeconds = (remainingBytes / bytesPerSecond).round();
    if (remainingSeconds < 60) return '${remainingSeconds}s';
    if (remainingSeconds < 3600) return '${remainingSeconds ~/ 60}m ${remainingSeconds % 60}s';
    return '${remainingSeconds ~/ 3600}h ${(remainingSeconds % 3600) ~/ 60}m';
  }

  /// 是否可以取消
  bool get canCancel =>
      status == TransferStatus.pending ||
      status == TransferStatus.connecting ||
      status == TransferStatus.transferring;

  /// 是否完成
  bool get isCompleted =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() => 'TransferTask($fileName, $status)';
}

/// 传输方向
enum TransferDirection {
  send,
  receive,
}

/// 传输状态
enum TransferStatus {
  pending,      // 等待中
  connecting,   // 连接中
  transferring, // 传输中
  completed,    // 已完成
  failed,       // 失败
  cancelled,    // 已取消
  rejected,     // 被拒绝
}