import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_model.dart';
import '../../providers/app_providers.dart';

class PairingDialog extends ConsumerStatefulWidget {
  final DeviceModel? initialTargetDevice;

  const PairingDialog({super.key, this.initialTargetDevice});

  @override
  ConsumerState<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends ConsumerState<PairingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsRemaining = 300;
  bool _isPairing = false;
  DeviceModel? _selectedTargetDevice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedTargetDevice = widget.initialTargetDevice;
    _startTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  String _formatTimer(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _submitPairCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit pair code.')),
      );
      return;
    }

    final target = _selectedTargetDevice;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target device to pair with.'),
        ),
      );
      return;
    }

    setState(() {
      _isPairing = true;
    });

    final currentDevice = ref.read(currentDeviceProvider);
    final pairingService = ref.read(pairingServiceProvider);

    final success = await pairingService.initiatePairingWithPeer(
      targetDevice: target,
      currentDevice: currentDevice,
      pairCode: code,
    );

    if (!mounted) return;
    setState(() {
      _isPairing = false;
    });

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully paired with ${target.alias}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing failed. Check code or Wi-Fi connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairingService = ref.watch(pairingServiceProvider);
    final activePairCode = pairingService.getOrGeneratePairCode();
    final discoveredDevices =
        ref.watch(discoveredDevicesProvider).value ?? const [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    Icons.phonelink_lock_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Device Pairing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Pair Code'),
                Tab(text: 'Enter Pair Code'),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Show My Code
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Share this 6-digit code with nearby device:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Code Display Box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          activePairCode.code,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Expires in ${_formatTimer(_secondsRemaining)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy Code',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: activePairCode.code),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pair code copied!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Tab 2: Enter Code
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select target device and enter its 6-digit pair code:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Device Selector Dropdown
                      DropdownButtonFormField<DeviceModel>(
                        initialValue: _selectedTargetDevice,
                        decoration: const InputDecoration(
                          labelText: 'Target Device',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: discoveredDevices.map((dev) {
                          return DropdownMenuItem<DeviceModel>(
                            value: dev,
                            child: Text('${dev.alias} (${dev.ip})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedTargetDevice = val;
                          });
                        },
                        hint: const Text('Select a discovered device'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter 6-Digit PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                      const Spacer(),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isPairing ? null : _submitPairCode,
                        icon: _isPairing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.link_rounded),
                        label: Text(_isPairing ? 'Pairing...' : 'Pair Device'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
