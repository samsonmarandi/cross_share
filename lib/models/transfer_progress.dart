import 'device_model.dart';
import 'share_file_model.dart';

enum TransferStatus {
  pending,
  connecting,
  transferring,
  completed,
  failed,
  rejected,
  cancelled,
}

class TransferProgress {
  final String transferId;
  final DeviceModel senderDevice;
  final DeviceModel receiverDevice;
  final List<ShareFileModel> files;
  final int bytesTransferred;
  final int totalBytes;
  final double speedInBytesPerSec;
  final TransferStatus status;
  final String? errorMessage;
  final bool isIncoming;

  TransferProgress({
    required this.transferId,
    required this.senderDevice,
    required this.receiverDevice,
    required this.files,
    this.bytesTransferred = 0,
    required this.totalBytes,
    this.speedInBytesPerSec = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
    required this.isIncoming,
  });

  double get progressPercentage {
    if (totalBytes <= 0) return 0.0;
    return (bytesTransferred / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (speedInBytesPerSec <= 0) return '0 B/s';
    if (speedInBytesPerSec < 1024) {
      return '${speedInBytesPerSec.toStringAsFixed(0)} B/s';
    }
    if (speedInBytesPerSec < 1024 * 1024) {
      return '${(speedInBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedInBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  TransferProgress copyWith({
    String? transferId,
    DeviceModel? senderDevice,
    DeviceModel? receiverDevice,
    List<ShareFileModel>? files,
    int? bytesTransferred,
    int? totalBytes,
    double? speedInBytesPerSec,
    TransferStatus? status,
    String? errorMessage,
    bool? isIncoming,
  }) {
    return TransferProgress(
      transferId: transferId ?? this.transferId,
      senderDevice: senderDevice ?? this.senderDevice,
      receiverDevice: receiverDevice ?? this.receiverDevice,
      files: files ?? this.files,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speedInBytesPerSec: speedInBytesPerSec ?? this.speedInBytesPerSec,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isIncoming: isIncoming ?? this.isIncoming,
    );
  }
}
