import 'package:zovv/features/drama/domain/watch_progress.dart';

class MemoryLibraryStorage implements LibraryStorage {
  MemoryLibraryStorage([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
