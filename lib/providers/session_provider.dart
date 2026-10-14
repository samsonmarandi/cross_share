import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_progress.dart';
import '../models/device_model.dart';
import '../services/http_server_service.dart';
import 'device_providers.dart';
import 'service_providers.dart';
import 'settings_providers.dart';
import 'transfer_providers.dart';

/// Coordinates service startup and transfer state independently of widgets.
final sessionProvider = Provider((ref) => AppSession(ref));

class AppSession {
  AppSession(this._ref) {
    _ref.onDispose(() => _disposed = true);
  }
  bool _disposed = false;
  final Ref _ref;
  Future<void>? _startup;

  Future<void> start(OnTransferRequestCallback requestApproval) =>
      _startup ??= _start(requestApproval);

  Future<void> _start(OnTransferRequestCallback requestApproval) async {
    final server = _ref.read(httpServerServiceProvider);
    final discovery = _ref.read(discoveryServiceProvider);
    server.onTransferRequest = requestApproval;
    server.onTransferStarted = (progress) {
      if (_disposed) return;
      _ref.read(activeTransferProvider.notifier).setTransfer(progress);
    };
    server.onProgressUpdate = (id, bytes, total, speed) {
      if (_disposed) return;
      final active = _ref.read(activeTransferProvider);
      if (active == null || active.transferId != id) return;
      _ref
          .read(activeTransferProvider.notifier)
          .updateProgress(
            active.copyWith(
              bytesTransferred: bytes,
              totalBytes: total,
              speedInBytesPerSec: speed,
              status: TransferStatus.transferring,
            ),
          );
    };
    server.onTransferFinished = (progress) {
      if (_disposed) return;
      _ref.read(activeTransferProvider.notifier).updateProgress(progress);
      _ref.read(transferHistoryProvider.notifier).addTransfer(progress);
    };
    _ref.listen(autoAcceptProvider, (_, next) => server.setAutoAccept(next));
    _ref.listen(
      customDownloadPathProvider,
      (_, next) => server.customDownloadPath = next,
    );
    _ref.listen(
      selectedFilesProvider,
      (_, next) => server.updateWebSharedFiles(next),
    );
    _ref.listen(currentDeviceProvider, (_, next) {
      server.currentDevice = next;
      discovery.updateDeviceName(next.alias);
    });
    server.setAutoAccept(_ref.read(autoAcceptProvider));
    server.customDownloadPath = _ref.read(customDownloadPathProvider);
    server.updateWebSharedFiles(_ref.read(selectedFilesProvider));
    await _ref.read(currentDeviceProvider.notifier).initDevice();
    if (_disposed) return;
    final device = _ref.read(currentDeviceProvider);
    final port = await server.startServer(device: device);
    if (_disposed) {
      await server.stopServer();
      return;
    }
    _ref.read(currentDeviceProvider.notifier).setPort(port);
    await discovery.startDiscovery(
      deviceId: device.id,
      deviceName: device.alias,
      httpPort: port,
    );
  }

  Future<void> sendSelectedFiles(DeviceModel receiver) async {
    await sendSelectedFilesToMultiple([receiver]);
  }

  Future<List<TransferProgress>> sendSelectedFilesToMultiple(
    List<DeviceModel> receivers,
  ) async {
    final results = <TransferProgress>[];
    for (final receiver in receivers) {
      if (_disposed) break;
      final storage = _ref.read(encryptedPairingStorageProvider);
      final pairedDevice = await storage.getPairedDevice(receiver.id);
      final pairAuthToken = pairedDevice?.authToken;

      final result = await _ref
          .read(transferEngineProvider)
          .sendFiles(
            sender: _ref.read(currentDeviceProvider),
            receiver: receiver,
            files: List.of(_ref.read(selectedFilesProvider)),
            pairAuthToken: pairAuthToken,
            onProgress: (progress) {
              if (!_disposed) {
                _ref
                    .read(activeTransferProvider.notifier)
                    .updateProgress(progress);
              }
            },
          );
      if (!_disposed) {
        _ref.read(transferHistoryProvider.notifier).addTransfer(result);
        results.add(result);
      }
    }
    return results;
  }
}
