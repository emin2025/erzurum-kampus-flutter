import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Java'daki ImageSliderAdapter'ın Flutter karşılığı.
///
/// - Resim URL listesini PageView ile gösterir.
/// - Video thumbnail'ları (videoResimList) sona eklenir, üstüne play ikonu çizilir.
/// - Tıklamada [onImageTap] (resim detay) veya [onVideoThumbnailTap] (video aç) çağrılır.
/// - [isFullscreen] = true olduğunda büyük görüntüleme modundadır.
///
/// Java'daki NORMAL_OPTIONS ≡ centerCrop + cache
/// Java'daki FULLSCREEN_OPTIONS ≡ fitCenter + cache
/// (Flutter'da cached_network_image paketi kurulunca TODO yorumları açılacak)
class ImageSlider extends StatefulWidget {
  const ImageSlider({
    super.key,
    required this.imageUrls,
    this.videoResimUrls = const [],
    this.isFullscreen = false,
    this.onImageTap,
    this.onVideoThumbnailTap,
    this.height = 240,
  });

  final List<String> imageUrls;
  final List<String> videoResimUrls;
  final bool isFullscreen;
  final void Function(int index)? onImageTap;
  final VoidCallback? onVideoThumbnailTap;
  final double height;

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  List<String> get _allItems => [
        ...widget.imageUrls,
        ...widget.videoResimUrls,
      ];

  bool _isVideoItem(int index) => index >= widget.imageUrls.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _allItems;
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── PageView ──────────────────────────────────────────────────
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) {
              final isVideo = _isVideoItem(i);
              return GestureDetector(
                onTap: () {
                  if (isVideo) {
                    widget.onVideoThumbnailTap?.call();
                  } else {
                    if (widget.imageUrls.isNotEmpty) {
                      widget.onImageTap?.call(i);
                    }
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Resim
                    _NetworkImage(
                      url: items[i],
                      fit: widget.isFullscreen ? BoxFit.contain : BoxFit.cover,
                    ),
                    // Video play overlay
                    if (isVideo)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: _PlayIcon(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Sayfa göstergesi (dot indicator) ─────────────────────────
          if (items.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: _DotsIndicator(
                count: items.length,
                current: _currentPage,
              ),
            ),

          // ── Resim sayısı rozeti ───────────────────────────────────────
          if (items.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: _CountBadge(
                current: _currentPage + 1,
                total: items.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt bileşenler
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // TODO: CachedNetworkImage ile değiştir:
    // return CachedNetworkImage(
    //   imageUrl: url,
    //   fit: fit,
    //   placeholder: (_, __) => const _ImagePlaceholder(),
    //   errorWidget: (_, __, ___) => const _ImageError(),
    //   cacheManager: DefaultCacheManager(),
    //   fadeInDuration: const Duration(milliseconds: 200),
    // );

    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const _ImagePlaceholder(),
        errorBuilder: (_, __, ___) => const _ImageError(),
      );
    }
    return const _ImagePlaceholder();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSecondary,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSecondary,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textMuted),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
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
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$current/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}