import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/device_model.dart';
import '../models/share_file_model.dart';
import '../models/transfer_progress.dart';

class TransferEngine {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 60),
      sendTimeout: const Duration(minutes: 60),
    ),
  );

  final Uuid _uuid = const Uuid();
  CancelToken? _currentCancelToken;

  Future<TransferProgress> sendFiles({
    required DeviceModel sender,
    required DeviceModel receiver,
    required List<ShareFileModel> files,
    required void Function(TransferProgress progress) onProgress,
    String? pairAuthToken,
  }) async {
    final transferId = _uuid.v4();
    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.size);

    DeviceModel targetReceiver = receiver;

    // Fetch actual target device info if alias is missing/loading
    if (targetReceiver.alias == 'Loading...' ||
        targetReceiver.alias == 'Unknown Device') {
      try {
        final infoUrl = 'http://${receiver.ip}:${receiver.port}/api/info';
        final infoRes = await http
            .get(Uri.parse(infoUrl))
            .timeout(const Duration(seconds: 2));
        if (infoRes.statusCode == 200) {
          final json = jsonDecode(infoRes.body) as Map<String, dynamic>;
          targetReceiver = DeviceModel.fromJson(
            json,
          ).copyWith(ip: receiver.ip, port: receiver.port);
        }
      } catch (_) {}
    }

    var currentProgress = TransferProgress(
      transferId: transferId,
      senderDevice: sender,
      receiverDevice: targetReceiver,
      files: files,
      totalBytes: totalBytes,
      status: TransferStatus.connecting,
      isIncoming: false,
    );

    onProgress(currentProgress);

    try {
      if (files.isEmpty) throw StateError('No files selected');
      for (final selected in files) {
        if (selected.textContent == null &&
            (selected.filePath == null ||
                !await File(selected.filePath!).exists())) {
          throw StateError('Cannot read selected file: ${selected.fileName}');
        }
      }
      // Step 1: Handshake & Prepare Request
      final prepareUrl =
          'http://${targetReceiver.ip}:${targetReceiver.port}/api/prepare';

      final prepareHeaders = <String, String>{
        'content-type': 'application/json',
      };
      if (pairAuthToken != null && pairAuthToken.isNotEmpty) {
        prepareHeaders['x-pair-auth-token'] = pairAuthToken;
      }

      final prepareResponse = await http
          .post(
            Uri.parse(prepareUrl),
            headers: prepareHeaders,
            body: jsonEncode({
              'transferId': transferId,
              'sender': sender.toJson(),
              'files': files.map((f) => f.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (prepareResponse.statusCode != 200) {
        currentProgress = currentProgress.copyWith(
          status: TransferStatus.failed,
          errorMessage: 'Target device rejected connection request.',
        );
        onProgress(currentProgress);
        return currentProgress;
      }

      final prepareData =
          jsonDecode(prepareResponse.body) as Map<String, dynamic>;
      final bool accepted = prepareData['accepted'] as bool? ?? false;

      if (!accepted) {
        currentProgress = currentProgress.copyWith(
          status: TransferStatus.rejected,
          errorMessage: 'Transfer request rejected by recipient.',
        );
        onProgress(currentProgress);
        return currentProgress;
      }

      // Step 2: Upload Files Sequentially
      currentProgress = currentProgress.copyWith(
        status: TransferStatus.transferring,
      );
      onProgress(currentProgress);

      _currentCancelToken = CancelToken();
      int previousFilesBytes = 0;

      for (final fileModel in files) {
        if (fileModel.filePath == null ||
            !File(fileModel.filePath!).existsSync()) {
          if (fileModel.textContent == null) {
            throw StateError(
              'Cannot read selected file: ${fileModel.fileName}',
            );
          }
        }

        final textBytes = fileModel.textContent == null
            ? null
            : utf8.encode(fileModel.textContent!);
        final file = textBytes == null ? File(fileModel.filePath!) : null;
        final fileSize = textBytes?.length ?? await file!.length();
        final uploadUrl =
            'http://${targetReceiver.ip}:${targetReceiver.port}/api/upload/$transferId/${fileModel.id}';

        final stopwatch = Stopwatch()..start();

        await _dio.post(
          uploadUrl,
          data: textBytes == null ? file!.openRead() : Stream.value(textBytes),
          options: Options(
            headers: {
              'x-file-name': Uri.encodeComponent(fileModel.fileName),
              'x-file-size': '$fileSize',
              'content-length': '$fileSize',
              'content-type': 'application/octet-stream',
            },
          ),
          cancelToken: _currentCancelToken,
          onSendProgress: (int sent, int total) {
            final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
            final speed = elapsedSec > 0 ? (sent / elapsedSec) : 0.0;

            final currentTotalTransferred = previousFilesBytes + sent;

            currentProgress = currentProgress.copyWith(
              bytesTransferred: currentTotalTransferred,
              speedInBytesPerSec: speed,
            );
            onProgress(currentProgress);
          },
        );

        stopwatch.stop();
        previousFilesBytes += fileSize;
      }

      currentProgress = currentProgress.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: totalBytes,
        speedInBytesPerSec: 0,
      );
      onProgress(currentProgress);
      return currentProgress;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        currentProgress = currentProgress.copyWith(
          status: TransferStatus.cancelled,
          errorMessage: 'Transfer cancelled by user.',
        );
      } else {
        currentProgress = currentProgress.copyWith(
          status: TransferStatus.failed,
          errorMessage: e.message ?? 'Network error during file transfer.',
        );
      }
      onProgress(currentProgress);
      return currentProgress;
    } catch (e) {
      currentProgress = currentProgress.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      onProgress(currentProgress);
      return currentProgress;
    }
  }

  void dispose() {
    cancelTransfer();
    _dio.close(force: true);
  }

  void cancelTransfer() {
    _currentCancelToken?.cancel();
  }
}
