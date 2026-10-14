import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_model.dart';
import '../../providers/app_providers.dart';

class DevicePickerDialog extends ConsumerStatefulWidget {
  final DeviceModel? preselectedDevice;

  const DevicePickerDialog({super.key, this.preselectedDevice});

  @override
  ConsumerState<DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends ConsumerState<DevicePickerDialog> {
  final Set<String> _selectedDeviceIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.preselectedDevice != null) {
      _selectedDeviceIds.add(widget.preselectedDevice!.id);
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
    final discoveredDevices =
        ref.watch(discoveredDevicesProvider).value ?? const [];
    final pairedDevices = ref.watch(pairedDevicesProvider);
    final pairedIds = pairedDevices.map((d) => d.id).toSet();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.devices_other_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Target Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text(
              'Choose which devices on your local network to send selected file(s) to:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Select All Toggle
            if (discoveredDevices.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Devices (${discoveredDevices.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedDeviceIds.length == discoveredDevices.length) {
                          _selectedDeviceIds.clear();
                        } else {
                          _selectedDeviceIds.addAll(discoveredDevices.map((d) => d.id));
                        }
                      });
                    },
                    child: Text(
                      _selectedDeviceIds.length == discoveredDevices.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

            const Divider(height: 16),

            // Discovered Devices Checkbox List
            Expanded(
              child: discoveredDevices.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar_rounded, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Searching for nearby devices on LAN...',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = discoveredDevices[index];
                        final isSelected = _selectedDeviceIds.contains(device.id);
                        final isPaired = pairedIds.contains(device.id);

                        return CheckboxListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDeviceIds.add(device.id);
                              } else {
                                _selectedDeviceIds.remove(device.id);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundColor: isPaired
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              _getOsIcon(device.deviceType),
                              color: isPaired ? Colors.green : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  device.alias,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPaired) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Paired',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'IP: ${device.ip}:${device.port}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Confirm Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _selectedDeviceIds.isEmpty
                  ? null
                  : () {
                      final selectedDevices = discoveredDevices
                          .where((d) => _selectedDeviceIds.contains(d.id))
                          .toList();
                      Navigator.pop(context, selectedDevices);
                    },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                'Send to Selected (${_selectedDeviceIds.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
