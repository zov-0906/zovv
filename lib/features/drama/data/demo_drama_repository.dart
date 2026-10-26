import '../domain/drama.dart';

/// Explicit demo catalog. Replace this adapter when a content API is available.
class DemoDramaRepository implements DramaRepository {
  static const _episodes = [
    Episode(id: 'sample-480', title: 'Sintel 预告片 · 480p', number: 1),
    Episode(id: 'sample-720', title: 'Sintel 预告片 · 720p', number: 2),
    Episode(id: 'sample-1080', title: 'Sintel 预告片 · 1080p', number: 3),
  ];
  static const catalog = [
    Drama(
      id: 'evening',
      title: '晚风来信',
      subtitle: '有些相遇，刚好是你。',
      category: '治愈',
      description: '一封没有署名的信，让她重新走进记忆里的小城。那些未曾说出口的话，终于在晚风中有了回音。\n\n这是用于体验产品的虚构剧目，分集播放 Blender 开源短片测试素材，与剧情简介无关。',
      poster: 'assets/posters/evening.jpg',
      color: 0xFFB68B73,
      episodes: _episodes,
    ),
    Drama(
      id: 'night',
      title: '长夜微光',
      subtitle: '循着微光，找到真相。',
      category: '悬疑',
      description: '城市入夜后，一盏始终亮着的灯，串起了三个陌生人的命运。\n\n虚构演示剧目，播放内容为开源短片测试素材。',
      poster: 'assets/posters/night.jpg',
      color: 0xFF647BA4,
      episodes: _episodes,
    ),
    Drama(
      id: 'sea',
      title: '在日落之前',
      subtitle: '把心事，说给海听。',
      category: '都市',
      description: '一次短暂的海边旅行，让两段原本平行的人生有了交点。\n\n虚构演示剧目，播放内容为开源短片测试素材。',
      poster: 'assets/posters/sea.jpg',
      color: 0xFF639DAD,
      episodes: _episodes,
    ),
    Drama(
      id: 'mountain',
      title: '山海之间',
      subtitle: '山海有期，相逢有时。',
      category: '古风',
      description: '越过重重山海，她寻找的答案，藏在一场久别重逢里。\n\n虚构演示剧目，播放内容为开源短片测试素材。',
      poster: 'assets/posters/mountain.jpg',
      color: 0xFF7C9785,
      episodes: _episodes,
    ),
    Drama(
      id: 'moon',
      title: '第二次心动',
      subtitle: '这一次，不再错过。',
      category: '甜宠',
      description: '熟悉的街角，意外的重逢。这次他们决定认真听完彼此的故事。\n\n虚构演示剧目，播放内容为开源短片测试素材。',
      poster: 'assets/posters/moon.jpg',
      color: 0xFF8B83AC,
      episodes: _episodes,
    ),
    Drama(
      id: 'forest',
      title: '明天见',
      subtitle: '平凡日子，也会发光。',
      category: '治愈',
      description: '三位朋友在平凡日常里，慢慢找到属于自己的节奏。\n\n虚构演示剧目，播放内容为开源短片测试素材。',
      poster: 'assets/posters/forest.jpg',
      color: 0xFF698876,
      episodes: _episodes,
    ),
  ];
  @override
  Future<List<Drama>> discover() async => catalog;
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async {
    final drama = catalog.where((item) => item.id == dramaId).firstOrNull;
    if (drama == null || !drama.episodes.any((item) => item.id == episodeId)) {
      throw ArgumentError('未知剧目或分集');
    }
    final quality = episodeId.split('-').last;
    return PlaybackSource(
      uri: Uri.parse(
        'https://download.blender.org/durian/trailer/sintel_trailer-${quality}p.mp4',
      ),
      attribution:
          'Sintel 预告片 © Blender Foundation · CC BY 3.0 · durian.blender.org',
    );
  }
}
