import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/device_model.dart';
import 'network_info_service.dart';

class DiscoveryService {
  DiscoveryService({NetworkInfoService? networkInfo})
    : _networkInfoService = networkInfo ?? NetworkInfoService();

  bool _disposed = false;
  void updateDeviceName(String name) => _currentDeviceName = name;

  static const int discoveryPort = 53317;
  final NetworkInfoService _networkInfoService;

  RawDatagramSocket? _socket;
  Timer? _announcementTimer;
  Timer? _cleanupTimer;
  Timer? _subnetScanTimer;
  bool _isScanningSubnet = false;

  final Map<String, DeviceModel> _discoveredDevices = {};
  final StreamController<List<DeviceModel>> _devicesController =
      StreamController<List<DeviceModel>>.broadcast();

  Stream<List<DeviceModel>> get devicesStream => _devicesController.stream;
  List<DeviceModel> get currentDevices => _discoveredDevices.values.toList();

  String _currentDeviceId = '';
  late String _currentDeviceName;
  late String _currentOsType;
  int _currentHttpPort = 53317;

  Future<void> startDiscovery({
    required String deviceId,
    required String deviceName,
    required int httpPort,
  }) async {
    _currentDeviceId = deviceId;
    _currentDeviceName = deviceName;
    _currentHttpPort = httpPort;
    _currentOsType = _networkInfoService.getDeviceOsType();

    try {
      if (kIsWeb) return; // UDP not available in web directly

      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
          reuseAddress: true,
          reusePort: true,
        );
      } catch (_) {
        try {
          _socket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            discoveryPort,
            reuseAddress: true,
            reusePort: false,
          );
        } catch (_) {
          _socket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            0,
            reuseAddress: true,
          );
        }
      }

      if (_disposed) {
        _socket?.close();
        _socket = null;
        return;
      }
      _socket?.broadcastEnabled = true;
      try {
        _socket?.joinMulticast(InternetAddress('224.0.0.1'));
      } catch (_) {
        // Multicast join might fail on some platforms
      }

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Start periodic UDP announcement
      _announcementTimer?.cancel();
      _announcementTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => announcePresence(),
      );

      // Start periodic stale device cleanup
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _cleanupStaleDevices(),
      );

      // Start periodic local subnet IP sweep (every 20s)
      _subnetScanTimer?.cancel();
      _subnetScanTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => scanLocalSubnet(),
      );

      // Initial announcement & immediate subnet scan
      announcePresence();
      scanLocalSubnet();
    } catch (e) {
      debugPrint('Error starting DiscoveryService: $e');
    }
  }

  Future<void> announcePresence() async {
    if (_socket == null || kIsWeb) return;

    try {
      final myIp = await _networkInfoService.getLocalIp();
      final packet = jsonEncode({
        'type': 'ANNOUNCE',
        'id': _currentDeviceId,
        'alias': _currentDeviceName,
        'ip': myIp,
        'port': _currentHttpPort,
        'deviceType': _currentOsType,
        'isWeb': false,
      });

      final data = utf8.encode(packet);

      // 1. Send to Multicast 224.0.0.1
      try {
        _socket?.send(data, InternetAddress('224.0.0.1'), discoveryPort);
      } catch (e) {
        debugPrint('Multicast send error: $e');
      }

      // 2. Send to Broadcast 255.255.255.255
      try {
        _socket?.send(data, InternetAddress('255.255.255.255'), discoveryPort);
      } catch (e) {
        debugPrint('Broadcast send error: $e');
      }

      // 3. Send to Subnet Broadcast (e.g., 192.168.1.255)
      if (myIp != null && myIp != '127.0.0.1' && myIp.contains('.')) {
        try {
          final parts = myIp.split('.');
          if (parts.length == 4) {
            final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            _socket?.send(
              data,
              InternetAddress(subnetBroadcast),
              discoveryPort,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error announcing presence: $e');
    }
  }

  /// Connect directly to a specific IP address via HTTP handshake
  Future<DeviceModel?> connectToIp(String targetIp, {int port = 53317}) async {
    final client = http.Client();
    try {
      final url = 'http://$targetIp:$port/api/info';
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final device = DeviceModel.fromJson(
          json,
        ).copyWith(ip: targetIp, port: port, lastSeen: DateTime.now());

        if (device.id != _currentDeviceId) {
          _discoveredDevices[device.id] = device;
          if (!_disposed) _devicesController.add(currentDevices);
          return device;
        }
      }
    } catch (_) {
      // Direct connection failed
    } finally {
      client.close();
    }
    return null;
  }

  /// Scans local Wi-Fi subnet in controlled batches (20 IPs at a time) to avoid socket file descriptor exhaustion
  Future<void> scanLocalSubnet() async {
    if (_isScanningSubnet) return; // Prevent overlapping scans
    _isScanningSubnet = true;

    final client = http.Client();
    try {
      final myIp = await _networkInfoService.getLocalIp();
      if (myIp == null || myIp == '127.0.0.1' || !myIp.contains('.')) return;

      final parts = myIp.split('.');
      if (parts.length != 4) return;

      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      // Sweep IPs in batches of 20
      const batchSize = 20;
      for (int i = 1; i <= 254 && !_disposed; i += batchSize) {
        final batch = <Future<void>>[];
        for (int j = i; j < i + batchSize && j <= 254; j++) {
          final hostIp = '$prefix.$j';
          if (hostIp == myIp) continue;

          batch.add(_checkIp(client, hostIp, port: discoveryPort));
        }
        await Future.wait(batch);
      }
    } catch (e) {
      debugPrint('Error scanning local subnet: $e');
    } finally {
      client.close(); // Close HTTP client to release all underlying sockets
      _isScanningSubnet = false;
    }
  }

  Future<void> _checkIp(
    http.Client client,
    String targetIp, {
    int port = 53317,
  }) async {
    try {
      final url = 'http://$targetIp:$port/api/info';
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(milliseconds: 1200));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final device = DeviceModel.fromJson(
          json,
        ).copyWith(ip: targetIp, port: port, lastSeen: DateTime.now());

        if (device.id != _currentDeviceId) {
          _discoveredDevices[device.id] = device;
          if (!_disposed) _devicesController.add(currentDevices);
        }
      }
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final senderIp = datagram.address.address;
      final payload = utf8.decode(datagram.data);
      final json = jsonDecode(payload) as Map<String, dynamic>;

      if (json['type'] == 'ANNOUNCE') {
        final id = json['id'] as String? ?? '';
        // Ignore self announcement
        if (id == _currentDeviceId) return;

        final alias = json['alias'] as String? ?? 'Device';
        final port = (json['port'] as num?)?.toInt() ?? 53317;
        final deviceType = json['deviceType'] as String? ?? 'unknown';

        final device = DeviceModel(
          id: id,
          alias: alias,
          ip: senderIp,
          port: port,
          deviceType: deviceType,
          lastSeen: DateTime.now(),
          isWeb: json['isWeb'] as bool? ?? false,
        );

        _discoveredDevices[id] = device;
        if (!_disposed) _devicesController.add(currentDevices);
      }
    } catch (e) {
      // Ignore malformed datagrams
    }
  }

  void addManualDevice(DeviceModel device) {
    _discoveredDevices[device.id] = device;
    if (!_disposed) _devicesController.add(currentDevices);
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    bool changed = false;

    _discoveredDevices.removeWhere((id, device) {
      final isStale = now.difference(device.lastSeen).inMinutes > 5;
      if (isStale) changed = true;
      return isStale;
    });

    if (changed) {
      if (!_disposed) _devicesController.add(currentDevices);
    }
  }

  void dispose() {
    _disposed = true;
    stopDiscovery();
    _devicesController.close();
  }

  void stopDiscovery() {
    _announcementTimer?.cancel();
    _cleanupTimer?.cancel();
    _subnetScanTimer?.cancel();
    _socket?.close();
    _socket = null;
    _discoveredDevices.clear();
  }
}
