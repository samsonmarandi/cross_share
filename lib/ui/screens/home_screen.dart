import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transfer_progress.dart';
import '../../providers/app_providers.dart';
import '../widgets/transfer_dialog.dart';
import 'history_tab.dart';
import 'receive_tab.dart';
import 'send_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSession();
    });
  }

  Future<void> _startSession() async {
    try {
      await ref.read(sessionProvider).start(_requestApproval);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start sharing: $error')),
      );
    }
  }

  Future<bool> _requestApproval(TransferProgress progress) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => TransferRequestDialog(
            progress: progress,
            onAccept: () => Navigator.pop(context, true),
            onReject: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }

  final List<Widget> _screens = const [
    SendTab(),
    ReceiveTab(),
    HistoryTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'CrossShare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Scan Subnet',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanning local network subnet...'),
                    duration: Duration(seconds: 2),
                  ),
                );
                await ref.read(discoveryServiceProvider).scanLocalSubnet();
              },
            ),
            IconButton(
              icon: const Icon(Icons.sensors_rounded),
              tooltip: 'Announce Presence',
              onPressed: () {
                ref.read(discoveryServiceProvider).announcePresence();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Broadcasting presence on LAN...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send_rounded),
            label: 'Send',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: 'Receive',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
