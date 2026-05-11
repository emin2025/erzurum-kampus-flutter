// ══════════════════════════════════════════════════════════════════════════════
//  FullscreenVideoScreen — Modern Tam Ekran Video Oynatıcı
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
// import 'package:erzurum_kampus/theme/app_colors.dart'; // Kendi AppColors yolunu düzelt

class FullscreenVideoScreen extends StatefulWidget {
  const FullscreenVideoScreen({
    super.key,
    required this.videoUrl,
    this.playbackPosition = Duration.zero,
    this.playWhenReady = true,
  });

  final String videoUrl;
  final Duration playbackPosition;
  final bool playWhenReady;

  @override
  State<FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<FullscreenVideoScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  // ── Videoyu ve Arayüzü Hazırlama ──
  Future<void> _initializePlayer() async {
    try {
      // 1. Videoyu internetten çekiyoruz
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      await _videoPlayerController.initialize();
      
      // Eğer videoya ana sayfadan basıldıysa, kaldığı saniyeden başlatır
      if (widget.playbackPosition != Duration.zero) {
        await _videoPlayerController.seekTo(widget.playbackPosition);
      }

      // 2. Chewie ile videonun üzerine oynatma butonlarını (UI) giydiriyoruz
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.playWhenReady,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text(
              'Video oynatılamadı.',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
        // Modern tasarım için ilerleme çubuğu renkleri
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF15C0A4), // Uygulamanın ana vurgu rengi
          handleColor: const Color(0xFF15C0A4),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white60,
        ),
      );

      // Ekranı güncelle
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Video Yükleme Hatası: $e");
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  // ── Hafıza Yönetimi (Memory Leak Önleme) ──
  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sinematik his için saf siyah
      extendBodyBehindAppBar: true,  // Üst bar videonun üstünde şeffaf dursun
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            // Çıkarken videoyu durdur
            _videoPlayerController.pause();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: _hasError
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white30, size: 64),
                  SizedBox(height: 16),
                  Text('Video yüklenirken bir hata oluştu.', style: TextStyle(color: Colors.white54)),
                ],
              )
            : _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(
                    color: Color(0xFF15C0A4), // Yüklenirken dönen çember
                  ),
      ),
    );
  }
}