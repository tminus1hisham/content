import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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
    final label = switch (post.access) {
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
        const ColoredBox(color: Colors.black45),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
