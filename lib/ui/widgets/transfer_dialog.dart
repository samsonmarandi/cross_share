import 'package:flutter/material.dart';

import '../../models/transfer_progress.dart';

class TransferRequestDialog extends StatelessWidget {
  final TransferProgress progress;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const TransferRequestDialog({
    super.key,
    required this.progress,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.downloading, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Incoming Files Request'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${progress.senderDevice.alias} wants to send you ${progress.files.length} file(s).',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: progress.files.take(3).map((file) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(_getFileIcon(file.fileType), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        file.formattedSize,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (progress.files.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ ${progress.files.length - 3} more file(s)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onReject,
          child: const Text('Decline', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Accept & Save'),
        ),
      ],
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

class TransferProgressDialog extends StatelessWidget {
  final TransferProgress progress;
  final VoidCallback onCancel;

  const TransferProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = progress.status == TransferStatus.completed ||
        progress.status == TransferStatus.failed ||
        progress.status == TransferStatus.cancelled ||
        progress.status == TransferStatus.rejected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  progress.isIncoming ? Icons.download : Icons.upload,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    progress.isIncoming
                        ? 'Receiving from ${progress.senderDevice.alias}'
                        : 'Sending to ${progress.receiverDevice.alias}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.progressPercentage,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                color: _getStatusColor(progress.status),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress.progressPercentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  progress.formattedSpeed,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              _getStatusText(progress),
              style: TextStyle(
                color: _getStatusColor(progress.status),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            if (!isFinished)
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Cancel Transfer'),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
      case TransferStatus.rejected:
      case TransferStatus.cancelled:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(TransferProgress progress) {
    switch (progress.status) {
      case TransferStatus.pending:
        return 'Waiting for confirmation...';
      case TransferStatus.connecting:
        return 'Connecting to target device...';
      case TransferStatus.transferring:
        return 'Transferring files...';
      case TransferStatus.completed:
        return 'Transfer completed successfully! 🎉';
      case TransferStatus.rejected:
        return 'Transfer was declined by recipient.';
      case TransferStatus.cancelled:
        return 'Transfer cancelled.';
      case TransferStatus.failed:
        return 'Failed: ${progress.errorMessage ?? "Network error"}';
    }
  }
}
