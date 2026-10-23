import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/ui.dart';
import '../../core/money.dart';
import 'content_api.dart';
import 'fake_content.dart';

/// Shows a media item through its short-lived access URL. Never used for
/// locked posts: those show [LockedMedia] and request nothing.
class MediaView extends ConsumerWidget {
  const MediaView({super.key, required this.mediaId, this.fit = BoxFit.cover});
  final String mediaId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(mediaAccessProvider(mediaId));
    return access.when(
      loading: () => const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
      data: (media) {
        final url = media.url;
        if (media.kind == 'video') {
          return url.startsWith('http')
              ? _NetworkVideo(url: url)
              : const _VideoPlaceholder();
        }
        if (url.startsWith('asset://')) {
          return Image.asset(url.substring('asset://'.length), fit: fit);
        }
        if (url.startsWith('fake-media://')) {
          final bytes = fakeContentDb.media[mediaId]?.bytes;
          return bytes == null
              ? const SizedBox.shrink()
              : Image.memory(bytes, fit: fit);
        }
        return Image.network(url, fit: fit);
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
          Text(
            'Video plays once the API is connected',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _NetworkVideo extends StatefulWidget {
  const _NetworkVideo({required this.url});
  final String url;

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  late final _controller = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () => setState(
        () => _controller.value.isPlaying
            ? _controller.pause()
            : _controller.play(),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            const Icon(Icons.play_arrow, color: Colors.white, size: 64),
        ],
      ),
    );
  }
}

/// Number of generic teaser covers in assets/covers/ (1.jpg … n.jpg).
const lockedCoverCount = 12;

/// What a fan sees instead of restricted media (FR-DIS-003): a generic
/// teaser cover, never the real image or a blur of it, plus what unlocking
/// costs.
class LockedMedia extends StatelessWidget {
  const LockedMedia({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final labelText = switch (post.access) {
      'paid' => 'Unlock for ${formatKes(post.priceCents ?? 0)}',
      'subscribers' => 'Subscribers only',
      'followers' => 'Follow to see this',
      _ => 'Locked',
    };
    // Same post, same cover, so the feed doesn't reshuffle on rebuild.
    final cover =
        post.id.codeUnits.fold(0, (a, b) => a + b) % lockedCoverCount + 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/covers/$cover.jpg', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x99000000)],
            ),
          ),
        ),
        // Grid tiles get a smaller pill so the price is never cut off.
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 260;
            final label = Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(color: Colors.white),
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Glass(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  color: Colors.black.withValues(alpha: 0.35),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: Padding(
                    padding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: compact ? 14 : 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Flexible(child: label),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
