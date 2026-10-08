import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final customPath = ref.watch(customDownloadPathProvider);

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
                  'Cross-Platform LAN File Sharing',
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
