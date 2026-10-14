import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/app_providers.dart';

class ReceiveTab extends ConsumerWidget {
  const ReceiveTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final autoAccept = ref.watch(autoAcceptProvider);
    final server = ref.watch(httpServerServiceProvider);
    final theme = Theme.of(context);

    final webUrl = 'http://${currentDevice.ip}:${server.port}/web';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Device Active Status Header Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentDevice.alias,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: Colors.green,
                                          size: 8,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Active',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'IP: ${currentDevice.ip}:${server.port}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Web Browser Portal Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Browser Web Sharing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan this QR code or open the URL in any web browser to receive or download files:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // QR Container with clean border/background
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: webUrl,
                            version: QrVersions.auto,
                            size: 180.0,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Copyable URL Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  webUrl,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                tooltip: 'Copy Web Portal URL',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: webUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Web URL copied to clipboard!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Auto-Accept Settings Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Auto-Accept Incoming Files',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Automatically save incoming transfers without popups',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: autoAccept,
                    onChanged: (val) {
                      ref.read(autoAcceptProvider.notifier).state = val;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
