import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../models/transfer_task.dart';
import '../services/file_transfer_service.dart';

/// 传输状态提供器
class TransferProvider extends ChangeNotifier {
  final FileTransferService _transferService = FileTransferService();

  List<TransferTask> _activeTasks = [];
  bool _isRunning = false;
  String? _downloadPath;
  bool _autoAccept = false;

  // 待接收的请求
  final List<_ReceiveRequest> _pendingRequests = [];

  StreamSubscription<TransferTask>? _updateSubscription;

  List<TransferTask> get activeTasks => _activeTasks;
  bool get isRunning => _isRunning;
  String? get downloadPath => _downloadPath;
  List<_ReceiveRequest> get pendingRequests => _pendingRequests;

  // 活跃传输数
  int get activeTransferCount =>
      _activeTasks.where((t) => !t.isCompleted).length;

  // 完成传输数
  int get completedTransferCount =>
      _activeTasks.where((t) => t.status == TransferStatus.completed).length;

  /// 初始化
  Future<void> init({
    required String deviceId,
    required String deviceName,
    String? downloadPath,
    bool autoAccept = false,
  }) async {
    _downloadPath = downloadPath;
    _autoAccept = autoAccept;

    // 监听传输更新
    _updateSubscription = _transferService.onTransferUpdate.listen((task) {
      _updateTask(task);
    });
  }

  /// 启动传输服务
  Future<void> start({
    required String deviceId,
    required String deviceName,
    String? downloadPath,
    bool autoAccept = false,
  }) async {
    if (_isRunning) return;

    _downloadPath = downloadPath ?? _downloadPath;
    _autoAccept = autoAccept;

    await _transferService.start(
      deviceId: deviceId,
      deviceName: deviceName,
      downloadPath: _downloadPath,
      autoAccept: _autoAccept,
      onReceiveRequest: _handleReceiveRequest,
    );

    _isRunning = true;
    notifyListeners();
  }

  /// 停止传输服务
  Future<void> stop() async {
    await _transferService.stop();
    _isRunning = false;
    notifyListeners();
  }

  /// 更新下载路径
  void setDownloadPath(String path) {
    _downloadPath = path;
    _transferService.setDownloadPath(path);
  }

  /// 更新自动接受设置
  void setAutoAccept(bool value) {
    _autoAccept = value;
    _transferService.setAutoAccept(value);
  }

  /// 发送文件
  Future<TransferTask?> sendFile({
    required String filePath,
    required Device targetDevice,
    Function(double progress)? onProgress,
  }) async {
    try {
      final task = await _transferService.sendFile(
        filePath: filePath,
        targetDevice: targetDevice,
        onProgress: onProgress,
      );
      return task;
    } catch (e) {
      print('[发送文件] 错误: $e');
      return null;
    }
  }

  /// 发送多个文件
  Future<List<TransferTask>> sendFiles({
    required List<String> filePaths,
    required Device targetDevice,
    Function(double progress, int completed, int total)? onProgress,
  }) async {
    final tasks = <TransferTask>[];
    final total = filePaths.length;

    for (var i = 0; i < filePaths.length; i++) {
      final task = await sendFile(
        filePath: filePaths[i],
        targetDevice: targetDevice,
        onProgress: (progress) {
          onProgress?.call(progress, i + 1, total);
        },
      );
      if (task != null) {
        tasks.add(task);
      }
    }

    return tasks;
  }

  /// 接受传输
  Future<bool> acceptTransfer(String taskId) async {
    final request = _pendingRequests.firstWhere(
      (r) => r.taskId == taskId,
      orElse: () => throw Exception('请求不存在'),
    );

    final success = await _transferService.acceptTransfer(
      taskId,
      request.sender,
    );

    if (success) {
      _pendingRequests.removeWhere((r) => r.taskId == taskId);
      notifyListeners();
    }

    return success;
  }

  /// 拒绝传输
  Future<bool> rejectTransfer(String taskId) async {
    final request = _pendingRequests.firstWhere(
      (r) => r.taskId == taskId,
      orElse: () => throw Exception('请求不存在'),
    );

    final success = await _transferService.rejectTransfer(
      taskId,
      request.sender,
    );

    if (success) {
      _pendingRequests.removeWhere((r) => r.taskId == taskId);
      notifyListeners();
    }

    return success;
  }

  /// 取消传输
  void cancelTransfer(String taskId) {
    _transferService.cancelTransfer(taskId);
  }

  /// 清理完成的传输
  void clearCompleted() {
    _transferService.clearCompleted();
    _activeTasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
  }

  /// 处理接收请求
  bool _handleReceiveRequest(
      String fileName, int fileSize, Device sender) {
    // 如果自动接受开启，直接接受
    if (_autoAccept) {
      _transferService.acceptTransfer(
        'auto_${DateTime.now().millisecondsSinceEpoch}',
        sender,
      );
      return true;
    }

    // 添加到待处理请求队列
    _pendingRequests.add(_ReceiveRequest(
      taskId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      sender: sender,
      fileName: fileName,
      fileSize: fileSize,
    ));
    notifyListeners();
    return false;
  }

  /// 更新任务状态
  void _updateTask(TransferTask task) {
    final index = _activeTasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _activeTasks[index] = task;
    } else {
      _activeTasks.add(task);
    }
    notifyListeners();
  }

  /// 获取传输历史
  List<TransferTask> get completedTasks =>
      _activeTasks.where((t) => t.isCompleted).toList();

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }
}

/// 待接收请求
class _ReceiveRequest {
  final String taskId;
  final Device sender;
  final String fileName;
  final int fileSize;
  final DateTime requestTime;

  _ReceiveRequest({
    required this.taskId,
    required this.sender,
    required this.fileName,
    required this.fileSize,
  }) : requestTime = DateTime.now();

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}