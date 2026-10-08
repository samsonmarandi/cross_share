import 'package:path/path.dart' as p;

String fileTypeCategory(String name) {
  final extension = p.extension(name).toLowerCase();
  if ([
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.heic',
    '.bmp',
    '.svg',
  ].contains(extension)) {
    return 'image';
  }
  if ([
    '.mp4',
    '.mkv',
    '.mov',
    '.avi',
    '.webm',
    '.m4v',
    '.flv',
  ].contains(extension)) {
    return 'video';
  }
  if (['.mp3', '.wav', '.flac', '.m4a', '.ogg'].contains(extension)) {
    return 'audio';
  }
  if (extension == '.apk') return 'apk';
  return 'document';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
