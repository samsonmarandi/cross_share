import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../models/device_model.dart';
import '../../models/share_file_model.dart';
import '../../providers/app_providers.dart';
import '../../utils/file_metadata.dart';
import '../widgets/device_picker_dialog.dart';
import '../widgets/pairing_dialog.dart';
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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

  void _showAddFilesBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Content to Share',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPickerItem(
                      icon: Icons.folder_rounded,
                      color: Colors.blue,
                      label: 'Files',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFiles(FileType.any);
                      },
                    ),
                    _buildPickerItem(
                      icon: Icons.image_rounded,
                      color: Colors.purple,
                      label: 'Photos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFiles(FileType.image);
                      },
                    ),
                    _buildPickerItem(
                      icon: Icons.videocam_rounded,
                      color: Colors.redAccent,
                      label: 'Videos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFiles(FileType.video);
                      },
                    ),
                    _buildPickerItem(
                      icon: Icons.notes_rounded,
                      color: Colors.amber.shade800,
                      label: 'Text',
                      onTap: () {
                        Navigator.pop(context);
                        _addTextSnippet();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSelectedFilesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final files = ref.watch(selectedFilesProvider);
            final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);

            if (files.isEmpty) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No files selected yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddFilesBottomSheet();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Files'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.85,
              minChildSize: 0.3,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Files (${files.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text('Clear All'),
                            onPressed: () {
                              ref.read(selectedFilesProvider.notifier).clear();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Total size: ${formatBytes(totalSize)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getFileIcon(file.fileType),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(file.formattedSize),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                ref
                                    .read(selectedFilesProvider.notifier)
                                    .removeFile(file.id);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
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
                              _handleDeviceSelection(device);
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

  void _handleDeviceSelection(DeviceModel device) {
    final pairedDevices = ref.read(pairedDevicesProvider);
    final isPaired = pairedDevices.any((d) => d.id == device.id);

    if (isPaired) {
      ref.read(connectedDeviceProvider.notifier).state = device;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to paired device ${device.alias}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showDeviceConnectPrompt(device);
    }
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
            OutlinedButton.icon(
              icon: const Icon(Icons.phonelink_lock_rounded, size: 16),
              label: const Text('Pair Device'),
              onPressed: () async {
                Navigator.pop(context);
                final paired = await showDialog<bool>(
                  context: context,
                  builder: (context) => PairingDialog(initialTargetDevice: device),
                );
                if (paired == true && mounted) {
                  ref.read(connectedDeviceProvider.notifier).state = device;
                }
              },
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(connectedDeviceProvider.notifier).state = device;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connected to ${device.alias}! Ready to transfer.',
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

  Future<void> _showDevicePickerAndSend() async {
    final connectedDevice = ref.read(connectedDeviceProvider);
    final selectedDevices = await showDialog<List<DeviceModel>>(
      context: context,
      builder: (context) => DevicePickerDialog(preselectedDevice: connectedDevice),
    );

    if (selectedDevices != null && selectedDevices.isNotEmpty) {
      _startBatchTransfer(selectedDevices);
    }
  }

  Future<void> _sendToAllDevices() async {
    final discoveredDevices = ref.read(discoveredDevicesProvider).value ?? [];
    if (discoveredDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active devices found on local network.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to All Devices'),
        content: Text(
          'Send selected file(s) to all ${discoveredDevices.length} active device(s) on your local network?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.hub_rounded, size: 18),
            label: const Text('Send to All'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _startBatchTransfer(discoveredDevices);
    }
  }

  Future<void> _startBatchTransfer(List<DeviceModel> targetDevices) async {
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

    await ref.read(sessionProvider).sendSelectedFilesToMultiple(targetDevices);
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

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.movie_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'apk':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildPickerItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final discoveredDevicesAsync = ref.watch(discoveredDevicesProvider);
    final pairedDevices = ref.watch(pairedDevicesProvider);

    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.size);
    final pairedIds = pairedDevices.map((d) => d.id).toList();

    // Auto-connect to a discovered paired device if not connected yet
    discoveredDevicesAsync.whenData((devices) {
      if (connectedDevice == null) {
        final pairedMatch = devices.where((d) => pairedIds.contains(d.id));
        if (pairedMatch.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ref.read(connectedDeviceProvider) == null) {
              ref.read(connectedDeviceProvider.notifier).state = pairedMatch.first;
            }
          });
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background Hero Radar Canvas
          Positioned.fill(
            child: discoveredDevicesAsync.when(
              data: (devices) {
                return RadarDeviceView(
                  devices: devices,
                  pairedDeviceIds: pairedIds,
                  onDeviceSelected: (device) => _handleDeviceSelection(device),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => RadarDeviceView(
                devices: const [],
                pairedDeviceIds: pairedIds,
                onDeviceSelected: (device) => _handleDeviceSelection(device),
              ),
            ),
          ),

          // Top Floating Bar (Connected Target & IP Connect)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                if (connectedDevice != null) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pairedIds.contains(connectedDevice.id)
                                ? Icons.link_rounded
                                : Icons.circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Target: ${connectedDevice.alias}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(connectedDeviceProvider.notifier)
                                  .state = null;
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.cancel_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Spacer(),
                ],

                // IP Connect Action Button
                Material(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  elevation: 3,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _showConnectByIpDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lan_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'IP Connect',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Floating Controls (Selected Files Tray & Add Content FAB)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedFiles.isNotEmpty) ...[
                  // Floating Selected Files Tray
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showSelectedFilesModal,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${selectedFiles.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Files Ready',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      formatBytes(totalSize),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Add More Button
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            tooltip: 'Add More Files',
                            onPressed: _showAddFilesBottomSheet,
                          ),

                          const SizedBox(width: 4),

                          // Send To... Button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(Icons.devices_rounded, size: 16),
                            label: const Text('Send To...'),
                            onPressed: _showDevicePickerAndSend,
                          ),

                          const SizedBox(width: 6),

                          // Send to All Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(Icons.hub_rounded, size: 16),
                            label: const Text('Send to All'),
                            onPressed: _sendToAllDevices,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Floating Add Content Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'add_files_fab',
                        onPressed: _showAddFilesBottomSheet,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Content'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
