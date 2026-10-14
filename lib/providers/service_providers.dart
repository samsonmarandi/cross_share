import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../services/discovery_service.dart';
import '../services/encrypted_pairing_storage.dart';
import '../services/http_server_service.dart';
import '../services/network_info_service.dart';
import '../services/pairing_service.dart';
import '../services/transfer_engine.dart';
import 'device_providers.dart';

// Services
final networkInfoServiceProvider = Provider((ref) => NetworkInfoService());
final discoveryServiceProvider = Provider((ref) {
  final service = DiscoveryService(
    networkInfo: ref.read(networkInfoServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final encryptedPairingStorageProvider = Provider(
  (ref) => EncryptedPairingStorage(),
);

final pairingServiceProvider = Provider((ref) {
  final storage = ref.read(encryptedPairingStorageProvider);
  final service = PairingService(storage: storage);
  service.onPairedDevicesChanged = () {
    ref.read(pairedDevicesProvider.notifier).loadDevices();
  };
  return service;
});

final httpServerServiceProvider = Provider((ref) {
  final service = HttpServerService();
  service.pairingService = ref.read(pairingServiceProvider);
  ref.onDispose(() => unawaited(service.stopServer()));
  return service;
});

final transferEngineProvider = Provider((ref) {
  final engine = TransferEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// Discovered Devices Stream
final discoveredDevicesProvider = StreamProvider<List<DeviceModel>>((
  ref,
) async* {
  final discovery = ref.watch(discoveryServiceProvider);
  yield discovery.currentDevices;
  yield* discovery.devicesStream;
});
