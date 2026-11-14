import 'package:material_ui/material_ui.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/theme/el_theme.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.audioId,
    this.size = 44,
    this.borderRadius = ElThemeTokens.radiusThumbnail,
    this.iconSize = 22,
  });

  final int audioId;
  final double size;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final el = context.el;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: el.bgColorPage,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: el.borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: audioId <= 0
          ? Center(
              child: Icon(
                Icons.music_note_rounded,
                size: iconSize,
                color: el.textColorSecondary,
              ),
            )
          : QueryArtworkWidget(
        id: audioId,
        type: ArtworkType.AUDIO,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.circular(borderRadius),
        keepOldArtwork: true,
        nullArtworkWidget: Center(
          child: Icon(
            Icons.music_note_rounded,
            size: iconSize,
            color: el.textColorSecondary,
          ),
        ),
      ),
    );
  }
}
