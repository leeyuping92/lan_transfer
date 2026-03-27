import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/transfer_task.dart';
import '../utils/constants.dart';

/// 文件传输服务
class FileTransferService {
  // 单例
  static final FileTransferService _instance =
      FileTransferService._internal();
  factory FileTransferService() => _instance;
  FileTransferService._internal();

  final _uuid = const Uuid();

  // 传输回调
  final StreamController<TransferTask> _onTransferUpdate =
      StreamController<TransferTask>.broadcast();

  Stream<TransferTask> get onTransferUpdate => _onTransferUpdate.stream;

  // 当前传输任务
  final Map<String, TransferTask> _activeTasks = {};

  // 待接收文件队列
  final Map<String, _PendingReceive> _pendingReceives = {};

  // 服务器
  HttpServer? _server;
  bool _isRunning = false;

  // 本机信息
  String? _deviceId;
  String? _deviceName;
  String? _downloadPath;
  bool _autoAccept = false;
  bool Function(String fileName, int fileSize, Device sender)? _onReceiveRequest;

  /// 当前传输任务列表
  List<TransferTask> get activeTasks => _activeTasks.values.toList();

  /// 启动传输服务
  Future<void> start({
    required String deviceId,
    required String deviceName,
    String? downloadPath,
    bool autoAccept = false,
    bool Function(String fileName, int fileSize, Device sender)? onReceiveRequest,
  }) async {
    if (_isRunning) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _downloadPath = downloadPath ?? await _getDefaultDownloadPath();
    _autoAccept = autoAccept;
    _onReceiveRequest = onReceiveRequest;

    // 监听来自其他设备的连接请求
    await _startServer();

    _isRunning = true;
  }

  /// 停止传输服务
  Future<void> stop() async {
    _server?.close();
    _server = null;
    _isRunning = false;

    // 取消所有活跃传输
    for (final task in _activeTasks.values) {
      if (task.canCancel) {
        final cancelled = task.copyWith(
          status: TransferStatus.cancelled,
          endTime: DateTime.now(),
        );
        _activeTasks[task.id] = cancelled;
        _onTransferUpdate.add(cancelled);
      }
    }
  }

  /// 更新下载路径
  void setDownloadPath(String path) {
    _downloadPath = path;
  }

  /// 更新自动接受设置
  void setAutoAccept(bool autoAccept) {
    _autoAccept = autoAccept;
  }

  /// 默认下载路径
  Future<String> _getDefaultDownloadPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // ========== 服务器 ==========

  /// 启动服务器监听连接
  Future<void> _startServer() async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      AppConstants.transferPort,
      shared: true,
    );

    print('[传输服务器] 监听端口: ${AppConstants.transferPort}');

    _server!.listen(_handleRequest);
  }

  /// 处理请求
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/send') {
        await _handleSendRequest(request);
      } else if (path == '/file') {
        await _handleFileTransfer(request);
      } else if (path == '/accept') {
        await _handleAccept(request);
      } else if (path == '/reject') {
        await _handleReject(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      print('[处理请求] 错误: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// 处理发送文件请求
  Future<void> _handleSendRequest(HttpRequest request) async {
    final body = await _readJsonBody(request);

    final taskId = body['taskId'] as String?;
    final senderId = body['senderId'] as String?;
    final senderName = body['senderName'] as String?;
    final fileName = body['fileName'] as String?;
    final fileSize = body['fileSize'] as int?;

    if (taskId == null || fileName == null || fileSize == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('{"error": "invalid request"}');
      await request.response.close();
      return;
    }

    // 创建待接收任务
    final pending = _PendingReceive(
      taskId: taskId,
      senderId: senderId ?? 'unknown',
      senderName: senderName ?? 'Unknown',
      fileName: fileName,
      fileSize: fileSize,
    );

    _pendingReceives[taskId] = pending;

    // 发送响应
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'taskId': taskId,
      'pending': true,
    }));
    await request.response.close();

    // 通知应用层处理接收请求
    if (_onReceiveRequest != null) {
      final device = Device(
        id: senderId ?? 'unknown',
        name: senderName ?? 'Unknown',
        ip: request.connectionInfo?.remoteAddress.address ?? 'unknown',
        port: AppConstants.transferPort,
        deviceType: 'unknown',
      );

      // 等待用户确认（由外部调用 accept/reject）
      // 这里只是把请求传递给 UI 层
    }
  }

  /// 处理文件传输
  Future<void> _handleFileTransfer(HttpRequest request) async {
    final taskId = request.uri.queryParameters['taskId'];
    if (taskId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final pending = _pendingReceives[taskId];
    if (pending == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final pendingNonNull = pending;

    // 检查是否已接受
    if (!pendingNonNull.accepted) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    // 检查下载路径
    final downloadPath = _downloadPath;
    if (downloadPath == null) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
      return;
    }

    // 开始接收文件
    final savePath = p.join(downloadPath, pendingNonNull.fileName);
    final file = File(savePath);
    final sink = file.openWrite();

    int receivedBytes = 0;
    final startTime = DateTime.now();

    // 创建传输任务
    final task = TransferTask(
      id: taskId,
      fileName: pendingNonNull.fileName,
      filePath: savePath,
      fileSize: pendingNonNull.fileSize,
      deviceId: pendingNonNull.senderId,
      deviceName: pendingNonNull.senderName,
      direction: TransferDirection.receive,
      status: TransferStatus.transferring,
      startTime: startTime,
    );
    _activeTasks[taskId] = task;
    _onTransferUpdate.add(task);

    await for (final chunk in request) {
      sink.add(chunk);
      receivedBytes += chunk.length;

      // 更新进度
      final updatedTask = task.copyWith(
        status: TransferStatus.transferring,
        transferredBytes: receivedBytes,
      );
      _activeTasks[taskId] = updatedTask;
      _onTransferUpdate.add(updatedTask);
    }

    await sink.close();

    // 完成传输
    final completedTask = task.copyWith(
      status: TransferStatus.completed,
      transferredBytes: receivedBytes,
      endTime: DateTime.now(),
    );
    _activeTasks[taskId] = completedTask;
    _onTransferUpdate.add(completedTask);

    _pendingReceives.remove(taskId);
    print('[接收] 完成: ${pending.fileName}');
  }

  /// 处理接受
  Future<void> _handleAccept(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final taskId = body['taskId'] as String?;

    if (taskId == null || !_pendingReceives.containsKey(taskId)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final pending = _pendingReceives[taskId]!;
    pending.accepted = true;

    print('[接受] taskId: $taskId');

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
    await request.response.close();
  }

  /// 处理拒绝
  Future<void> _handleReject(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final taskId = body['taskId'] as String?;

    if (taskId != null) {
      _pendingReceives.remove(taskId);
    }

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
    await request.response.close();
  }

  /// 读取 JSON 请求体
  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ========== 发送文件 ==========

  /// 发送文件到设备
  Future<TransferTask> sendFile({
    required String filePath,
    required Device targetDevice,
    Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final fileName = p.basename(filePath);
    final fileSize = await file.length();
    final taskId = _uuid.v4();

    // 创建发送任务
    final task = TransferTask(
      id: taskId,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      deviceId: targetDevice.id,
      deviceName: targetDevice.name,
      direction: TransferDirection.send,
      status: TransferStatus.connecting,
    );
    _activeTasks[taskId] = task;
    _onTransferUpdate.add(task);

    try {
      // 发送接受请求
      final accepted = await _requestSend(
        taskId: taskId,
        fileName: fileName,
        fileSize: fileSize,
        targetDevice: targetDevice,
      );

      if (!accepted) {
        final rejectedTask = task.copyWith(
          status: TransferStatus.rejected,
          endTime: DateTime.now(),
        );
        _activeTasks[taskId] = rejectedTask;
        _onTransferUpdate.add(rejectedTask);
        return rejectedTask;
      }

      // 传输文件
      final completedTask = await _transferFile(
        task: task,
        file: file,
        targetDevice: targetDevice,
        onProgress: onProgress,
      );

      _activeTasks[taskId] = completedTask;
      _onTransferUpdate.add(completedTask);
      return completedTask;

    } catch (e) {
      final failedTask = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
      _activeTasks[taskId] = failedTask;
      _onTransferUpdate.add(failedTask);
      return failedTask;
    }
  }

  /// 请求发送文件
  Future<bool> _requestSend({
    required String taskId,
    required String fileName,
    required int fileSize,
    required Device targetDevice,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/send'),
      );

      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'taskId': taskId,
        'senderId': _deviceId,
        'senderName': _deviceName,
        'fileName': fileName,
        'fileSize': fileSize,
      }));

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['pending'] == true;
    } catch (e) {
      print('[请求发送] 失败: $e');
      return false;
    }
  }

  /// 传输文件
  Future<TransferTask> _transferFile({
    required TransferTask task,
    required File file,
    required Device targetDevice,
    Function(double progress)? onProgress,
  }) async {
    // 更新状态为传输中
    var currentTask = task.copyWith(status: TransferStatus.transferring);
    _onTransferUpdate.add(currentTask);

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse(
            'http://${targetDevice.ip}:${targetDevice.port}/file?taskId=${task.id}'),
      );

      final totalBytes = task.fileSize;
      int sentBytes = 0;
      final startTime = DateTime.now();

      // 打开文件流
      final input = file.openRead();

      // 构建多部分请求
      final socket = await Socket.connect(
        targetDevice.ip,
        targetDevice.port,
        timeout: const Duration(seconds: 30),
      );

      // 发送文件数据
      await for (final chunk in input) {
        socket.add(chunk);
        sentBytes += chunk.length;

        // 更新进度
        currentTask = currentTask.copyWith(
          transferredBytes: sentBytes,
        );
        _onTransferUpdate.add(currentTask);
        onProgress?.call(sentBytes / totalBytes * 100);
      }

      await socket.close();

      print('[发送] 完成: ${task.fileName}');

      return currentTask.copyWith(
        status: TransferStatus.completed,
        endTime: DateTime.now(),
      );

    } catch (e) {
      print('[发送] 失败: $e');
      return currentTask.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
    }
  }

  /// 接受文件传输
  Future<bool> acceptTransfer(String taskId, Device sender) async {
    final pending = _pendingReceives[taskId];
    if (pending == null) return false;

    // 告诉发送方接受传输
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://${sender.ip}:${sender.port}/accept'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'taskId': taskId}));
      await request.close();
      return true;
    } catch (e) {
      print('[接受传输] 失败: $e');
      return false;
    }
  }

  /// 拒绝文件传输
  Future<bool> rejectTransfer(String taskId, Device sender) async {
    _pendingReceives.remove(taskId);

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://${sender.ip}:${sender.port}/reject'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'taskId': taskId}));
      await request.close();
      return true;
    } catch (e) {
      print('[拒绝传输] 失败: $e');
      return false;
    }
  }

  /// 取消传输
  void cancelTransfer(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null && task.canCancel) {
      final cancelled = task.copyWith(
        status: TransferStatus.cancelled,
        endTime: DateTime.now(),
      );
      _activeTasks[taskId] = cancelled;
      _onTransferUpdate.add(cancelled);
    }
  }

  /// 清理完成的传输
  void clearCompleted() {
    _activeTasks.removeWhere((_, task) => task.isCompleted);
  }
}

/// 待接收文件信息
class _PendingReceive {
  final String taskId;
  final String senderId;
  final String senderName;
  final String fileName;
  final int fileSize;
  bool accepted = false;

  _PendingReceive({
    required this.taskId,
    required this.senderId,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
  });
}