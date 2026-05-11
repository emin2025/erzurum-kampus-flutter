import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';

// TODO (video_player): pubspec.yaml'a ekle:
//   video_player: ^2.9.1
//   chewie: ^1.8.1        (kontroller UI için)
//
// Sonra import'ları aç:
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';

/// Java'daki VideoViewPagerAdapter'ın Flutter karşılığı.
///
/// - Her video URL için ayrı bir player yönetir (lazy init).
/// - Sayfa değiştiğinde aktif olmayan playerlar duraklatılır.
/// - [onFullscreen] callback'i ile tam ekrana geçiş sağlanır.
/// - dispose() çağrısında tüm playerlar serbest bırakılır.
///
/// Java'daki stopAllPlayersExcept() → [_pauseAllExcept()]
/// Java'daki releaseAllPlayers()    → [dispose()]
class VideoPager extends StatefulWidget {
  const VideoPager({
    super.key,
    required this.videoUrls,
    this.onFullscreen,
    this.onClose,
  });

  final List<String> videoUrls;
  final void Function(String url, Duration position)? onFullscreen;
  final VoidCallback? onClose;

  @override
  State<VideoPager> createState() => VideoPagerState();
}

class VideoPagerState extends State<VideoPager> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Java'daki List<ExoPlayer> players karşılığı
  // TODO (video_player): List<VideoPlayerController?> _controllers = [];
  // TODO (video_player): List<ChewieController?> _chewieControllers = [];

  @override
  void initState() {
    super.initState();
    // TODO (video_player): _controllers = List.filled(widget.videoUrls.length, null);
    // TODO (video_player): _chewieControllers = List.filled(widget.videoUrls.length, null);
    // TODO (video_player): _initPlayer(0); // İlk video'yu başlat
  }

  @override
  void dispose() {
    // Java'daki releaseAllPlayers()
    // TODO (video_player):
    // for (final c in _controllers) { c?.dispose(); }
    // for (final c in _chewieControllers) { c?.dispose(); }
    _pageController.dispose();
    super.dispose();
  }

  // Java'daki stopAllPlayersExcept(position)
  void _pauseAllExcept(int activeIndex) {
    // TODO (video_player):
    // for (int i = 0; i < _controllers.length; i++) {
    //   final ctrl = _controllers[i];
    //   if (ctrl == null) continue;
    //   if (i == activeIndex) {
    //     ctrl.play();
    //   } else {
    //     ctrl.pause();
    //     ctrl.seekTo(Duration.zero);
    //   }
    // }
  }

  // Dışarıdan durdurma (VideoPlayerManager tarafından çağrılır)
  void pause() {
    // TODO (video_player): _controllers[_currentPage]?.pause();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.videoUrls.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _pauseAllExcept(i);
              // TODO (video_player): _initPlayer(i); // lazy init
            },
            itemBuilder: (_, i) {
              // TODO (video_player): Gerçek oynatıcıyı göster:
              // final ctrl = _controllers[i];
              // if (ctrl != null && ctrl.value.isInitialized) {
              //   return Chewie(controller: _chewieControllers[i]!);
              // }
              return _VideoPlaceholder(
                url: widget.videoUrls[i],
                onPlay: () {
                  // TODO (video_player): _initPlayer(i).then((_) => _controllers[i]?.play());
                },
              );
            },
          ),

          // Fullscreen butonu
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                // TODO (video_player):
                // final ctrl = _controllers[_currentPage];
                // if (ctrl != null) {
                //   widget.onFullscreen?.call(
                //     widget.videoUrls[_currentPage],
                //     ctrl.value.position,
                //   );
                //   ctrl.pause();
                // }
                widget.onFullscreen?.call(widget.videoUrls[_currentPage], Duration.zero);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
              ),
            ),
          ),

          // Dots indicator (birden fazla video için)
          if (widget.videoUrls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.videoUrls.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Video yüklenene kadar gösterilen placeholder ──────────────────────────────
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.url, required this.onPlay});
  final String url;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Video yükleniyor…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}