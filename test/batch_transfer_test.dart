import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_share/models/device_model.dart';
import 'package:cross_share/models/share_file_model.dart';
import 'package:cross_share/models/transfer_progress.dart';
import 'package:cross_share/providers/app_providers.dart';
import 'package:cross_share/services/http_server_service.dart';

DeviceModel testDevice(String id, int port) => DeviceModel(
  id: id,
  alias: 'Device $id',
  ip: '127.0.0.1',
  port: port,
  deviceType: 'android',
  lastSeen: DateTime.now(),
);

void main() {
  late HttpServerService server1;
  late HttpServerService server2;
  late Directory tempDir;
  late DeviceModel rx1;
  late DeviceModel rx2;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('batch_test_');
    server1 = HttpServerService()..customDownloadPath = tempDir.path..setAutoAccept(true);
    server2 = HttpServerService()..customDownloadPath = tempDir.path..setAutoAccept(true);

    final port1 = await server1.startServer(device: testDevice('rx1', 0), initialPort: 0);
    rx1 = testDevice('rx1', port1);
    server1.currentDevice = rx1;

    final port2 = await server2.startServer(device: testDevice('rx2', 0), initialPort: 0);
    rx2 = testDevice('rx2', port2);
    server2.currentDevice = rx2;

    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await server1.stopServer();
    await server2.stopServer();
    await tempDir.delete(recursive: true);
  });

  test('sendSelectedFilesToMultiple transmits files to all target devices', () async {
    final text = 'Multi device batch transfer test';
    final shareFile = ShareFileModel(
      id: 'batch_file_1',
      fileName: 'batch.txt',
      size: utf8.encode(text).length,
      mimeType: 'text/plain',
      fileType: 'text',
      textContent: text,
    );

    container.read(selectedFilesProvider.notifier).addFiles([shareFile]);

    final session = container.read(sessionProvider);
    final results = await session.sendSelectedFilesToMultiple([rx1, rx2]);

    expect(results.length, 2);
    expect(results[0].status, TransferStatus.completed);
    expect(results[1].status, TransferStatus.completed);
    expect(results[0].receiverDevice.id, rx1.id);
    expect(results[1].receiverDevice.id, rx2.id);
  });
}
