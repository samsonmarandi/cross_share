import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String?> getLocalIp() async {
    if (!kIsWeb) {
      try {
        final wifiIp = await _networkInfo.getWifiIP();
        if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '127.0.0.1') {
          return wifiIp;
        }
      } catch (e) {
        debugPrint('Error getting Wi-Fi IP: $e');
      }

      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );

        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      } catch (e) {
        debugPrint('Error listing network interfaces: $e');
      }
    }
    return '127.0.0.1';
  }

  Future<String> getDeviceName() async {
    try {
      if (kIsWeb) return 'Web Browser';
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        return '${android.brand.toUpperCase()} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        return ios.name;
      } else if (Platform.isMacOS) {
        final mac = await _deviceInfo.macOsInfo;
        return mac.computerName;
      } else if (Platform.isWindows) {
        final win = await _deviceInfo.windowsInfo;
        return win.computerName;
      } else if (Platform.isLinux) {
        final linux = await _deviceInfo.linuxInfo;
        return linux.prettyName;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return 'CrossShare Device';
  }

  String getDeviceOsType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
