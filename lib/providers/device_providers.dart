import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/device_model.dart';
import '../models/paired_device_model.dart';
import '../services/encrypted_pairing_storage.dart';
import '../services/network_info_service.dart';
import 'service_providers.dart';

// Current Device State
final currentDeviceProvider =
    StateNotifierProvider<CurrentDeviceNotifier, DeviceModel>((ref) {
      return CurrentDeviceNotifier(ref.read(networkInfoServiceProvider));
    });

class CurrentDeviceNotifier extends StateNotifier<DeviceModel> {
  final NetworkInfoService _netInfo;

  CurrentDeviceNotifier(this._netInfo)
    : super(
        DeviceModel(
          id: const Uuid().v4(),
          alias: _getInitialDefaultName(),
          ip: '127.0.0.1',
          port: 53317,
          deviceType: _getInitialOsType(),
          lastSeen: DateTime.now(),
        ),
      );

  static String _getInitialDefaultName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isMacOS) return 'MacBook';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    return 'CrossShare Device';
  }

  static String _getInitialOsType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  Future<void> initDevice() async {
    try {
      final ip = await _netInfo.getLocalIp() ?? '127.0.0.1';
      final name = await _netInfo.getDeviceName();
      final osType = _netInfo.getDeviceOsType();

      if (!mounted) return;
      state = state.copyWith(
        alias: (name.isNotEmpty && name != 'Loading...') ? name : state.alias,
        ip: ip,
        deviceType: osType,
      );
    } catch (error) {
      debugPrint('Device initialization failed: $error');
    }
  }

  void setDeviceName(String newName) {
    state = state.copyWith(alias: newName);
  }

  void updateIp(String newIp) {
    state = state.copyWith(ip: newIp);
  }

  void setPort(int port) {
    state = state.copyWith(port: port);
  }
}

// Reactive Paired Devices Riverpod State
final pairedDevicesProvider =
    StateNotifierProvider<PairedDevicesNotifier, List<PairedDeviceModel>>((ref) {
      final storage = ref.watch(encryptedPairingStorageProvider);
      return PairedDevicesNotifier(storage);
    });

class PairedDevicesNotifier extends StateNotifier<List<PairedDeviceModel>> {
  final EncryptedPairingStorage _storage;

  PairedDevicesNotifier(this._storage) : super([]) {
    loadDevices();
  }

  Future<void> loadDevices() async {
    final list = await _storage.loadPairedDevices();
    if (mounted) {
      state = list;
    }
  }

  Future<void> addPairedDevice(PairedDeviceModel device) async {
    await _storage.savePairedDevice(device);
    await loadDevices();
  }

  Future<void> removePairedDevice(String deviceId) async {
    await _storage.removePairedDevice(deviceId);
    await loadDevices();
  }

  bool isPaired(String deviceId) {
    return state.any((d) => d.id == deviceId);
  }
}
