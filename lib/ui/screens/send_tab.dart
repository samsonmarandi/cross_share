import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import '../../utils/file_metadata.dart';
import 'package:uuid/uuid.dart';

import '../../models/device_model.dart';
import '../../models/share_file_model.dart';
import '../../providers/app_providers.dart';
import '../widgets/radar_device_view.dart';
import '../widgets/transfer_dialog.dart';

class SendTab extends ConsumerStatefulWidget {
  const SendTab({super.key});

  @override
  ConsumerState<SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<SendTab> {
  final Uuid _uuid = const Uuid();

  Future<void> _pickFiles(FileType type) async {
    try {
      FileType pickerType = type;
      List<String>? allowedExtensions;

      // On macOS & desktop platforms, FileType.image or FileType.video require explicit allowedExtensions
      if (type == FileType.image) {
        pickerType = FileType.custom;
        allowedExtensions = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'bmp',
          'svg',
        ];
      } else if (type == FileType.video) {
        pickerType = FileType.custom;
        allowedExtensions = ['mp4', 'mov', 'mkv', 'avi', 'webm', 'm4v', 'flv'];
      }

      final messenger = ScaffoldMessenger.of(context);

      final result = await FilePicker.platform.pickFiles(
        type: pickerType,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files
            .map((f) {
              final path = f.path;
              final name = f.name;
              final size = f.size;
              final mime =
                  lookupMimeType(path ?? name) ?? 'application/octet-stream';

              return ShareFileModel(
                id: _uuid.v4(),
                fileName: name,
                filePath: path,
                size: size,
                mimeType: mime,
                fileType: fileTypeCategory(name),
              );
            })
            .where((f) => f.filePath != null && f.filePath!.isNotEmpty)
            .toList();

        if (newFiles.isNotEmpty) {
          ref.read(selectedFilesProvider.notifier).addFiles(newFiles);
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not access paths of selected files.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error selecting files: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
      }
    }
  }

  void _addTextSnippet() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share Text / Clipboard'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Type or paste text content to send...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final text = controller.text.trim();
                  final fileModel = ShareFileModel(
                    id: _uuid.v4(),
                    fileName:
                        'text_${DateTime.now().millisecondsSinceEpoch}.txt',
                    size: utf8.encode(text).length,
                    mimeType: 'text/plain',
                    fileType: 'text',
                    textContent: text,
                  );
                  ref.read(selectedFilesProvider.notifier).addFiles([
                    fileModel,
                  ]);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Text'),
            ),
          ],
        );
      },
    );
  }

  void _showConnectByIpDialog() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Connect via IP Address'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the local IP address shown on the Receive tab of the target device:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 192.168.1.150',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Connecting to target device...'),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final ip = controller.text.trim();
                          if (ip.isNotEmpty) {
                            setDialogState(() {
                              isLoading = true;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final discovery = ref.read(
                              discoveryServiceProvider,
                            );
                            final device = await discovery.connectToIp(ip);
                            navigator.pop();
                            if (device != null) {
                              _showDeviceConnectPrompt(device);
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not connect. Ensure both devices are on the same Wi-Fi.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeviceConnectPrompt(DeviceModel device) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _getOsIcon(device.deviceType),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.alias,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'IP: ${device.ip}:${device.port}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            'Connect to ${device.alias} as your target transfer device?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(connectedDeviceProvider.notifier).state = device;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connected to ${device.alias}! You can now select files and transfer.',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  IconData _getOsIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
      case 'windows':
      case 'linux':
      case 'desktop':
        return Icons.laptop;
      default:
        return Icons.devices;
    }
  }

  Future<void> _startTransferToDevice(DeviceModel targetDevice) async {
    final selectedFiles = ref.read(selectedFilesProvider);
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to send.'),
        ),
      );
      return;
    }

    final engine = ref.read(transferEngineProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final activeTransfer = ref.watch(activeTransferProvider);
            if (activeTransfer == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return TransferProgressDialog(
              progress: activeTransfer,
              onCancel: () {
                engine.cancelTransfer();
              },
            );
          },
        );
      },
    );

    await ref.read(sessionProvider).sendSelectedFiles(targetDevice);
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final discoveredDevicesAsync = ref.watch(discoveredDevicesProvider);

    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

    return Scaffold(
      body: Column(
        children: [
          // Connected Target Banner
          if (connectedDevice != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Colors.green, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected Target: ${connectedDevice.alias}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'IP: ${connectedDevice.ip}:${connectedDevice.port}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Disconnect Target',
                    onPressed: () {
                      ref.read(connectedDeviceProvider.notifier).state = null;
                    },
                  ),
                ],
              ),
            ),
          ],

          // File Picker Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerButton(
                  icon: Icons.folder,
                  label: 'Files',
                  onTap: () => _pickFiles(FileType.any),
                ),
                _buildPickerButton(
                  icon: Icons.image,
                  label: 'Photos',
                  onTap: () => _pickFiles(FileType.image),
                ),
                _buildPickerButton(
                  icon: Icons.videocam,
                  label: 'Videos',
                  onTap: () => _pickFiles(FileType.video),
                ),
                _buildPickerButton(
                  icon: Icons.notes,
                  label: 'Text',
                  onTap: _addTextSnippet,
                ),
              ],
            ),
          ),

          // Selected Files List
          if (selectedFiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Files (${selectedFiles.length}) - ${formatBytes(totalSize)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(selectedFilesProvider.notifier).clear(),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = selectedFiles[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_getFileIcon(file.fileType), size: 24),
                            const Spacer(),
                            Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              file.formattedSize,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () => ref
                                .read(selectedFilesProvider.notifier)
                                .removeFile(file.id),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Separate Transfer Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(
                    connectedDevice != null
                        ? 'Transfer ${selectedFiles.length} File(s) to ${connectedDevice.alias}'
                        : 'Select a Connected Device on Radar to Transfer',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (connectedDevice == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please tap a device on the radar to connect first.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      _startTransferToDevice(connectedDevice);
                    }
                  },
                ),
              ),
            ),
            const Divider(height: 1),
          ],

          // Direct Connect & Subnet Scan Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lan, size: 18),
                    label: const Text('Connect via IP'),
                    onPressed: _showConnectByIpDialog,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Scan Subnet'),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sweeping local network subnet for active devices...',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await ref.read(discoveryServiceProvider).scanLocalSubnet();
                  },
                ),
              ],
            ),
          ),

          // Radar Devices View
          Expanded(
            child: discoveredDevicesAsync.when(
              data: (devices) {
                return RadarDeviceView(
                  devices: devices,
                  onDeviceSelected: (device) =>
                      _showDeviceConnectPrompt(device),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => RadarDeviceView(
                devices: const [],
                onDeviceSelected: (device) => _showDeviceConnectPrompt(device),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.movie;
      case 'audio':
        return Icons.audiotrack;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }
}
