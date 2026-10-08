import '../utils/file_metadata.dart';

class ShareFileModel {
  final String id;
  final String fileName;
  final String? filePath;
  final int size;
  final String mimeType;
  final String fileType; // 'image', 'video', 'audio', 'document', 'text', 'apk'
  final String? textContent;

  ShareFileModel({
    required this.id,
    required this.fileName,
    this.filePath,
    required this.size,
    required this.mimeType,
    required this.fileType,
    this.textContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'size': size,
      'mimeType': mimeType,
      'fileType': fileType,
      'textContent': textContent,
    };
  }

  factory ShareFileModel.fromJson(Map<String, dynamic> json) {
    return ShareFileModel(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'file',
      filePath: json['filePath'] as String?,
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      fileType: json['fileType'] as String? ?? 'document',
      textContent: json['textContent'] as String?,
    );
  }

  String get formattedSize => formatBytes(size);
}
