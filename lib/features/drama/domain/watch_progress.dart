class WatchProgress {
  const WatchProgress({
    required this.dramaId,
    required this.episodeIndex,
    required this.positionSeconds,
    required this.updatedAt,
  });
  final String dramaId;
  final int episodeIndex;
  final int positionSeconds;
  final DateTime updatedAt;
  Map<String, Object> toJson() => {
    'dramaId': dramaId,
    'episodeIndex': episodeIndex,
    'positionSeconds': positionSeconds,
    'updatedAt': updatedAt.toIso8601String(),
  };
  static WatchProgress? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['dramaId'];
    final index = value['episodeIndex'];
    final seconds = value['positionSeconds'];
    final date = DateTime.tryParse('${value['updatedAt']}');
    if (id is! String ||
        index is! int ||
        seconds is! int ||
        index < 0 ||
        seconds < 0 ||
        date == null) {
      return null;
    }
    return WatchProgress(
      dramaId: id,
      episodeIndex: index,
      positionSeconds: seconds,
      updatedAt: date,
    );
  }
}

abstract interface class LibraryStorage {
  Future<String?> read();
  Future<void> write(String value);
}
