// ignore_for_file: avoid_print
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:flutter/services.dart';

const _kNavy  = Color(0xFF1E1B4B);
const _kSlate = Color(0xFF64748B);
const _kIce   = Color(0xFFF4F6FA);
const _kCard  = Colors.white;

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    this.postId,
    this.post,
    this.currentUserId,
  }) : assert(postId != null || post != null, 'postId veya post gerekli');

  final String? postId;
  final Post?   post;
  final String? currentUserId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with TickerProviderStateMixin {

  final _cache = PostCacheService.instance;

  // ── Post verisi ───────────────────────────────────────────────────────────
  Post?   _post;
  bool    _isLoading = true;
  String? _loadError;

  // ── Kullanıcı bilgisi ─────────────────────────────────────────────────────
  String? _profileImageUrl;
  String  _username      = '';
  String  _userFirstName = '';

  // ── Favori ────────────────────────────────────────────────────────────────
  bool _isFavorite = false;
  late final AnimationController _favAnim;
  late final Animation<double>   _favScale;

  // ── Medya ─────────────────────────────────────────────────────────────────
  bool         _showingVideo = false;
  bool         _videoLoading = false;
  List<String> _videoUrls   = [];
  final GlobalKey<VideoPagerState> _videoPagerKey = GlobalKey();

  // ── Açıklama toggle ───────────────────────────────────────────────────────
  bool _expanded = false;

  // ── Giriş animasyonu ─────────────────────────────────────────────────────
  late final AnimationController _entryAnim;
  late final Animation<double>   _entryFade;
  late final Animation<Offset>   _entrySlide;

  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _scroll = ScrollController();

  // ── Getters ───────────────────────────────────────────────────────────────
  String? get _uid  => widget.currentUserId;

  /// PostCard ile aynı mantık:
  /// _uid null ise ziyaretçi → kendi ilanı sayılmaz.
  /// _uid doluysa ve post.userId ile eşleşiyorsa kendi ilanı.
  bool get _isOwn => _uid != null && _uid == _post?.userId;

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _favAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _favScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.4, end: 1.35)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 20),
    ]).animate(_favAnim);

    _entryAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entryFade  = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryAnim, curve: Curves.easeOutCubic));

    _scroll.addListener(() => setState(() {}));

    if (widget.post != null) {
      _post      = widget.post;
      _isLoading = false;
      _afterLoad();
    } else {
      _loadFromFirestore();
    }
  }

  @override
  void dispose() {
    _favAnim.dispose();
    _entryAnim.dispose();
    _scroll.dispose();
    if (_post?.documentId != null) {
      VideoPlayerManager.instance.clearActive(_post!.documentId!);
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERİ YÜKLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadFromFirestore() async {
    print('🔍 LOG 17 [DetailScreen]: Açıldı. ID: "${widget.postId}"');
    try {
      if (widget.postId == null || widget.postId!.trim().isEmpty) {
        if (mounted) setState(() { _isLoading = false; _loadError = 'Geçersiz İlan ID.'; });
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId!.trim())
          .get()
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw Exception('Firebase yanıt vermedi.'));

      if (!snap.exists) {
        if (mounted) setState(() { _isLoading = false; _loadError = 'İlan bulunamadı.'; });
        return;
      }

      final post = Post.fromMap(Map<String, dynamic>.from(snap.data()!), snap.id);
      if (post == null) {
        if (mounted) setState(() { _isLoading = false; _loadError = 'İlan verisi okunamadı.'; });
        return;
      }

      if (mounted) {
        setState(() { _post = post; _isLoading = false; });
        _afterLoad();
      }
    } catch (e) {
      print('🚨 LOG 24 [DetailScreen]: $e');
      if (mounted) setState(() { _isLoading = false; _loadError = 'Bağlantı hatası oluştu.'; });
    }
  }

  void _afterLoad() {
    _loadProfileImage();
    _loadUsername();
    _loadFavoriteStatus();
    _entryAnim.forward();
  }

  Future<void> _loadProfileImage() async {
    if (_post?.userId == null) return;
    final url = await _cache.getProfilUrl(_post!.userId!);
    if (mounted) setState(() => _profileImageUrl = url);
  }

  Future<void> _loadUsername() async {
    if (_post?.userId == null) return;
    final info = await _cache.getKullaniciAdi(_post!.userId!);
    if (mounted && info != null) {
      setState(() { _username = info.tamAd; _userFirstName = info.adKucuk; });
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (_uid == null || _post?.documentId == null) return;
    final v = await _cache.isFavori(
        currentUserId: _uid!, postId: _post!.documentId!);
    if (mounted) setState(() => _isFavorite = v);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AKSIYONLAR — PostCard ile birebir aynı mantık
  // ══════════════════════════════════════════════════════════════════════════

  /// Ziyaretçi (uid==null) uyarısı — PostCard._guestUyari() karşılığı
  void _guestUyari() => _snack('Lütfen önce giriş yapın veya kayıt olun.');

  Future<void> _toggleFavorite() async {
    // PostCard._toggleFavorite() ile birebir aynı
    if (_uid == null) { _guestUyari(); return; }
    if (_post?.documentId == null) return;
    _favAnim.forward(from: 0);
    try {
      final yeni = await _cache.toggleFavori(
          currentUserId: _uid!, postId: _post!.documentId!);
      if (mounted) {
        setState(() => _isFavorite = yeni);
        _snack(yeni ? 'Favorilere eklendi! ❤️' : 'Favorilerden kaldırıldı. ❤️‍🩹');
      }
    } catch (_) {
      if (mounted) _snack('İşlem sırasında hata oluştu.');
    }
  }

  Future<void> _toggleVideo() async {
    if (_showingVideo) {
      if (_post?.documentId != null) {
        VideoPlayerManager.instance.clearActive(_post!.documentId!);
      }
      if (mounted) setState(() => _showingVideo = false);
      return;
    }
    setState(() => _videoLoading = true);
    final urls = await _cache.getVideoUrls(_post?.documentId ?? '');
    if (!mounted) return;
    if (urls.isEmpty) {
      setState(() => _videoLoading = false);
      _snack('Bu ilana ait video bulunmamaktadır.');
      return;
    }
    setState(() { _videoUrls = urls; _videoLoading = false; _showingVideo = true; });
    if (_post?.documentId != null) {
      VideoPlayerManager.instance.setActive(
        postId: _post!.documentId!,
        pauseCallback: () {
          if (mounted && _showingVideo) {
            _videoPagerKey.currentState?.pause();
            setState(() => _showingVideo = false);
          }
        },
      );
    }
  }

  /// PostCard._goChat() karşılığı:
  /// Ziyaretçi → uyarı, kendi ilanı → hiçbir şey yapma, başkasının → chat aç
  void _openChat({String? teklifMesaj}) {
    if (_uid == null)  { _guestUyari(); return; }
    if (_isOwn)        return; // kendi ilanına mesaj atmaz
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        hedefUserId: _post?.userId ?? '',
        kategori: _post?.kategori,
        teklifMesaj: teklifMesaj,
      ),
    ));
  }

  /// PostCard._goProfile() karşılığı
  void _openProfile() {
    if (_uid == null) { _guestUyari(); return; }
    if (_post?.userId == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProfileScreen(
        userId: _post!.userId!,
        nereden: 'postProfili',
        kategori: _post?.kategori,
      ),
    ));
  }

  void _openImageDetail(int index) {
    if (_post?.gosterilecekResimler?.isEmpty ?? true) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ImageDetailScreen(
        imageUrls: _post!.gosterilecekResimler!,
        initialIndex: index,
      ),
    ));
  }

  /// PostCard._openOffer() karşılığı:
  /// Ziyaretçi → uyarı, kendi ilanı → hiçbir şey, başkasının → teklif sheet
  void _openOffer() {
    if (_uid == null) { _guestUyari(); return; }
    if (_isOwn)       return;
    OfferBottomSheet.show(
      context: context,
      fiyatStr: _post?.fiyat,
      kategori: _post?.kategori ?? '',
      onOfferSelected: (msg) => _openChat(teklifMesaj: msg),
    );
  }

  void _openOptions() {
    PostOptionsBottomSheet.show(
      context: context,
      postId:   _post?.documentId ?? '',
      isOwner:  _isOwn,
      ownerId:  _post?.userId ?? '',
      kategori: _post?.kategori,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kIce,
        body: _isLoading
            ? _buildLoadingState()
            : _loadError != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: _kIce,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: _kIce,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(_loadError!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final post      = _post!;
    final showFiyat = post.paylasimTuru != 'Bağış' &&
                      post.paylasimTuru != 'Kayıp Eşya';

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor: _kNavy,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeroMedia(post),
                collapseMode: CollapseMode.parallax,
              ),
              leading: _buildBackButton(),
              actions: [_buildOptionsButton()],
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: Column(
                    children: [
                      _buildPriceStrip(post, showFiyat),
                      _buildOwnerCard(post),
                      _buildDescriptionCard(post),
                      if (post.konum != null && post.konum!.isNotEmpty)
                        _buildLocationCard(post),
                      if (post.etiketler != null && post.etiketler!.isNotEmpty)
                        _buildTagsCard(post),
                      _buildMetaCard(post),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildStickyBar(post, showFiyat),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HERO MEDYA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroMedia(Post post) {
    final hasVideo = post.videoResim?.isNotEmpty ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        _showingVideo
            ? VideoPager(
                key: _videoPagerKey,
                videoUrls: _videoUrls,
                onFullscreen: (url, pos) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FullscreenVideoScreen(
                            videoUrl: url, playbackPosition: pos))),
                onClose: () => setState(() => _showingVideo = false),
              )
            : ImageSlider(
                key: ValueKey(post.documentId ?? ''),
                imageUrls: post.gosterilecekResimler ?? [],
                videoResimUrls: post.videoResim ?? [],
                height: 340,
                onImageTap: _openImageDetail,
                onVideoThumbnailTap: _toggleVideo,
              ),

        // Üst gradient (geri & options butonları için)
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xDD1E1B4B), Colors.transparent],
              ),
            ),
          ),
        ),

        // İlan türü etiketi (sol alt)
        Positioned(
          bottom: 16, left: 16,
          child: _TypePill(paylasimTuru: post.paylasimTuru ?? ''),
        ),

        // Video geçiş butonu (sağ alt) — sadece video varsa göster
        if (hasVideo || _showingVideo)
          Positioned(
            bottom: 16, right: 16,
            child: GestureDetector(
              onTap: _videoLoading ? null : _toggleVideo,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    color: Colors.black38,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_videoLoading)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        else
                          Icon(
                            _showingVideo
                                ? Icons.image_outlined
                                : Icons.play_circle_outline_rounded,
                            color: Colors.white, size: 16,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _videoLoading
                              ? 'Yükleniyor...'
                              : _showingVideo
                                  ? 'Fotoğraflar'
                                  : '▶ Video',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 38, height: 38,
              color: Colors.black26,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: _openOptions,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 38, height: 38,
              color: Colors.black26,
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  İÇERİK KARTLARI
  // ══════════════════════════════════════════════════════════════════════════

  // ── Fiyat bandı ──────────────────────────────────────────────────────────
  Widget _buildPriceStrip(Post post, bool showFiyat) {
    final price = _priceLabel(post);
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.kategori != null)
            Row(
              children: [
                Text(post.kategori!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
                if (post.altKategori != null) ...[
                  const Icon(Icons.chevron_right,
                      size: 14, color: AppColors.textMuted),
                  Text(post.altKategori!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showFiyat) ...[
                Text(price,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                        letterSpacing: -1)),
                const Spacer(),
                // Teklif Ver: sadece kendi ilanı DEĞİLSE göster (PostCard mantığı)
                if (!_isOwn)
                  GestureDetector(
                    onTap: _openOffer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF1D4ED8)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x401D4ED8),
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: const Text('Teklif Ver',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                  ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: post.paylasimTuru == 'Bağış'
                        ? AppColors.successSoft
                        : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(price,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: post.paylasimTuru == 'Bağış'
                              ? AppColors.success
                              : AppColors.warning)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Kullanıcı kartı ───────────────────────────────────────────────────────
  Widget _buildOwnerCard(Post post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar → profile git (PostCard._goProfile mantığı)
            GestureDetector(
              onTap: _openProfile,
              child: _buildAvatar(),
            ),
            const SizedBox(width: 14),
            // İsim + tarih → profile git
            Expanded(
              child: GestureDetector(
                onTap: _openProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _username.isNotEmpty ? _username : 'Kullanıcı',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kNavy),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(post.tarihStr ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: _kSlate)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Chat butonu: PostCard ile aynı — sadece başkasının ilanıysa göster
            if (!_isOwn)
              GestureDetector(
                onTap: () => _openChat(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF15C0A4), Color(0xFF0EA5E9)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x4015C0A4),
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null &&
        _profileImageUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: AppColors.accentSoft,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.accentSoft,
      child: Text(
        _username.isNotEmpty ? _username[0].toUpperCase() : '?',
        style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            fontSize: 18),
      ),
    );
  }

  // ── Açıklama kartı ────────────────────────────────────────────────────────
  Widget _buildDescriptionCard(Post post) {
    final aciklama    = post.aciklama ?? '';
    final needsExpand = aciklama.length > 120;

    return _sectionCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            text: TextSpan(children: [
              if (_userFirstName.isNotEmpty)
                TextSpan(
                  text: '$_userFirstName ',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kNavy),
                ),
              TextSpan(
                text: aciklama,
                style: const TextStyle(
                    fontSize: 14, color: _kSlate, height: 1.6),
              ),
            ]),
          ),
          if (needsExpand) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Daha az göster' : 'Devamını gör',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.accent),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Konum kartı ───────────────────────────────────────────────────────────
  Widget _buildLocationCard(Post post) {
    return _sectionCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Konum',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kSlate,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(post.konum!,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Etiketler kartı — yeniden tasarlandı ─────────────────────────────────
  Widget _buildTagsCard(Post post) {
    final tags = post.etiketler!;
    return _sectionCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı: ikon + yazı
          Row(
            children: const [
              Icon(Icons.local_offer_rounded,
                  size: 14, color: AppColors.accent),
              SizedBox(width: 6),
              Text('Etiketler',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),
          // Etiket pilleri — yatayda kaydırılabilir tek satır
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: tags.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                      right: entry.key < tags.length - 1 ? 8 : 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.15),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent.withOpacity(0.6))),
                        Text(entry.value,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Meta kart ─────────────────────────────────────────────────────────────
  Widget _buildMetaCard(Post post) {
    return _sectionCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _metaRow(Icons.category_outlined, 'Kategori', post.kategori ?? '-'),
          if (post.altKategori != null) ...[
            const SizedBox(height: 10),
            _metaRow(Icons.subdirectory_arrow_right_rounded,
                'Alt Kategori', post.altKategori!),
          ],
          if (post.universite != null) ...[
            const SizedBox(height: 10),
            _metaRow(
                Icons.school_outlined, 'Üniversite', post.universite!),
          ],
          if (post.esyaDurumu != null && post.esyaDurumu!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _metaRow(Icons.star_outline_rounded, 'Eşya Durumu',
                post.esyaDurumu!),
          ],
          if (post.hedefKitle != null) ...[
            const SizedBox(height: 10),
            _metaRow(Icons.people_alt_outlined, 'Hedef Kitle',
                post.hedefKitle!),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kSlate),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(fontSize: 13, color: _kSlate)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kNavy)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STICKY ALT BAR
  //  PostCard mantığı:
  //  • Kendi ilanı → "Bu sizin ilanınız" etiketi (mesaj butonu yok)
  //  • Başkasının  → "Satıcıyla İletişime Geç" butonu
  //  • Ziyaretçi  → butona tıklayınca guestUyari
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStickyBar(Post post, bool showFiyat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          // Favori butonu
          GestureDetector(
            onTap: _toggleFavorite,
            child: ScaleTransition(
              scale: _favScale,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _isFavorite
                      ? AppColors.errorSoft
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isFavorite
                        ? AppColors.error.withOpacity(0.3)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? AppColors.error : _kSlate,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sağ taraf: kendi ilanı mı değil mi?
          Expanded(
            child: _isOwn
                ? _buildOwnerTag()   // "Bu sizin ilanınız"
                : _buildContactBtn(), // "Satıcıyla İletişime Geç"
          ),
        ],
      ),
    );
  }

  /// Kendi ilanı — PostCard'da chat butonu hiç render edilmez,
  /// burada da devre dışı bir etiket gösteriyoruz.
  Widget _buildOwnerTag() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined,
              color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('Bu sizin ilanınız',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Başkasının ilanı ya da ziyaretçi → butona basınca _openChat
  Widget _buildContactBtn() {
    return GestureDetector(
      onTap: () => _openChat(),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kNavy, Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _kNavy.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Satıcıyla İletişime Geç',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  YARDIMCI
  // ══════════════════════════════════════════════════════════════════════════

  String _priceLabel(Post post) {
    if (post.paylasimTuru == 'Bağış') return 'Ücretsiz';
    if (post.paylasimTuru == 'Kayıp Eşya') return 'Kayıp İlanı';
    final f = post.fiyat;
    if (f == null || f.trim().isEmpty || f == '-') return 'Fiyat belirtilmedi';
    return '${f.trim()} ₺';
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      );

  Widget _sectionCard(
      {required Widget child, EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      decoration: _cardDecoration(),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Tip Pill
// ═════════════════════════════════════════════════════════════════════════════

class _TypePill extends StatelessWidget {
  const _TypePill({required this.paylasimTuru});
  final String paylasimTuru;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text, String label, IconData icon) =
        switch (paylasimTuru) {
      'İkinci El Eşya' => (
          AppColors.tagBlueBg,
          AppColors.tagBlueText,
          'İkinci El',
          Icons.sell_rounded
        ),
      'Kayıp Eşya' => (
          AppColors.warningSoft,
          AppColors.warning,
          'Kayıp Eşya',
          Icons.search_rounded
        ),
      'Bağış' => (
          AppColors.successSoft,
          AppColors.success,
          'Bağış',
          Icons.volunteer_activism_rounded
        ),
      _ => (
          AppColors.surfaceSecondary,
          AppColors.textMuted,
          paylasimTuru,
          Icons.info_outline
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: bg.withOpacity(0.9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: text)),
            ],
          ),
        ),
      ),
    );
  }
}