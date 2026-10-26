import 'package:flutter/material.dart';

import '../../domain/drama.dart';

class DramaPoster extends StatelessWidget {
  const DramaPoster({super.key, required this.drama, this.showTitle = true});
  final Drama drama;
  final bool showTitle;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image(
        image: drama.poster.startsWith('https://')
            ? NetworkImage(drama.poster)
            : AssetImage(drama.poster) as ImageProvider,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: Color(drama.color)),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .05),
              Colors.black.withValues(alpha: .12),
              Colors.black.withValues(alpha: .72),
            ],
            stops: const [0, .45, 1],
          ),
        ),
      ),
      if (showTitle)
        Positioned(
          left: 16,
          right: 12,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                drama.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                drama.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ),
    ],
  );
}
