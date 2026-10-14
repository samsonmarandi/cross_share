import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import '../models/device_model.dart';
import '../models/share_file_model.dart';
import '../models/transfer_progress.dart';
import '../utils/file_metadata.dart';
import 'pairing_service.dart';
import 'web_portal.dart';

typedef OnTransferRequestCallback =
    Future<bool> Function(TransferProgress progress);
typedef OnFileReceivedCallback =
    void Function(String transferId, ShareFileModel file);
typedef OnProgressUpdateCallback =
    void Function(
      String transferId,
      int bytesTransferred,
      int totalBytes,
      double speedInBytesPerSec,
    );

class HttpServerService {
  HttpServer? _server;
  int _port = 53317;
  bool _isAutoAccept = false;

  int get port => _port;
  bool get isRunning => _server != null;

  final Map<String, _IncomingTransfer> _incomingTransfers = {};
  void Function(TransferProgress)? onTransferStarted;
  void Function(TransferProgress)? onTransferFinished;
  OnTransferRequestCallback? onTransferRequest;
  OnFileReceivedCallback? onFileReceived;
  OnProgressUpdateCallback? onProgressUpdate;

  PairingService? pairingService;
  late DeviceModel currentDevice;
  final List<ShareFileModel> _webSharedFiles = [];
  String? customDownloadPath;

  void setAutoAccept(bool value) {
    _isAutoAccept = value;
  }

  void updateWebSharedFiles(List<ShareFileModel> files) {
    _webSharedFiles.clear();
    _webSharedFiles.addAll(files);
  }

  Future<int> startServer({
    required DeviceModel device,
    int initialPort = 53317,
  }) async {
    if (isRunning) return _port;
    currentDevice = device;
    _port = initialPort;

    final appRouter = Router();

    // 1. Handshake Endpoint
    appRouter.get('/api/info', (Request request) {
      return Response.ok(
        jsonEncode(currentDevice.toJson()),
        headers: {'content-type': 'application/json'},
      );
    });

    // 2. Pair Code Handshake Endpoint
    appRouter.post('/api/pair', (Request request) async {
      try {
        final bodyText = await request.readAsString();
        final json = jsonDecode(bodyText) as Map<String, dynamic>;

        final pairCode = json['pairCode'] as String? ?? '';
        final peerDeviceId = json['deviceId'] as String? ?? '';
        final peerAlias = json['alias'] as String? ?? '';
        final peerDeviceType = json['deviceType'] as String? ?? 'unknown';

        if (pairingService == null) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Pairing service unavailable'}),
          );
        }

        final pairedDevice = await pairingService!.handlePairingRequest(
          pairCode: pairCode,
          peerDeviceId: peerDeviceId,
          peerAlias: peerAlias,
          peerDeviceType: peerDeviceType,
        );

        if (pairedDevice != null) {
          return Response.ok(
            jsonEncode({
              'status': 'success',
              'authToken': pairedDevice.authToken,
              'deviceId': currentDevice.id,
              'alias': currentDevice.alias,
              'deviceType': currentDevice.deviceType,
            }),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response(
            401,
            body: jsonEncode({
              'status': 'error',
              'message': 'Invalid or expired pair code',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 3. Prepare/Request Endpoint
    appRouter.post('/api/prepare', (Request request) async {
      try {
        final bodyText = await request.readAsString();
        final json = jsonDecode(bodyText) as Map<String, dynamic>;

        final transferId = json['transferId'] as String;
        final senderJson = json['sender'] as Map<String, dynamic>;
        final filesJson = json['files'] as List<dynamic>;

        final sender = DeviceModel.fromJson(senderJson);
        final files = filesJson
            .map((f) => ShareFileModel.fromJson(f as Map<String, dynamic>))
            .toList();

        if (files.isEmpty ||
            files.any((f) => f.id.isEmpty || f.size < 0) ||
            files.map((f) => f.id).toSet().length != files.length) {
          return Response(400, body: 'Invalid file list');
        }
        if (_incomingTransfers.isNotEmpty) {
          return Response(409, body: 'A transfer is already in progress');
        }
        final totalBytes = files.fold<int>(0, (sum, f) => sum + f.size);

        // Check for paired device auth token header
        final pairAuthToken = request.headers['x-pair-auth-token'];
        bool isPairedAndVerified = false;
        if (pairAuthToken != null && pairingService != null) {
          final pairedDevice = await pairingService!.storage.getPairedDevice(sender.id);
          if (pairedDevice != null && pairedDevice.authToken == pairAuthToken) {
            isPairedAndVerified = true;
          }
        }

        final progress = TransferProgress(
          transferId: transferId,
          senderDevice: sender,
          receiverDevice: currentDevice,
          files: files,
          totalBytes: totalBytes,
          status: TransferStatus.pending,
          isIncoming: true,
        );

        final incoming = _IncomingTransfer(progress);
        _incomingTransfers[transferId] = incoming;
        bool accepted = _isAutoAccept || isPairedAndVerified;
        try {
          if (!accepted && onTransferRequest != null) {
            accepted = await onTransferRequest!(progress);
          }
        } catch (_) {
          _incomingTransfers.remove(transferId);
          rethrow;
        }

        if (accepted) {
          incoming.accepted = true;
          onTransferStarted?.call(progress);
          _expireIdleTransfer(transferId, incoming);
        } else {
          _incomingTransfers.remove(transferId);
        }
        return Response.ok(
          jsonEncode({'accepted': accepted}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        debugPrint('Error in /api/prepare: $e');
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 3. Binary File Stream Upload Endpoint
    appRouter.post('/api/upload/<transferId>/<fileId>', (
      Request request,
      String transferId,
      String fileId,
    ) async {
      final incoming = _incomingTransfers[transferId];
      if (incoming == null ||
          !incoming.accepted ||
          incoming.uploading ||
          incoming.received.containsKey(fileId)) {
        return Response(403, body: 'Upload has not been approved');
      }
      final matches = incoming.progress.files.where((f) => f.id == fileId);
      if (matches.isEmpty) return Response(403, body: 'Unknown file');
      final expected = matches.first;
      incoming.idleTimer?.cancel();
      incoming.uploading = true;
      try {
        final fileNameHeader = request.headers['x-file-name'] ?? 'file_$fileId';
        String fileName;
        try {
          fileName = Uri.decodeComponent(fileNameHeader);
        } catch (_) {
          fileName = fileNameHeader;
        }
        fileName = p.basename(fileName); // Sanitize path traversal

        final fileSize = expected.size;

        final downloadDir = await _getDownloadDirectory();
        final savePath = p.join(downloadDir.path, fileName);
        final file = File(savePath);

        final sink = file.openWrite();
        int receivedBytes = 0;
        final stopwatch = Stopwatch()..start();

        try {
          await for (final chunk in request.read()) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (receivedBytes > fileSize) {
              throw StateError('Upload exceeds declared size');
            }

            final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
            final speed = elapsedSec > 0 ? (receivedBytes / elapsedSec) : 0.0;

            if (onProgressUpdate != null) {
              onProgressUpdate!(
                transferId,
                incoming.receivedBytes + receivedBytes,
                incoming.progress.totalBytes,
                speed,
              );
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (receivedBytes != fileSize) throw StateError('Incomplete upload');
        stopwatch.stop();

        final receivedFile = ShareFileModel(
          id: fileId,
          fileName: fileName,
          filePath: savePath,
          size: receivedBytes,
          mimeType: lookupMimeType(savePath) ?? 'application/octet-stream',
          fileType: fileTypeCategory(fileName),
        );

        incoming.received[fileId] = receivedFile;
        if (incoming.received.length == incoming.progress.files.length) {
          final completed = incoming.progress.copyWith(
            files: incoming.progress.files
                .map((f) => incoming.received[f.id]!)
                .toList(),
            bytesTransferred: incoming.receivedBytes,
            status: TransferStatus.completed,
          );
          _incomingTransfers.remove(transferId);
          onTransferFinished?.call(completed);
        }
        if (onFileReceived != null) {
          onFileReceived!(transferId, receivedFile);
        }

        return Response.ok(
          jsonEncode({'success': true, 'savePath': savePath}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e, stack) {
        _incomingTransfers.remove(transferId);
        onTransferFinished?.call(
          incoming.progress.copyWith(
            status: TransferStatus.failed,
            errorMessage: e.toString(),
            files: incoming.received.values.toList(),
            bytesTransferred: incoming.receivedBytes,
          ),
        );
        debugPrint('Error handling file upload: $e\n$stack');
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      } finally {
        incoming.uploading = false;
        if (_incomingTransfers.containsKey(transferId)) {
          _expireIdleTransfer(transferId, incoming);
        }
      }
    });

    // 4. Web Portal HTML Interface
    appRouter.get('/web', (Request request) {
      return Response.ok(
        buildWebPortal(currentDevice),
        headers: {'content-type': 'text/html'},
      );
    });

    // 5. Web Portal Shared Files JSON List
    appRouter.get('/web/shared', (Request request) {
      final jsonList = _webSharedFiles.map((f) => f.toJson()).toList();
      return Response.ok(
        jsonEncode(jsonList),
        headers: {'content-type': 'application/json'},
      );
    });

    // 6. Web Portal Download File Endpoint
    appRouter.get('/web/download/<fileId>', (Request request, String fileId) {
      final fileModel = _webSharedFiles.firstWhere(
        (f) => f.id == fileId,
        orElse: () => ShareFileModel(
          id: '',
          fileName: '',
          size: 0,
          mimeType: '',
          fileType: '',
        ),
      );

      if (fileModel.filePath == null ||
          !File(fileModel.filePath!).existsSync()) {
        return Response.notFound('File not found');
      }

      final file = File(fileModel.filePath!);
      final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': mime,
          'content-disposition':
              'attachment; filename="${Uri.encodeComponent(fileModel.fileName)}"',
          'content-length': '${file.lengthSync()}',
        },
      );
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(appRouter.call);

    // Try starting server on port, fallback to 0 (auto assigned) if port is in use
    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, _port);
    } catch (_) {
      _server = await io.serve(handler, InternetAddress.anyIPv4, 0);
      _port = _server!.port;
    }

    _port = _server!.port;
    return _port;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (customDownloadPath != null && customDownloadPath!.isNotEmpty) {
      try {
        final customDir = Directory(customDownloadPath!);
        if (!customDir.existsSync()) {
          customDir.createSync(recursive: true);
        }
        return customDir;
      } catch (e) {
        debugPrint('Custom download path error: $e');
      }
    }

    try {
      Directory? baseDir;
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          baseDir = Directory('/storage/emulated/0/Download/CrossShare');
          if (!baseDir.existsSync()) {
            baseDir.createSync(recursive: true);
          }
          return baseDir;
        } else {
          baseDir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final targetDir = Directory(p.join(baseDir.path, 'CrossShare'));
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      return targetDir;
    } catch (e) {
      debugPrint('Error getting download directory, using temp: $e');
      final temp = await getTemporaryDirectory();
      return temp;
    }
  }

  void _expireIdleTransfer(String id, _IncomingTransfer incoming) {
    incoming.idleTimer?.cancel();
    incoming.idleTimer = Timer(const Duration(minutes: 2), () {
      if (_incomingTransfers.remove(id) == null) return;
      onTransferFinished?.call(
        incoming.progress.copyWith(
          status: TransferStatus.failed,
          errorMessage: 'Sender stopped sending files.',
          files: incoming.received.values.toList(),
          bytesTransferred: incoming.receivedBytes,
        ),
      );
    });
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    for (final incoming in _incomingTransfers.values) {
      incoming.idleTimer?.cancel();
    }
    _incomingTransfers.clear();
  }
}

/// Tracks aggregate progress and the received local paths for one approved batch.
class _IncomingTransfer {
  _IncomingTransfer(this.progress);
  final TransferProgress progress;
  final Map<String, ShareFileModel> received = {};
  Timer? idleTimer;
  bool accepted = false;
  bool uploading = false;
  int get receivedBytes =>
      received.values.fold(0, (sum, file) => sum + file.size);
}
