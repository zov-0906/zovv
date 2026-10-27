class DanmakuItem {
  const DanmakuItem({required this.time, required this.text});
  final Duration time;
  final String text;
  static DanmakuItem? fromJson(Object? raw) {
    if (raw is! Map || raw['timeMs'] is! int || raw['text'] is! String) {
      return null;
    }
    final time = raw['timeMs'] as int;
    final text = (raw['text'] as String)
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
        .trim();
    if (time < 0 || time > 86400000 || text.isEmpty) return null;
    return DanmakuItem(
      time: Duration(milliseconds: time),
      text: text.length > 120 ? text.substring(0, 120) : text,
    );
  }
}

class DanmakuWindow {
  const DanmakuWindow({
    required this.available,
    this.items = const [],
    this.notice = '',
  });
  final bool available;
  final List<DanmakuItem> items;
  final String notice;
}

abstract interface class EpisodeDanmakuSource {
  Future<DanmakuWindow> fetchDanmakuWindow(
    String dramaId,
    String episodeId, {
    required Duration start,
    required Duration duration,
  });
}
