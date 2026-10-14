import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/paired_device_model.dart';

class EncryptedPairingStorage {
  final String _keySalt = 'CrossShare_Storage_Key_Salt_v1_2026';
  File? _cachedFile;

  Future<File> _getStorageFile() async {
    if (_cachedFile != null) return _cachedFile!;
    Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }
    _cachedFile = File(p.join(dir.path, 'paired_devices.enc'));
    return _cachedFile!;
  }

  Uint8List _encryptDecrypt(Uint8List input, String saltKey) {
    final keyBytes = sha256.convert(utf8.encode(saltKey)).bytes;
    final output = Uint8List(input.length);

    for (int i = 0; i < input.length; i++) {
      final blockIndex = i ~/ 32;
      final keyBlock = sha256
          .convert([...keyBytes, ...utf8.encode('block_$blockIndex')])
          .bytes;
      final keyByte = keyBlock[i % 32];
      output[i] = input[i] ^ keyByte;
    }

    return output;
  }

  String _encrypt(String plainText) {
    final inputBytes = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = _encryptDecrypt(inputBytes, _keySalt);
    return base64.encode(encryptedBytes);
  }

  String _decrypt(String cipherText) {
    final encryptedBytes = base64.decode(cipherText);
    final decryptedBytes = _encryptDecrypt(
      Uint8List.fromList(encryptedBytes),
      _keySalt,
    );
    return utf8.decode(decryptedBytes);
  }

  Future<List<PairedDeviceModel>> loadPairedDevices() async {
    try {
      final file = await _getStorageFile();
      if (!await file.exists()) return [];

      final encryptedContent = await file.readAsString();
      if (encryptedContent.trim().isEmpty) return [];

      final decryptedJson = _decrypt(encryptedContent.trim());
      final List<dynamic> list = jsonDecode(decryptedJson);

      return list
          .map((item) => PairedDeviceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading encrypted paired devices: $e');
      return [];
    }
  }

  Future<void> savePairedDevice(PairedDeviceModel device) async {
    final currentList = await loadPairedDevices();
    final updatedList = [
      ...currentList.where((d) => d.id != device.id),
      device,
    ];

    await _saveAll(updatedList);
  }

  Future<void> removePairedDevice(String deviceId) async {
    final currentList = await loadPairedDevices();
    final updatedList = currentList.where((d) => d.id != deviceId).toList();
    await _saveAll(updatedList);
  }

  Future<void> _saveAll(List<PairedDeviceModel> devices) async {
    try {
      final file = await _getStorageFile();
      final plainJson = jsonEncode(devices.map((d) => d.toJson()).toList());
      final encryptedContent = _encrypt(plainJson);

      await file.writeAsString(encryptedContent, flush: true);
    } catch (e) {
      debugPrint('Error writing encrypted paired devices: $e');
    }
  }

  Future<PairedDeviceModel?> getPairedDevice(String deviceId) async {
    final devices = await loadPairedDevices();
    for (final d in devices) {
      if (d.id == deviceId) return d;
    }
    return null;
  }

  Future<bool> isDevicePaired(String deviceId) async {
    final device = await getPairedDevice(deviceId);
    return device != null;
  }
}
