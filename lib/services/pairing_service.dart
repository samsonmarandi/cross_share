import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/device_model.dart';
import '../models/paired_device_model.dart';
import 'encrypted_pairing_storage.dart';

class ActivePairCode {
  final String code;
  final DateTime expiresAt;

  ActivePairCode({required this.code, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class PairingService {
  final EncryptedPairingStorage storage;
  final Uuid _uuid = const Uuid();
  ActivePairCode? _activeCode;
  void Function()? onPairedDevicesChanged;

  PairingService({required this.storage});

  ActivePairCode getOrGeneratePairCode() {
    if (_activeCode != null && !_activeCode!.isExpired) {
      return _activeCode!;
    }

    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();
    _activeCode = ActivePairCode(
      code: pin,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    return _activeCode!;
  }

  bool validatePairCode(String code) {
    if (_activeCode == null || _activeCode!.isExpired) return false;
    return _activeCode!.code.trim() == code.trim();
  }

  Future<PairedDeviceModel?> handlePairingRequest({
    required String pairCode,
    required String peerDeviceId,
    required String peerAlias,
    required String peerDeviceType,
  }) async {
    if (!validatePairCode(pairCode)) {
      debugPrint('Pair code validation failed for peer: $peerAlias');
      return null;
    }

    final authToken = _uuid.v4();
    final pairedModel = PairedDeviceModel(
      id: peerDeviceId,
      alias: peerAlias,
      deviceType: peerDeviceType,
      authToken: authToken,
      pairedAt: DateTime.now(),
    );

    await storage.savePairedDevice(pairedModel);
    onPairedDevicesChanged?.call();
    debugPrint('Successfully paired with $peerAlias ($peerDeviceId)');
    return pairedModel;
  }

  Future<bool> initiatePairingWithPeer({
    required DeviceModel targetDevice,
    required DeviceModel currentDevice,
    required String pairCode,
  }) async {
    try {
      final url = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/api/pair');
      final body = jsonEncode({
        'pairCode': pairCode,
        'deviceId': currentDevice.id,
        'alias': currentDevice.alias,
        'deviceType': currentDevice.deviceType,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body) as Map<String, dynamic>;
        if (resData['status'] == 'success') {
          final hostAuthToken = resData['authToken'] as String;
          final hostDeviceId = resData['deviceId'] as String;
          final hostAlias = resData['alias'] as String;
          final hostDeviceType = resData['deviceType'] as String? ?? 'unknown';

          final pairedModel = PairedDeviceModel(
            id: hostDeviceId,
            alias: hostAlias,
            deviceType: hostDeviceType,
            authToken: hostAuthToken,
            pairedAt: DateTime.now(),
          );

          await storage.savePairedDevice(pairedModel);
          onPairedDevicesChanged?.call();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error initiating pairing with ${targetDevice.alias}: $e');
      return false;
    }
  }
}
