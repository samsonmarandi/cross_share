import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/paired_device_model.dart';
import '../../providers/app_providers.dart';
import '../widgets/pairing_dialog.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentDevice = ref.read(currentDeviceProvider);
      _nameController.text = currentDevice.alias;
      ref.read(pairedDevicesProvider.notifier).loadDevices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDownloadPath() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (!mounted) return;
    if (selectedDirectory != null) {
      ref.read(customDownloadPathProvider.notifier).state = selectedDirectory;
    }
  }

  void _openPairingDialog() {
    showDialog<bool>(
      context: context,
      builder: (context) => const PairingDialog(),
    );
  }

  Future<void> _unpairDevice(PairedDeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: Text(
          'Remove ${device.alias} from trusted paired devices? Automatic background transfers will no longer be approved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(pairedDevicesProvider.notifier).removePairedDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unpaired ${device.alias}.')),
        );
      }
    }
  }

  IconData _getOsIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
      case 'windows':
      case 'linux':
      case 'desktop':
        return Icons.laptop_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final customPath = ref.watch(customDownloadPathProvider);
    final pairedDevices = ref.watch(pairedDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Name Setting
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Name',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter device name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.trim().isNotEmpty) {
                            ref
                                .read(currentDeviceProvider.notifier)
                                .setDeviceName(_nameController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Device name updated!'),
                              ),
                            );
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Device Pairing Section
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trusted Paired Devices',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openPairingDialog,
                        icon: const Icon(Icons.add_link_rounded, size: 18),
                        label: const Text('Pair Device'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paired devices automatically connect on the local Wi-Fi and allow instant file transfers without popups.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  if (pairedDevices.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'No paired devices yet. Tap Pair Device to pair with a 6-digit code.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pairedDevices.length,
                      itemBuilder: (context, index) {
                        final paired = pairedDevices[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              _getOsIcon(paired.deviceType),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            paired.alias,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Paired ${paired.pairedAt.day}/${paired.pairedAt.month}/${paired.pairedAt.year}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.link_off_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Unpair Device',
                            onPressed: () => _unpairDevice(paired),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Download Location Setting
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Download Location'),
              subtitle: Text(
                customPath ?? 'Default Downloads/CrossShare folder',
              ),
              trailing: const Icon(Icons.edit),
              onTap: _pickDownloadPath,
            ),
          ),
          const SizedBox(height: 16),

          // Network Info
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi),
                  title: const Text('Local IP Address'),
                  subtitle: Text(currentDevice.ip),
                ),
                ListTile(
                  leading: const Icon(Icons.router),
                  title: const Text('Server Port'),
                  subtitle: Text('${currentDevice.port}'),
                ),
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Platform OS'),
                  subtitle: Text(currentDevice.deviceType.toUpperCase()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          const Center(
            child: Column(
              children: [
                Text(
                  'CrossShare v1.0.0',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cross-Platform Encrypted LAN File Sharing',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
