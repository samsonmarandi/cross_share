import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/transfer_progress.dart';
import '../../providers/app_providers.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transferHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear History',
              onPressed: () {
                ref.read(transferHistoryProvider.notifier).clearHistory();
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No transfer history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: item.isIncoming
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              child: Icon(
                                item.isIncoming
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: item.isIncoming ? Colors.green : Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.isIncoming
                                        ? 'From: ${item.senderDevice.alias}'
                                        : 'To: ${item.receiverDevice.alias}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${item.files.length} file(s) (${_formatSize(item.totalBytes)})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(item.status),
                          ],
                        ),
                        const Divider(height: 20),
                        Column(
                          children: item.files.map((file) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(_getFileIcon(file.fileType), size: 20),
                              title: Text(
                                file.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(file.formattedSize),
                              trailing: (file.filePath != null &&
                                      File(file.filePath!).existsSync())
                                  ? IconButton(
                                      icon: const Icon(Icons.open_in_new, size: 20),
                                      tooltip: 'Open File',
                                      onPressed: () {
                                        OpenFilex.open(file.filePath!);
                                      },
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(TransferStatus status) {
    Color color;
    String label;

    switch (status) {
      case TransferStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case TransferStatus.failed:
        color = Colors.red;
        label = 'Failed';
        break;
      case TransferStatus.rejected:
        color = Colors.orange;
        label = 'Rejected';
        break;
      case TransferStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled';
        break;
      default:
        color = Colors.blue;
        label = 'In Progress';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
