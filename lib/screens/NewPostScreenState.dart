import 'dart:io';
import 'dart:ui';
import 'package:erzurum_kampus/screens/FilterOptions.dart';
import 'package:erzurum_kampus/screens/NotificationService.dart';
import 'package:erzurum_kampus/screens/OcrService.dart';
import 'package:erzurum_kampus/screens/PostUploadService.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sabit Veriler
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryItem {
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryItem(this.label, this.icon, this.color);
}

const List<_CategoryItem> _allCategoryMeta = [
  _CategoryItem('Elektronik',        Icons.devices_rounded,           Color(0xFF6366F1)),
  _CategoryItem('Kitap / Kırtasiye', Icons.menu_book_rounded,         Color(0xFFF59E0B)),
  _CategoryItem('Giyim / Aksesuar',  Icons.checkroom_rounded,         Color(0xFFEC4899)),
  _CategoryItem('Kimlik / Kart',     Icons.credit_card_rounded,       Color(0xFF14B8A6)),
  _CategoryItem('Spor / Outdoor',    Icons.sports_basketball_rounded, Color(0xFF22C55E)),
  _CategoryItem('Ev / Yaşam',        Icons.home_rounded,              Color(0xFF8B5CF6)),
  _CategoryItem('Araç / Gereç',      Icons.build_rounded,             Color(0xFF64748B)),
  _CategoryItem('Anahtar / Kilit',   Icons.key_rounded,               Color(0xFFEF4444)),
  _CategoryItem('Diğer',             Icons.more_horiz_rounded,        Color(0xFF94A3B8)),
];

_CategoryItem _metaFor(String label) =>
    _allCategoryMeta.firstWhere(
      (c) => c.label == label,
      orElse: () => const _CategoryItem('Diğer', Icons.more_horiz_rounded, Color(0xFF94A3B8)),
    );

const List<String> _universities = [
  'Erzurum Teknik Üniversitesi',
  'Atatürk Üniversitesi',
  'Tümü',
];

class _PostTypeData {
  final PostTypeEnum type;
  final String label;
  final String sublabel;
  final IconData icon;
  final List<Color> gradient;
  const _PostTypeData(this.type, this.label, this.sublabel, this.icon, this.gradient);
}

const List<_PostTypeData> _postTypes = [
  _PostTypeData(PostTypeEnum.ikinciEl,  'İkinci El',  'Satılık ürün',     Icons.sell_rounded,               [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
  _PostTypeData(PostTypeEnum.kayipEsya, 'Kayıp Eşya', 'Bulunan / Aranan', Icons.search_rounded,             [Color(0xFFF59E0B), Color(0xFFEF4444)]),
  _PostTypeData(PostTypeEnum.bagis,     'Bağış',       'Ücretsiz ver',     Icons.volunteer_activism_rounded, [Color(0xFF10B981), Color(0xFF0EA5E9)]),
];

// ═════════════════════════════════════════════════════════════════════════════
//  NewPostScreen
// ═════════════════════════════════════════════════════════════════════════════

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, this.editPostId});
  final String? editPostId;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen>
    with TickerProviderStateMixin {

  // ── Servisler ─────────────────────────────────────────────────────────────
  final _uploader = PostUploadService.instance;
  final _ocr      = OcrService.instance;
  final _picker   = ImagePicker();

  // ── Adım ──────────────────────────────────────────────────────────────────
  int _step = 0;
  late final AnimationController _stepAnim;
  late final Animation<double>   _stepFade;

  // ── Form Kontrolcüleri ────────────────────────────────────────────────────
  final _konumCtrl    = TextEditingController();
  final _fiyatCtrl    = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  final _etiketCtrl   = TextEditingController();
  final _sahipCtrl    = TextEditingController();

  // ── Medya ─────────────────────────────────────────────────────────────────
  final List<File>   _imageFiles   = [];
  final List<File>   _videoFiles   = [];
  final List<File>   _thumbFiles   = [];
  final List<String> _mediaTypes   = [];
  final List<String> _previewPaths = [];
  // FIX: PageController'ı doğrudan burada tutuyoruz, _mediaPage ile senkron
  final PageController _mediaPager = PageController();
  int _mediaPage = 0;

  // ── Seçimler ──────────────────────────────────────────────────────────────
  PostTypeEnum _postType       = PostTypeEnum.ikinciEl;
  String?      _category;
  String?      _subCategory;
  String       _university     = _universities[0];
  String       _condition      = '';
  String       _audience       = 'Herkes';
  double       _uploadProgress = 0;
  bool         _isSubmitting   = false;
  bool         _ocrLoading     = false;
  String?      _ocrResult;

  bool get _isEdit => widget.editPostId != null;

  Map<String, List<String>> get _categoryMap => AppCategories.forEnum(_postType);
  List<String> get _categoryKeys             => _categoryMap.keys.toList();
  List<String> get _subCategoryList          => _category == null ? [] : (_categoryMap[_category] ?? []);

  String get _postTypeString => switch (_postType) {
    PostTypeEnum.ikinciEl  => PostType.ikinciEl,
    PostTypeEnum.kayipEsya => PostType.kayipEsya,
    PostTypeEnum.bagis     => PostType.bagis,
  };

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _stepFade = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut);
    _stepAnim.value = 1.0;
    if (_isEdit) _loadEdit();
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    _mediaPager.dispose();
    _konumCtrl.dispose();
    _fiyatCtrl.dispose();
    _aciklamaCtrl.dispose();
    _etiketCtrl.dispose();
    _sahipCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVİGASYON
  // ══════════════════════════════════════════════════════════════════════════

  void _goNext() {
    if (_step == 0 && !_validateStep0()) return;
    if (_step == 1 && _category == null) {
      _snack('Lütfen bir kategori seçin.');
      return;
    }
    _animateStep(_step + 1);
  }

  void _goBack() {
    if (_step > 0) _animateStep(_step - 1);
    else Navigator.pop(context);
  }

  void _animateStep(int next) {
    _stepAnim.reverse().then((_) {
      if (!mounted) return;
      setState(() => _step = next);
      _stepAnim.forward();
    });
  }

  bool _validateStep0() {
    if (_mediaTypes.where((t) => t == 'image').isEmpty) {
      _snack('Lütfen en az bir fotoğraf ekleyin.');
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MEDYA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickMedia(String type) async {
    Navigator.pop(context);
    if (type == 'photo') {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      for (final x in files) {
        _imageFiles.add(File(x.path));
        _mediaTypes.add('image');
        _previewPaths.add(x.path);
        _ocr.resetOcrFlag();
        if (_postType == PostTypeEnum.kayipEsya) _runOcr(File(x.path));
      }
    } else {
      final x = await _picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      _videoFiles.add(File(x.path));
      final dir  = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: x.path,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );
      if (path != null) {
        _thumbFiles.add(File(path));
        _mediaTypes.add('video');
        _previewPaths.add(path);
      }
    }
    if (mounted) setState(() {});
  }

  void _deleteMedia(int idx) {
    if (_mediaTypes[idx] == 'video') {
      final vi = _mediaTypes.take(idx).where((t) => t == 'video').length;
      if (vi < _videoFiles.length) _videoFiles.removeAt(vi);
      if (vi < _thumbFiles.length) _thumbFiles.removeAt(vi);
    } else {
      final ii = _mediaTypes.take(idx).where((t) => t == 'image').length;
      if (ii < _imageFiles.length) _imageFiles.removeAt(ii);
    }
    _mediaTypes.removeAt(idx);
    _previewPaths.removeAt(idx);
    setState(() {
      if (_mediaPage >= _previewPaths.length && _mediaPage > 0) _mediaPage--;
    });
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(onSelect: _pickMedia),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  OCR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runOcr(File file) async {
    if (!mounted) return;
    setState(() => _ocrLoading = true);
    final name = await _ocr.detectOwnerName(file);
    if (!mounted) return;
    setState(() {
      _ocrLoading = false;
      if (name != null && name.isNotEmpty) {
        _ocrResult = name;
        if (_sahipCtrl.text.trim().isEmpty) _sahipCtrl.text = name;
      } else {
        _ocrResult = null;
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUBMIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_konumCtrl.text.trim().isEmpty)    { _snack('Konum gerekli'); return; }
    if (_aciklamaCtrl.text.trim().isEmpty) { _snack('Açıklama gerekli'); return; }
    if (_postType == PostTypeEnum.ikinciEl && _fiyatCtrl.text.trim().isEmpty) {
      _snack('Fiyat gerekli');
      return;
    }

    setState(() { _isSubmitting = true; _uploadProgress = 0; });

    final tags = _etiketCtrl.text
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      String gecerliPostId;

      if (_isEdit) {
        await _uploader.updatePost(
          postId:         widget.editPostId!,
          konum:          _konumCtrl.text.trim(),
          fiyat:          _fiyatCtrl.text.trim().isEmpty ? '-' : _fiyatCtrl.text.trim(),
          aciklama:       _aciklamaCtrl.text.trim(),
          kategori:       _category ?? '',
          altKategori:    _subCategory ?? '',
          imageFiles:     _imageFiles,
          videoFiles:     _videoFiles,
          thumbnailFiles: _thumbFiles,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        gecerliPostId = widget.editPostId!;
      } else {
        gecerliPostId = await _uploader.publishPost(
          paylasimTuru:    _postTypeString,
          konum:           _konumCtrl.text.trim(),
          fiyat:           _fiyatCtrl.text.trim().isEmpty ? '-' : _fiyatCtrl.text.trim(),
          aciklama:        _aciklamaCtrl.text.trim(),
          kategori:        _category ?? '',
          altKategori:     _subCategory ?? '',
          universite:      _university,
          esyaDurumu:      _condition,
          hedefKitle:      _audience,
          etiketler:       tags,
          kayipEsyaSahibi: _sahipCtrl.text.trim(),
          imageFiles:      _imageFiles,
          videoFiles:      _videoFiles,
          thumbnailFiles:  _thumbFiles,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      if (!_isEdit &&
          _postType == PostTypeEnum.kayipEsya &&
          _sahipCtrl.text.trim().isNotEmpty &&
          gecerliPostId.isNotEmpty) {
        try {
          final rc  = FirebaseRemoteConfig.instance;
          await rc.fetchAndActivate();
          final key = rc.getString('onesignal_rest_api_key');
          if (key.isNotEmpty) {
            NotificationService.instance.sendKayipEsyaNotification(
              postId:              gecerliPostId,
              kayipEsyaSahibi:     _sahipCtrl.text.trim(),
              oneSignalRestApiKey: key,
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        _snack('İlan başarıyla yayınlandı! 🎉');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _snack('Hata oluştu: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DÜZENLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadEdit() async {
    final data = await _uploader.fetchPostForEdit(widget.editPostId!);
    if (data == null || !mounted) return;
    setState(() {
      _konumCtrl.text    = data['konum']    ?? '';
      _fiyatCtrl.text    = data['fiyat']    ?? '';
      _aciklamaCtrl.text = data['aciklama'] ?? '';
      _category          = data['kategori'];
      _subCategory       = data['altKategori'];
      final tags = data['etiketler'] as List?;
      if (tags != null) _etiketCtrl.text = tags.join(', ');
    });
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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: Column(
          children: [
            RepaintBoundary(child: _buildHeader()),
            if (_isSubmitting) _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _stepFade,
                child: _buildCurrentStep(),
              ),
            ),
            RepaintBoundary(child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: _goBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? 'İlanı Düzenle' : 'Yeni İlan',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      const ['Medya & Tür Seç', 'Kategori Seç', 'Detayları Gir'][_step == 2 ? 2 : _step],
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(3, (i) {
                  final active = i == _step;
                  final done   = i < _step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 6),
                    width:  active ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF6EE7B7)
                          : active ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: done ? const Icon(Icons.check, size: 7, color: Color(0xFF064E3B)) : null,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _uploadProgress),
      duration: const Duration(milliseconds: 250),
      builder: (_, v, __) => LinearProgressIndicator(
        value: v,
        backgroundColor: Colors.transparent,
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        minHeight: 2,
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => _Step0(state: this),
      1 => _Step1(state: this),
      _ => _Step2(state: this),
    };
  }

  // ── Alt Bar ───────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _step == 2;
    return Container(
      color: const Color(0xFFF4F6FA),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          if (_step > 0) ...[
            GestureDetector(
              onTap: _goBack,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _isSubmitting ? null : (isLast ? _submit : _goNext),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  gradient: _isSubmitting ? null
                      : const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  color: _isSubmitting ? const Color(0xFFE2E8F0) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isSubmitting ? null : [
                    BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    else
                      Icon(isLast ? Icons.send_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isSubmitting ? 'Yayınlanıyor...' : isLast ? 'İlanı Yayınla' : 'Devam Et',
                      style: TextStyle(
                        color: _isSubmitting ? const Color(0xFF94A3B8) : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADIM 0
// ═════════════════════════════════════════════════════════════════════════════

class _Step0 extends StatelessWidget {
  const _Step0({required this.state});
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaStage(state: state),
          const SizedBox(height: 24),
          const Row(children: [
            Text('İlan Türü', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
            SizedBox(width: 8),
            Text('Birini seç', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 14),
          ..._postTypes.map((pt) => _TypeCard(pt: pt, state: state)),
          if (state._postType == PostTypeEnum.kayipEsya) ...[
            const SizedBox(height: 20),
            _OwnerSection(state: state),
          ],
          if (state._postType == PostTypeEnum.ikinciEl) ...[
            const SizedBox(height: 20),
            _ConditionSection(state: state),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─ Medya Sahnesi ─────────────────────────────────────────────────────────────
class _MediaStage extends StatefulWidget {
  const _MediaStage({required this.state});
  final _NewPostScreenState state;

  @override
  State<_MediaStage> createState() => _MediaStageState();
}

// FIX: _MediaStage artık StatefulWidget — pageChanged kendi state'ini yönetir,
// üst widget gereksiz yere rebuild olmaz.
class _MediaStageState extends State<_MediaStage> {
  int _localPage = 0;

  @override
  void initState() {
    super.initState();
    widget.state._mediaPager.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.state._mediaPager.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    final page = widget.state._mediaPager.page?.round() ?? 0;
    if (page != _localPage) {
      setState(() => _localPage = page);
      widget.state._mediaPage = page; // üst state'i de senkron tut (setState gerektirmez)
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return RepaintBoundary(
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x261E1B4B), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              s._previewPaths.isEmpty
                  ? _EmptyStage(onTap: s._showMediaPicker)
                  : PageView.builder(
                      controller: s._mediaPager,
                      itemCount: s._previewPaths.length,
                      itemBuilder: (_, i) => Stack(
                        fit: StackFit.expand,
                        children: [
                          // FIX: cacheWidth ile decode maliyeti azaltıldı
                          Image.file(
                            File(s._previewPaths[i]),
                            fit: BoxFit.cover,
                            cacheWidth: 900,
                            gaplessPlayback: true, // PERF: görüntü geçişinde titreme önlenir
                          ),
                          if (s._mediaTypes[i] == 'video')
                            const ColoredBox(
                              color: Colors.black38,
                              child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 60)),
                            ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xAA000000)],
                                stops: [0.5, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10, right: 10,
                            child: GestureDetector(
                              onTap: () => s._deleteMedia(i),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: const SizedBox(
                                    width: 36, height: 36,
                                    child: ColoredBox(
                                      color: Colors.black38,
                                      child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              if (s._ocrLoading)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: const ColoredBox(
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        SizedBox(height: 14),
                        Text('Görsel analiz ediliyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: [
                      if (s._previewPaths.length > 1)
                        Expanded(
                          child: Row(
                            children: List.generate(s._previewPaths.length, (i) {
                              final active = i == _localPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 5),
                                width: active ? 18 : 6, height: 6,
                                decoration: BoxDecoration(
                                  color: active ? Colors.white : Colors.white54,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        )
                      else
                        const Spacer(),
                      GestureDetector(
                        onTap: s._showMediaPicker,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              color: Colors.white.withOpacity(0.2),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    s._previewPaths.isEmpty ? 'Medya Ekle' : 'Daha Ekle',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('Fotoğraf veya Video Ekle', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Dokunarak galeriden seç', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─ İlan Türü Kartı ────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.pt, required this.state});
  final _PostTypeData pt;
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    final selected = state._postType == pt.type;
    return GestureDetector(
      onTap: () => state.setState(() {
        state._postType    = pt.type;
        state._category    = null;
        state._subCategory = null;
        state._ocrResult   = null;
        if (pt.type == PostTypeEnum.kayipEsya && state._imageFiles.isNotEmpty) {
          state._ocr.resetOcrFlag();
          state._runOcr(state._imageFiles.first);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: pt.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE8ECF4), width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: pt.gradient.first.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : pt.gradient.first.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(pt.icon, size: 22, color: selected ? Colors.white : pt.gradient.first),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pt.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xFF1E1B4B))),
                    Text(pt.sublabel, style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : const Color(0xFF94A3B8))),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : Colors.transparent,
                  border: Border.all(color: selected ? Colors.transparent : const Color(0xFFCBD5E1), width: 2),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: pt.gradient.first) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─ Eşya Durumu ────────────────────────────────────────────────────────────────
class _ConditionSection extends StatelessWidget {
  const _ConditionSection({required this.state});
  final _NewPostScreenState state;

  static const _items = [
    (raw: 'Sıfır',   display: '🌟 Sıfır'),
    (raw: 'İyi',     display: '✅ İyi'),
    (raw: 'Orta',    display: '🔶 Orta'),
    (raw: 'Hasarlı', display: '🔴 Hasarlı'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Eşya Durumu',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: _items.map((item) {
          final sel = state._condition == item.raw;
          return GestureDetector(
            onTap: () => state.setState(() => state._condition = sel ? '' : item.raw),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1E1B4B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: sel ? [const BoxShadow(color: Color(0x401E1B4B), blurRadius: 10, offset: Offset(0, 4))] : [],
              ),
              child: Text(item.display, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─ Eşya Sahibi ────────────────────────────────────────────────────────────────
class _OwnerSection extends StatelessWidget {
  const _OwnerSection({required this.state});
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Eşya Sahibi',
      child: Column(
        children: [
          if (state._ocrResult != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Görselden tespit edildi', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(state._ocrResult!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => state.setState(() => state._ocrResult = null),
                      child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          // FIX: const kaldırıldı — runtime parametreler içeriyor
          _PremiumField(
            ctrl: state._sahipCtrl,
            hint: 'Ad Soyad (opsiyonel)',
            icon: Icons.person_search_outlined,
            capitalize: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          const _OcrHintBox(),
        ],
      ),
    );
  }
}

// PERF: Sabit içerik ayrı const widget'a taşındı — rebuild almaz
class _OcrHintBox extends StatelessWidget {
  const _OcrHintBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFFEFF6FF), borderRadius: BorderRadius.all(Radius.circular(12))),
      child: const Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF1D4ED8)),
          SizedBox(width: 8),
          Expanded(child: Text('Adı doğru girerseniz sahibi anında bildirim alır.', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), height: 1.4))),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADIM 1  —  Kategori
// ═════════════════════════════════════════════════════════════════════════════

class _Step1 extends StatelessWidget {
  const _Step1({required this.state});
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    final keys = state._categoryKeys;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori Seç', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text('İlanın hangi kategoriye ait?', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
            ),
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final label = keys[i];
              final meta  = _metaFor(label);
              return _CategoryCard(label: label, meta: meta, state: state);
            },
          ),
          if (state._category != null && state._subCategoryList.length > 1) ...[
            const SizedBox(height: 24),
            Row(children: [
              const Text('Alt Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
              const SizedBox(width: 8),
              Text('(opsiyonel)', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: state._subCategoryList.map((s) {
                final sel = state._subCategory == s;
                return GestureDetector(
                  onTap: () => state.setState(() => state._subCategory = sel ? null : s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF1E1B4B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.label, required this.meta, required this.state});
  final String label;
  final _CategoryItem meta;
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    final selected = state._category == label;
    return GestureDetector(
      onTap: () => state.setState(() {
        state._category    = selected ? null : label;
        state._subCategory = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? meta.color : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE8ECF4), width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: meta.color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]
              : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.25) : meta.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 20, color: selected ? Colors.white : meta.color),
              ),
              const Spacer(),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF1E293B))),
              if (selected)
                const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADIM 2  —  Detaylar
// ═════════════════════════════════════════════════════════════════════════════

class _Step2 extends StatelessWidget {
  const _Step2({required this.state});
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detaylar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text('Son adım — az kaldı!', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          _SectionCard(title: 'Üniversite', child: _UniversityPicker(state: state)),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Hedef Kitle',
            child: Row(
              children: ['Herkes', 'Sadece Öğrenciler'].map((k) {
                final sel = state._audience == k;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => state.setState(() => state._audience = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: k == 'Herkes' ? const EdgeInsets.only(right: 8) : EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1E1B4B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        k == 'Herkes' ? '🌍 Herkes' : '🎓 Sadece Öğrenciler',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Bilgiler',
            child: Column(
              children: [
                // FIX: const kaldırıldı — runtime TextEditingController geçiliyor
                _PremiumField(
                  ctrl: state._konumCtrl,
                  hint: 'Konum (ör: ETÜ Mühendislik Fakültesi)',
                  icon: Icons.location_on_outlined,
                ),
                if (state._postType == PostTypeEnum.ikinciEl) ...[
                  const SizedBox(height: 12),
                  // FIX: inputFormatters List runtime nesnesi, const olmaz
                  _PremiumField(
                    ctrl: state._fiyatCtrl,
                    hint: 'Fiyat',
                    icon: Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    prefixText: '₺ ',
                    accentColor: const Color(0xFF10B981),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: state._aciklamaCtrl,
                  maxLines: 4,
                  maxLength: 350,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E1B4B)),
                  decoration: const InputDecoration(
                    hintText: 'Açıklama (ne kadar detaylı, o kadar iyi)',
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.notes_rounded, size: 20, color: Color(0xFFCBD5E1)),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF6366F1), width: 2)),
                    counterStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                _PremiumField(
                  ctrl: state._etiketCtrl,
                  hint: 'Etiketler (ör: samsung, laptop)',
                  icon: Icons.local_offer_outlined,
                  accentColor: const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _UniversityPicker extends StatelessWidget {
  const _UniversityPicker({required this.state});
  final _NewPostScreenState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _universities.map((u) {
        final label = u == 'Erzurum Teknik Üniversitesi' ? 'ETÜ'
            : u == 'Atatürk Üniversitesi' ? 'ATA Üni.' : 'Tümü';
        final sel    = state._university == u;
        final isLast = u == _universities.last;
        return Expanded(
          child: GestureDetector(
            onTap: () => state.setState(() => state._university = u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1E1B4B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E8F0)),
                boxShadow: sel ? [const BoxShadow(color: Color(0x401E1B4B), blurRadius: 10, offset: Offset(0, 4))] : [],
              ),
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF64748B))),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  YARDIMCI BİLEŞENLER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.4)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// FIX: const constructor kaldırıldı — TextEditingController ve Color gibi
// runtime nesneler içerdiğinden const örnek oluşturulamaz. Tüm çağrı yerlerindeki
// const anahtar sözcüğü de kaldırıldı.
class _PremiumField extends StatelessWidget {
  _PremiumField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.capitalize = TextCapitalization.none,
    this.prefixText,
    this.accentColor = const Color(0xFF6366F1),
  });

  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization capitalize;
  final String? prefixText;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: capitalize,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E1B4B), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCBD5E1)),
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accentColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MediaPickerSheet
// ═════════════════════════════════════════════════════════════════════════════

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet({required this.onSelect});
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Medya Türü', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
          const SizedBox(height: 6),
          const Text('Ne eklemek istiyorsun?', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildOption(
                icon: Icons.photo_library_outlined,
                label: 'Fotoğraf',
                sublabel: 'Galeriden seç',
                gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                onTap: () => onSelect('photo'),
              ),
              const SizedBox(width: 14),
              _buildOption(
                icon: Icons.video_library_outlined,
                label: 'Video',
                sublabel: 'Galeriden seç',
                gradient: const [Color(0xFF10B981), Color(0xFF0EA5E9)],
                onTap: () => onSelect('video'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String sublabel,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sublabel, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}