import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_share/models/device_model.dart';
import 'package:cross_share/models/paired_device_model.dart';
import 'package:cross_share/models/share_file_model.dart';
import 'package:cross_share/models/transfer_progress.dart';
import 'package:cross_share/services/encrypted_pairing_storage.dart';
import 'package:cross_share/services/http_server_service.dart';
import 'package:cross_share/services/pairing_service.dart';
import 'package:cross_share/services/transfer_engine.dart';

DeviceModel testDevice(String id, int port) => DeviceModel(
  id: id,
  alias: 'Test $id',
  ip: '127.0.0.1',
  port: port,
  deviceType: 'macos',
  lastSeen: DateTime.now(),
);

void main() {
  late EncryptedPairingStorage storage;
  late PairingService pairingService;
  late HttpServerService server;
  late TransferEngine engine;
  late Directory tempDir;
  late DeviceModel receiverDevice;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pairing_test_');
    storage = EncryptedPairingStorage();
    pairingService = PairingService(storage: storage);
    server = HttpServerService()
      ..customDownloadPath = tempDir.path
      ..pairingService = pairingService;
    engine = TransferEngine();

    final port = await server.startServer(
      device: testDevice('host_device', 0),
      initialPort: 0,
    );
    receiverDevice = testDevice('host_device', port);
    server.currentDevice = receiverDevice;
  });

  tearDown(() async {
    engine.dispose();
    await server.stopServer();
    await tempDir.delete(recursive: true);
  });

  test('EncryptedPairingStorage encrypts data on disk and restores it correctly', () async {
    final pairedModel = PairedDeviceModel(
      id: 'secret_device_123',
      alias: 'Samson-MacBook',
      deviceType: 'macos',
      authToken: 'secret_auth_token_xyz_999',
      pairedAt: DateTime.now(),
    );

    await storage.savePairedDevice(pairedModel);

    final isPaired = await storage.isDevicePaired('secret_device_123');
    expect(isPaired, isTrue);

    final retrieved = await storage.getPairedDevice('secret_device_123');
    expect(retrieved, isNotNull);
    expect(retrieved!.id, 'secret_device_123');
    expect(retrieved.alias, 'Samson-MacBook');
    expect(retrieved.authToken, 'secret_auth_token_xyz_999');

    // Verify unpairing
    await storage.removePairedDevice('secret_device_123');
    expect(await storage.isDevicePaired('secret_device_123'), isFalse);
  });

  test('PairingService validates code and exchanges auth tokens over /api/pair', () async {
    final activeCode = pairingService.getOrGeneratePairCode();
    expect(activeCode.code.length, 6);
    expect(pairingService.validatePairCode(activeCode.code), isTrue);
    expect(pairingService.validatePairCode('000000'), isFalse);

    final clientDevice = testDevice('client_device', 5555);
    final success = await pairingService.initiatePairingWithPeer(
      targetDevice: receiverDevice,
      currentDevice: clientDevice,
      pairCode: activeCode.code,
    );

    expect(success, isTrue);

    // Verify client device is now in encrypted storage
    final pairedDevice = await storage.getPairedDevice('client_device');
    expect(pairedDevice, isNotNull);
    expect(pairedDevice!.alias, 'Test client_device');
    expect(pairedDevice.authToken.isNotEmpty, isTrue);
  });

  test('Verified paired auth token auto-accepts transfers without manual approval prompt', () async {
    // Manually insert a paired device entry into receiver storage
    final pairedModel = PairedDeviceModel(
      id: 'sender_device',
      alias: 'Test Sender',
      deviceType: 'android',
      authToken: 'trusted_token_123',
      pairedAt: DateTime.now(),
    );
    await storage.savePairedDevice(pairedModel);

    // Turn auto-accept OFF to ensure paired auth token bypasses confirmation
    server.setAutoAccept(false);

    final textContent = 'Hello Paired';
    final files = [
      ShareFileModel(
        id: '1',
        fileName: 'paired_test.txt',
        size: utf8.encode(textContent).length,
        mimeType: 'text/plain',
        fileType: 'text',
        textContent: textContent,
      ),
    ];

    // Transfer using the trusted pairAuthToken
    final result = await engine.sendFiles(
      sender: testDevice('sender_device', 9000),
      receiver: receiverDevice,
      files: files,
      pairAuthToken: 'trusted_token_123',
      onProgress: (_) {},
    );

    expect(result.status, TransferStatus.completed);
  });
}
