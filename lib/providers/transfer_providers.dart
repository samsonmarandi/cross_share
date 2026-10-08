import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../models/share_file_model.dart';
import '../models/transfer_progress.dart';

// Connected Target Device State
final connectedDeviceProvider = StateProvider<DeviceModel?>((ref) => null);

// Selected Files to Send
final selectedFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<ShareFileModel>>((ref) {
      return SelectedFilesNotifier();
    });

class SelectedFilesNotifier extends StateNotifier<List<ShareFileModel>> {
  SelectedFilesNotifier() : super([]);

  void addFiles(List<ShareFileModel> files) {
    state = [...state, ...files];
  }

  void removeFile(String id) {
    state = state.where((f) => f.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

// Active Transfer State
final activeTransferProvider =
    StateNotifierProvider<ActiveTransferNotifier, TransferProgress?>((ref) {
      return ActiveTransferNotifier();
    });

class ActiveTransferNotifier extends StateNotifier<TransferProgress?> {
  ActiveTransferNotifier() : super(null);

  void setTransfer(TransferProgress? progress) {
    state = progress;
  }

  void updateProgress(TransferProgress progress) {
    state = progress;
  }

  void clear() {
    state = null;
  }
}

// Transfer History
final transferHistoryProvider =
    StateNotifierProvider<TransferHistoryNotifier, List<TransferProgress>>((
      ref,
    ) {
      return TransferHistoryNotifier();
    });

class TransferHistoryNotifier extends StateNotifier<List<TransferProgress>> {
  TransferHistoryNotifier() : super([]);

  void addTransfer(TransferProgress transfer) {
    state = [transfer, ...state];
  }

  void clearHistory() {
    state = [];
  }
}
