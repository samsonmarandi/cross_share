import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings
final autoAcceptProvider = StateProvider<bool>((ref) => false);
final customDownloadPathProvider = StateProvider<String?>((ref) => null);
