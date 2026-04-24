// ignore_for_file: avoid_print

import 'package:erzurum_kampus/screens/ChatScreen.dart';
import 'package:erzurum_kampus/screens/FullscreenVideoScreen.dart';
import 'package:erzurum_kampus/screens/ImageDetailScreen.dart';
import 'package:erzurum_kampus/screens/ImageSlider.dart';
import 'package:erzurum_kampus/screens/OfferBottomSheet.dart';
import 'package:erzurum_kampus/screens/Post.dart';
import 'package:erzurum_kampus/screens/PostCacheService.dart';
import 'package:erzurum_kampus/screens/PostOptionsBottomSheet.dart';
import 'package:erzurum_kampus/screens/ProfileScreen.dart';
import 'package:erzurum_kampus/screens/VideoPagerState.dart';
import 'package:erzurum_kampus/screens/VideoPlayerManager.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Java'daki PostAdapter.onBindViewHolder() + PostHolder'ın tam Flutter karşılığı.
///
/// Her kart kendi lifecycle'ını yönetir (StatefulWidget):
///  - Favori durumu + animasyon      (Java: btnFavorite, animateIconChange)
///  - Profil fotoğrafı cache         (Java: yukleProfilFoto)
///  - Kullanıcı adı cache            (Java: yukleKullaniciAdi)
///  - Video var mı? cache            (Java: video_varmi_cached)
///  - Video aç/kapat toggle          (Java: videolariGor onClick)
///  - "Devamını Gör" expand/collapse (Java: txtDevaminiGor onClick)
///  - Teklif Ver bottom sheet        (Java: recyclerVievTeklifVer onClick)
///  - 3-nokta menü                   (Java: btnUcnokta onClick)
///  - Profil, chat, resim navigasyon (Java: startActivity)
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId, required Null Function() onTap, required Null Function() onMessage, required Null Function() onBookmark,
  });

  final Post post;
  final String? currentUserId;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  final _cache = PostCacheService.instance;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isFavorite = false;
  bool _isExpanded = false;
  bool _showingVideo = false;
  bool _isLoadingVideo = false;
  bool _hasVideo = false;
  String? _profileImageUrl;
  String _username = '';
  String _userFirstName = '';
  List<String> _videoUrls = [];

  // ── Favori animasyonu ─────────────────────────────────────────────────────
  late final AnimationController _favAnimCtrl;
  late final Animation<double> _favScaleAnim;

  final GlobalKey<VideoPagerState> _videoPagerKey = GlobalKey();

  Post get _post => widget.post;
  String? get _uid => widget.currentUserId;
  bool get _isOwn => _uid != null && _uid == _post.userId;

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _favAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _favScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 25),
    ]).animate(_favAnimCtrl);

    _loadFavoriteStatus();
    _loadProfileImage();
    _loadUsername();
    _checkVideoAvailability();
  }

  @override
  void dispose() {
    _favAnimCtrl.dispose();
    if (_showingVideo && _post.documentId != null) {
      VideoPlayerManager.instance.clearActive(_post.documentId!);
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERİ YÜKLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadFavoriteStatus() async {
    if (_uid == null || _post.documentId == null) return;
    final v = await _cache.isFavori(
      currentUserId: _uid!,
      postId: _post.documentId!,
    );
    if (mounted) setState(() => _isFavorite = v);
  }

  Future<void> _loadProfileImage() async {
    if (_post.userId == null) return;
    final url = await _cache.getProfilUrl(_post.userId!);
    if (mounted) setState(() => _profileImageUrl = url);
  }

  Future<void> _loadUsername() async {
    if (_post.userId == null) return;
    final info = await _cache.getKullaniciAdi(_post.userId!);
    if (mounted && info != null) {
      setState(() {
        _username = info.tamAd;
        _userFirstName = info.adKucuk;
      });
    }
  }

  Future<void> _checkVideoAvailability() async {
    if (_post.documentId == null) return;
    final v = await _cache.videoVarMi(
      postId: _post.documentId!,
      videoResimFromPost: _post.videoResim,
    );
    if (mounted) setState(() => _hasVideo = v);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FAVORİ TOGGLE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleFavorite() async {
    if (_uid == null) { _guestUyari(); return; }
    if (_post.documentId == null) return;
    _favAnimCtrl.forward(from: 0);
    try {
      final yeni = await _cache.toggleFavori(
        currentUserId: _uid!,
        postId: _post.documentId!,
      );
      if (mounted) {
        setState(() => _isFavorite = yeni);
        _snack(yeni ? 'Favorilere eklendi! ❤️' : 'Favorilerden kaldırıldı. ❤️‍🩹');
      }
    } catch (_) {
      if (mounted) _snack('İşlem sırasında hata oluştu.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VİDEO TOGGLE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleVideo() async {
    if (_showingVideo) {
      if (_post.documentId != null) {
        VideoPlayerManager.instance.clearActive(_post.documentId!);
      }
      if (mounted) setState(() => _showingVideo = false);
      return;
    }
    setState(() => _isLoadingVideo = true);
    final urls = await _cache.getVideoUrls(_post.documentId ?? '');
    if (!mounted) return;
    if (urls.isEmpty) {
      setState(() => _isLoadingVideo = false);
      _snack('Bu ilanda video yok.');
      return;
    }
    setState(() {
      _videoUrls = urls;
      _isLoadingVideo = false;
      _showingVideo = true;
    });
    if (_post.documentId != null) {
      VideoPlayerManager.instance.setActive(
        postId: _post.documentId!,
        pauseCallback: () {
          if (mounted && _showingVideo) {
            _videoPagerKey.currentState?.pause();
            setState(() => _showingVideo = false);
          }
        },
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVİGASYON
  // ══════════════════════════════════════════════════════════════════════════
void _goChat({String? teklifMesaj}) {
  if (_uid == null) { _guestUyari(); return; }
  if (_isOwn) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
    hedefUserId: _post.userId ?? '',
    kategori: _post.kategori,
    teklifMesaj: teklifMesaj,
    // EKSİK OLAN KISIMLAR BURASI:
    teklifPostId: _post.documentId, 
    teklifPostBaslik: _post.aciklama,
    teklifPostResim: _post.gosterilecekResimler != null && _post.gosterilecekResimler!.isNotEmpty ? _post.gosterilecekResimler![0] : null,
    teklifPostFiyat: _post.fiyat,
  )));
}

  void _goProfile() {
    if (_uid == null) { _guestUyari(); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(
      userId: _post.userId ?? '',
      nereden: 'postProfili',
      kategori: _post.kategori,
    )));
  }

  void _goImageDetail(int index) {
    if (_post.gosterilecekResimler?.isEmpty ?? true) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ImageDetailScreen(
      imageUrls: _post.gosterilecekResimler!,
      initialIndex: index,
    )));
  }

  void _goFullscreenVideo(String url, Duration pos) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenVideoScreen(
      videoUrl: url,
      playbackPosition: pos,
    )));
  }

  void _openOffer() {
    if (_uid == null) { _guestUyari(); return; }
    if (_isOwn) return;
    OfferBottomSheet.show(
      context: context,
      fiyatStr: _post.fiyat,
      kategori: _post.kategori ?? '',
      onOfferSelected: (msg) => _goChat(teklifMesaj: msg),
    );
  }

  void _openOptions() {
    PostOptionsBottomSheet.show(
      context: context,
      postId: _post.documentId ?? '',
      isOwner: _isOwn,
      ownerId: _post.userId ?? '',
      kategori: _post.kategori,
    );
  }

  void _guestUyari() {
    _snack('Lütfen önce giriş yapın veya kayıt olun.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  YARDIMCI
  // ══════════════════════════════════════════════════════════════════════════

  String _priceLabel() {
    if (_post.paylasimTuru == 'Bağış') return 'Ücretsiz';
    if (_post.paylasimTuru == 'Kayıp Eşya') return 'Kayıp';
    final f = _post.fiyat;
    if (f == null || f.trim().isEmpty || f == '-') return '-';
    return f.startsWith('₺') ? f : '${f.trim()} ₺';
  }

  bool get _showFiyat =>
      _post.paylasimTuru != 'Bağış' &&
      _post.paylasimTuru != 'Kayıp Eşya';

  bool get _needsExpand => (_post.aciklama?.length ?? 0) > 81;

  bool get _showVideoBtn =>
      _hasVideo || (_post.videoResim?.isNotEmpty ?? false);

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, top: 1, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildMediaSection(),
          _buildFavoriteRow(),
          _buildContentSection(),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _goProfile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _PostProfileAvatar(imageUrl: _profileImageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _username.isNotEmpty ? _username : 'Kullanıcı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _post.tarihStr ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isOwn)
                      GestureDetector(
                        onTap: () => _goChat(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF15C0A4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openOptions,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Medya Alanı ──────────────────────────────────────────────────────────
  Widget _buildMediaSection() {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showingVideo
              ? VideoPager(
                  key: _videoPagerKey,
                  videoUrls: _videoUrls,
                  onFullscreen: _goFullscreenVideo,
                  onClose: () => setState(() => _showingVideo = false),
                )
              : ImageSlider(
                  key: ValueKey(_post.documentId ?? ''),
                  imageUrls: _post.gosterilecekResimler ?? [],
                  videoResimUrls: _post.videoResim ?? [],
                  height: 240,
                  onImageTap: _goImageDetail,
                  onVideoThumbnailTap: _toggleVideo,
                ),
        ),
        if (_showVideoBtn)
          Positioned(
            bottom: 10,
            left: 10,
            child: GestureDetector(
              onTap: _isLoadingVideo ? null : _toggleVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingVideo)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(
                        _showingVideo
                            ? Icons.image_outlined
                            : Icons.play_circle_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _isLoadingVideo
                          ? 'Yükleniyor...'
                          : _showingVideo
                              ? 'Fotoğrafları Gör'
                              : '▶ Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Favori Satırı ────────────────────────────────────────────────────────
  Widget _buildFavoriteRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleFavorite,
            child: Row(
              children: [
                ScaleTransition(
                  scale: _favScaleAnim,
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? AppColors.error : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isFavorite ? 'Favorilere Eklendi' : 'Favorilere Ekle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isFavorite ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_showingVideo)
            GestureDetector(
              onTap: () {
                if (_videoUrls.isNotEmpty) {
                  _goFullscreenVideo(_videoUrls[0], Duration.zero);
                }
              },
              child: const Icon(
                Icons.fullscreen_rounded,
                size: 26,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // ── İçerik ───────────────────────────────────────────────────────────────
  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showFiyat) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _priceLabel(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (!_isOwn)
                  GestureDetector(
                    onTap: _openOffer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x301976D2),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Teklif Ver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Açıklama
          RichText(
            maxLines: _isExpanded ? 11 : 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              if (_userFirstName.isNotEmpty)
                TextSpan(
                  text: '$_userFirstName ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              TextSpan(
                text: _post.aciklama ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ]),
          ),
          // Devamını Gör
          if (_needsExpand)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isExpanded ? 'Devamını Gizle...' : 'Devamını Gör...',
                  style: const TextStyle(
                    color: Color(0xFF1976D2),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          // Konum
          if (_post.konum != null && _post.konum!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _post.konum!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Profil Avatarı ────────────────────────────────────────────────────────────
class _PostProfileAvatar extends StatelessWidget {
  const _PostProfileAvatar({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 21,
          backgroundImage: imageProvider,
          backgroundColor: AppColors.accentSoft,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.accentSoft,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => const CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.accentSoft,
          child: Icon(Icons.person_rounded, size: 22, color: AppColors.accent),
        ),
      );
    }
    return const CircleAvatar(
      radius: 21,
      backgroundColor: AppColors.accentSoft,
      child: Icon(Icons.person_rounded, size: 22, color: AppColors.accent),
    );
  }
}