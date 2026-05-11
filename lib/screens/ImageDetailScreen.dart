// ══════════════════════════════════════════════════════════════════════════════
//  ImageDetailScreen — Çift Tıklama Destekli Modern Resim Galerisi
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class ImageDetailScreen extends StatefulWidget {
  const ImageDetailScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.4), // Şeffaf üst bar
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) {
          final url = widget.imageUrls[index];
          // Her bir resim için kendi zoom mantığını yöneten alt widget'ı çağırıyoruz
          return _ZoomableImage(url: url);
        },
      ),
    );
  }
}

// ── Çift Tıklama ve Animasyonlu Zoom Mantığı ──
class _ZoomableImage extends StatefulWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    // Yağ gibi kayan 300 milisaniyelik zoom animasyonu
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), 
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Kullanıcının nereye dokunduğunu x,y koordinatı olarak kaydeder
  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  // Çift tıklanınca çalışacak matematiksel zoom işlemi
  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    final position = _doubleTapDetails!.localPosition;
    
    // Eğer resim zaten yakınlaştırılmış durumdaysa, orijinal boyuta (1x) geri dön
    final isZoomedIn = _transformationController.value.getMaxScaleOnAxis() > 1.0;
    
    final endMatrix = isZoomedIn
        ? Matrix4.identity() // Geri uzaklaştır
        : (Matrix4.identity()
          ..translate(-position.dx * 2, -position.dy * 2) // Tam tıklanan noktayı merkeze al
          ..scale(3.0)); // O noktaya 3 kat yakınlaş

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeOutCubic).animate(_animationController));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0, // Kullanıcı iki parmağıyla 4 kata kadar yakınlaştırabilir
        panEnabled: true, // Sağa sola ve yukarı aşağı kaydırma
        child: Center(
          child: widget.url.startsWith('http')
              ? Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white30,
                    size: 64,
                  ),
                )
              : const Icon(
                  Icons.image_outlined,
                  color: Colors.white30,
                  size: 64,
                ),
        ),
      ),
    );
  }
}