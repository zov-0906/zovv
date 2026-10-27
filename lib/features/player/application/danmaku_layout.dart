import '../../drama/domain/danmaku.dart';

class DanmakuFlight {
  const DanmakuFlight(this.item, this.lane, this.width);
  final DanmakuItem item;
  final int lane;
  final double width;
}

/// Equal travel velocity lets each lane admit the next text only after the
/// previous text's tail has cleared the entry edge, preventing overtaking.
List<DanmakuFlight> layoutDanmaku(
  List<DanmakuItem> items,
  double Function(String) widthFor, {
  int lanes = 3,
  double velocity = 90,
}) {
  final ready = List<double>.filled(lanes, double.negativeInfinity);
  final sorted = [...items]..sort((a, b) => a.time.compareTo(b.time));
  final result = <DanmakuFlight>[];
  for (final item in sorted) {
    final time = item.time.inMilliseconds / 1000;
    final lane = ready.indexWhere((value) => value <= time);
    if (lane < 0) continue;
    final width = widthFor(item.text);
    ready[lane] = time + (width + 20) / velocity;
    result.add(DanmakuFlight(item, lane, width));
  }
  return result;
}
