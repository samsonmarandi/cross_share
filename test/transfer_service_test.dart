import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cross_share/models/device_model.dart';
import 'package:cross_share/models/share_file_model.dart';
import 'package:cross_share/models/transfer_progress.dart';
import 'package:cross_share/services/http_server_service.dart';
import 'package:cross_share/services/transfer_engine.dart';

DeviceModel device(String id, int port) => DeviceModel(
  id: id,
  alias: id,
  ip: '127.0.0.1',
  port: port,
  deviceType: 'linux',
  lastSeen: DateTime.now(),
);

void main() {
  late HttpServerService server;
  late TransferEngine engine;
  late Directory downloads;
  late DeviceModel receiver;

  setUp(() async {
    downloads = await Directory.systemTemp.createTemp('cross_share_test_');
    server = HttpServerService()..customDownloadPath = downloads.path;
    engine = TransferEngine();
    final port = await server.startServer(
      device: device('receiver', 0),
      initialPort: 0,
    );
    receiver = device('receiver', port);
    server.currentDevice = receiver;
  });
  tearDown(() async {
    engine.dispose();
    await server.stopServer();
    await downloads.delete(recursive: true);
  });

  test(
    'text batch preserves UTF-8 and completes once with aggregate progress',
    () async {
      server.setAutoAccept(true);
      final completed = <TransferProgress>[];
      final byteCounts = <int>[];
      server.onTransferFinished = completed.add;
      server.onProgressUpdate = (_, bytes, total, speed) =>
          byteCounts.add(bytes);
      final files = ['hello', 'नमस्ते 🌍']
          .asMap()
          .entries
          .map(
            (entry) => ShareFileModel(
              id: '${entry.key}',
              fileName: '${entry.key}.txt',
              size: utf8.encode(entry.value).length,
              mimeType: 'text/plain',
              fileType: 'text',
              textContent: entry.value,
            ),
          )
          .toList();
      final result = await engine.sendFiles(
        sender: device('sender', 1),
        receiver: receiver,
        files: files,
        onProgress: (_) {},
      );
      expect(result.status, TransferStatus.completed);
      expect(completed, hasLength(1));
      expect(completed.single.bytesTransferred, result.totalBytes);
      expect(byteCounts.last, result.totalBytes);
      for (final file in completed.single.files) {
        expect(
          await File(file.filePath!).readAsString(),
          files.firstWhere((f) => f.id == file.id).textContent,
        );
      }
    },
  );

  test('upload without approved prepare is refused', () async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:${receiver.port}/api/upload/unknown/file'),
      body: 'data',
    );
    expect(response.statusCode, 403);
    expect(await downloads.list().toList(), isEmpty);
  });

  test('unreadable selection fails instead of claiming completion', () async {
    server.setAutoAccept(true);
    final result = await engine.sendFiles(
      sender: device('sender', 1),
      receiver: receiver,
      files: [
        ShareFileModel(
          id: 'missing',
          fileName: 'missing.txt',
          size: 3,
          mimeType: 'text/plain',
          fileType: 'document',
          filePath: '${downloads.path}/missing.txt',
        ),
      ],
      onProgress: (_) {},
    );
    expect(result.status, TransferStatus.failed);
    expect(result.errorMessage, contains('Cannot read selected file'));
  });
}
