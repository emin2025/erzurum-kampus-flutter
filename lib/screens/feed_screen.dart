// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:erzurum_kampus/screens/FilterBottomSheet.dart';
import 'package:erzurum_kampus/screens/FilterOptions.dart';
import 'package:erzurum_kampus/screens/InboxScreen.dart';
import 'package:erzurum_kampus/screens/NewPostScreenState.dart';
import 'package:erzurum_kampus/screens/Post.dart';
import 'package:erzurum_kampus/screens/PostCard.dart';
import 'package:erzurum_kampus/screens/ProfileScreen.dart';
import 'package:erzurum_kampus/screens/login_screen.dart';
import 'package:erzurum_kampus/screens/options_side_menu.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Firebase Importları Aktif Edildi ───────────────────────────────────────
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:permission_handler/permission_handler.dart'; // Gerekirse sonra açılır
// ─────────────────────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // ── Firebase referansları (Aktif Edildi) ─────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  String get _userId => _auth.currentUser?.uid ?? '';

  StreamSubscription<QuerySnapshot>? _postSubscription;
  StreamSubscription<QuerySnapshot>? _mesajSubscription;

  // ── State ─────────────────────────────────────────────────────────────────

  final Map<String, Post> _tumSonuclar = <String, Post>{};
  final List<Post> _postListesi = [];

  String _paylasimTuru = 'İkinci El Eşya';
  int _tabIndex = 0;

  FilterOptions _aktifFiltre = FilterOptions();
  String? _profileImageUrl;
  int _unreadCount = 0;

  bool _isLoading = false;
  int _refreshStartMs = 0;

  final ScrollController _scrollController = ScrollController();

  static const List<_TabDef> _tabs = [
    _TabDef(label: 'İkinci El',  paylasimTuru: 'İkinci El Eşya'),
    _TabDef(label: 'Kayıp Eşya', paylasimTuru: 'Kayıp Eşya'),
    _TabDef(label: 'Bağış',      paylasimTuru: 'Bağış'),
  ];

  @override
  void initState() {
    super.initState();
    _initAuthStateListener();
    _getData();
    _kontrolMesajlar();
    _kendiProfilimiGetir();
  }

  @override
  void dispose() {
    _durdurDinleyiciler();
    _scrollController.dispose();
    super.dispose();
  }

  void _initAuthStateListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        _durdurDinleyiciler();
        // TODO: Login ekranı hazır olunca burayı açarsın
        // Navigator.pushAndRemoveUntil(
        //   context,
        //   MaterialPageRoute(builder: (_) => const LoginScreen()),
        //   (_) => false,
        // );
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GERÇEK VERİ ÇEKİMİ (Mock'lar silindi, burası aktif edildi)
  // ══════════════════════════════════════════════════════════════════════════
  void _getData() {
    _refreshStartMs = DateTime.now().millisecondsSinceEpoch;
    setState(() => _isLoading = true);
    print('[FeedScreen] getData() başladı - Firestore dinleniyor');

    _postSubscription?.cancel();
    
    // Posts koleksiyonunu tarih sırasına göre dinliyoruz
    _postSubscription = _db
        .collection('Posts')
        .where('paylasimTuru', isEqualTo: _paylasimTuru) // Yükü veritabanına bırak
        .orderBy('tarih', descending: true)
        .limit(20)
        .snapshots()
        .listen(
      (snapshot) {
        print('[FeedScreen] Firestoredan ${snapshot.docs.length} post geldi');
        _tumSonuclar.clear();
        
        for (final doc in snapshot.docs) {
          // doc.data() Map döner, bunu Post modeline çeviriyoruz
          final data = doc.data();
          final post = Post.fromMap(data, doc.id);
          
          if (post != null) {
            _tumSonuclar[post.documentId ?? doc.id] = post;
          }
        }
        _gosterAktifTab();
      },
      onError: (Object e) {
        print('[FeedScreen] postListener HATA: $e');
        _stopRefresh();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FİLTRELEME
  // ══════════════════════════════════════════════════════════════════════════
  void _gosterAktifTab() {
    final List<Post> filtrelenmis = _tumSonuclar.values.where((p) {
      if (p.paylasimTuru != _paylasimTuru) return false;
      return _filtreyiGecti(p);
    }).toList()
      ..sort((a, b) {
        final tsA = a.timestamp;
        final tsB = b.timestamp;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });

    print('[FeedScreen] tab=$_paylasimTuru → ${filtrelenmis.length} post ekrana basılacak');

    if (!mounted) return;
    setState(() {
      _postListesi
        ..clear()
        ..addAll(filtrelenmis);
      _isLoading = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _stopRefresh();
  }

  bool _filtreyiGecti(Post post) {
    final f = _aktifFiltre;
    if (f.universite != null) {
      final uni = post.universite;
      if (uni == null) return false;
      if (uni.toLowerCase() != 'tümü' && uni != f.universite) return false;
    }
    if (f.kategori != null) {
      if (post.kategori == null || post.kategori != f.kategori) return false;
    }
    if (f.altKategori != null) {
      if (post.altKategori == null || post.altKategori != f.altKategori) {
        return false;
      }
    }
    if (f.esyaDurumu != null) {
      if (post.esyaDurumu == null || post.esyaDurumu != f.esyaDurumu) {
        return false;
      }
    }
    if (f.hedefKitle != null) {
      if (post.hedefKitle == null || post.hedefKitle != f.hedefKitle) {
        return false;
      }
    }
    if (f.etiket != null && f.etiket!.isNotEmpty) {
      final etiketler = post.etiketler;
      if (etiketler == null ||
          !etiketler.contains(f.etiket!.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  void _filtreAc() {
    FilterBottomSheet.show(
      context: context,
      paylasimTuru: _paylasimTuru,
      currentFilter: _aktifFiltre,
      onApply: (FilterOptions options) {
        _aktifFiltre = options;
        _gosterAktifTab();
        if (mounted) setState(() {});
      },
      onReset: () {
        _aktifFiltre = FilterOptions();
        _gosterAktifTab();
        if (mounted) setState(() {});
      },
    );
  }

  void _kontrolMesajlar() {
    if (_userId.isEmpty) return;
    _mesajSubscription?.cancel();
    _mesajSubscription = _db
        .collection('users')
        .doc(_userId)
        .collection('inbox')
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() => _unreadCount = snapshot.docs.length);
    });
  }

  Future<void> _kendiProfilimiGetir() async {
    if (_userId.isEmpty) return;
    
    final doc = await _db.collection('users').doc(_userId).get();
    if (doc.exists && mounted) {
      setState(() {
        _profileImageUrl = doc.data()?['profilResmiUrl']; // Veritabanından direkt alıyoruz
      });
    }
  }
  void _onTabChanged(int index) {
    if (_tabIndex == index) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      return;
    }
    
    // ÖNCE sekmeyi değiştirip arayüzü güncelliyoruz
    setState(() {
      _tabIndex = index;
      _paylasimTuru = _tabs[index].paylasimTuru;
      _postListesi.clear(); // Yeni sekmeye geçerken eski listeyi temizle
    });
    
    _temizleTabaOzelFiltreler();
    
    // SONRA yeni sekmeye göre verileri sunucudan istiyoruz
    _getData();
  }

  void _temizleTabaOzelFiltreler() {
    if (_paylasimTuru != 'İkinci El Eşya') {
      _aktifFiltre.esyaDurumu = null;
    }
    if (_paylasimTuru != 'Kayıp Eşya' &&
        _aktifFiltre.kategori == 'Kimlik / Kart') {
      _aktifFiltre.kategori = null;
      _aktifFiltre.altKategori = null;
    }
  }

  Future<void> _yenile() async {
    _tumSonuclar.clear();
    if (mounted) setState(() => _postListesi.clear());
    _getData();
    _kontrolMesajlar();
  }

  void _stopRefresh() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _refreshStartMs;
    final remaining = (1500 - elapsed).clamp(0, 1500);
    Future.delayed(Duration(milliseconds: remaining), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _durdurDinleyiciler() {
    _postSubscription?.cancel();
    _mesajSubscription?.cancel();
  }

  void _guestUyari() {
    // Önce kullanıcıya ufak bir bilgi veriyoruz
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu işlem için giriş yapmalısınız.')),
    );
    
    // Sonra doğrudan Giriş/Kayıt sayfasına yönlendiriyoruz
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()), // Kendi giriş sayfanın adını buraya yaz
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI (Arayüzde değişiklik yok)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
             _FeedToolbar(
                profileImageUrl: _profileImageUrl,
                unreadCount: _unreadCount,
                
                // 1. MESAJLAR (INBOX) BUTONU
                onMessagesPressed: () {
                  if (_userId.isEmpty) {
                    _guestUyari(); // Giriş yapmamışsa uyar ve logine at
                  } else {
                    // Giriş yapmışsa Inbox'a gönder
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InboxScreen()),
                    );
                  }
                },
                
                // 2. KENDİ PROFİLİNE GİTME BUTONU
                onProfilePressed: () {
                  if (_userId.isEmpty) {
                    _guestUyari();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: _userId,
                          nereden: 'KendiProfili', // Kendi profili olduğunu belirtiyoruz
                        ),
                      ),
                    );
                  }
                },
                
                
                // 3. SAĞ MENÜ (Burası zaten çalışıyordu)
                onOptionsPressed: () {
                  showOptionsSideMenu(context, paylasimTuru: _paylasimTuru);
                },
              ),
              // 🔥 KAYBOLAN SEKMELER (İkinci El, Kayıp Eşya, Bağış) BURADA 🔥
              _FeedTabBar(
                tabs: _tabs,
                selectedIndex: _tabIndex,
                onTabSelected: _onTabChanged,
              ),

              // 🔥 KAYBOLAN AKTİF FİLTRE BALONCUKLARI BURADA 🔥
              _ActiveFilterChips(
                filter: _aktifFiltre,
                onRemove: (field) {
                  setState(() {
                    if (field == 'universite') _aktifFiltre.universite = null;
                    if (field == 'kategori') _aktifFiltre.kategori = null;
                    if (field == 'altKategori') _aktifFiltre.altKategori = null;
                    if (field == 'esyaDurumu') _aktifFiltre.esyaDurumu = null;
                    if (field == 'hedefKitle') _aktifFiltre.hedefKitle = null;
                    if (field == 'etiket') _aktifFiltre.etiket = null;
                  });
                  _gosterAktifTab();
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _yenile,
                  child: _isLoading && _postListesi.isEmpty
                      ? const _LoadingIndicator()
                      : _postListesi.isEmpty
                          ? _EmptyState(paylasimTuru: _paylasimTuru)
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                              itemCount: _postListesi.length,
                              itemBuilder: (_, i) {
                                final post = _postListesi[i];
                                return PostCard(
                                  key: ValueKey(post.documentId),
                                  post: post,
                                  onTap: () {},
                                  onMessage: () {},
                                  onBookmark: () {}, 
                                  currentUserId: _userId, // ID eklendi
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFabs(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

 Widget _buildFabs() {
    final filterLabel = _aktifFiltre.activeCount > 0
        ? 'Filtrele (${_aktifFiltre.activeCount})'
        : 'Filtrele';

    // Column yerine Row kullanıyoruz ki butonlar yan yana gelsin
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end, // Butonları sağa yaslar
      crossAxisAlignment: CrossAxisAlignment.center, // Dikeyde ortalar
      children: [
        // 1. Soldaki Buton (Filtrele)
        FloatingActionButton.extended(
          heroTag: 'fab_filter',
          onPressed: _filtreAc,
          label: Text(
            filterLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          icon: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
          backgroundColor: _aktifFiltre.isEmpty ? AppColors.primary : AppColors.accent,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        
        // İki buton arasındaki yatay boşluk (height yerine width yaptık)
        const SizedBox(width: 11), 
        
       // 2. Sağdaki Buton (İlan Paylaş)
        FloatingActionButton(
          heroTag: 'fab_post',
          onPressed: () {
            if (_userId.isEmpty) {
              _guestUyari(); // Giriş yapmamışsa uyar
            } else {
              // GİRİŞ YAPMIŞSA YENİ İLAN SAYFASINA GİT
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewPostScreen(), // Sayfanın adını kontrol et
                ),
              );
            }
          },
          backgroundColor: AppColors.accent,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ALT BİLEŞENLER (Buradan aşağısı arayüz kodları, değişiklik yapılmadı)
// ══════════════════════════════════════════════════════════════════════════════

class _TabDef {
  const _TabDef({required this.label, required this.paylasimTuru});
  final String label;
  final String paylasimTuru;
}

class _FeedToolbar extends StatelessWidget {
  const _FeedToolbar({
    this.profileImageUrl,
    required this.unreadCount,
    required this.onMessagesPressed,
    required this.onProfilePressed,
    required this.onOptionsPressed,
  });

  final String? profileImageUrl;
  final int unreadCount;
  final VoidCallback onMessagesPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erzurum Kampüs',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontSize: 22),
                ),
                Text(
                  'Kampüste neler oluyor?',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ToolbarButton(
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onMessagesPressed,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _MessageBadge(count: unreadCount),
                ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onProfilePressed,
            child: _ProfileAvatar(imageUrl: profileImageUrl),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.more_vert_rounded,
            onPressed: onOptionsPressed,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: AppColors.textPrimary),
        onPressed: onPressed,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentSoft,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  // Resim yüklenirken veya resim yoksa gösterilecek yuvarlak adam ikonu
  Widget _buildPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSoft,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, size: 22, color: AppColors.accent),
    );
  }
}
class _MessageBadge extends StatelessWidget {
  const _MessageBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FeedTabBar extends StatelessWidget {
  const _FeedTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.accentGlow,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filter,
    required this.onRemove,
  });

  final FilterOptions filter;
  final ValueChanged<String> onRemove;

  static String _kisalt(String uni) {
    if (uni.contains('Teknik')) return 'ETÜ';
    if (uni.contains('Atatürk')) return 'ATA';
    return uni;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <(String field, String label)>[
      if (filter.universite != null)
        ('universite', '🎓 ${_kisalt(filter.universite!)}'),
      if (filter.kategori != null)
        ('kategori', '📦 ${filter.kategori}'),
      if (filter.altKategori != null)
        ('altKategori', '→ ${filter.altKategori}'),
      if (filter.esyaDurumu != null)
        ('esyaDurumu', '🔖 ${filter.esyaDurumu}'),
      if (filter.hedefKitle != null)
        ('hedefKitle', '👥 ${filter.hedefKitle}'),
      if (filter.etiket != null && filter.etiket!.isNotEmpty)
        ('etiket', '🏷️ ${filter.etiket}'),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (_, i) {
          final (field, label) = chips[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
            child: _FilterChipItem(
              label: label,
              onDelete: () => onRemove(field),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({required this.label, required this.onDelete});
  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accent,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.paylasimTuru});
  final String paylasimTuru;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String msg) = switch (paylasimTuru) {
      'İkinci El Eşya' => (Icons.storefront_outlined, 'Henüz ikinci el ilan yok'),
      'Kayıp Eşya'     => (Icons.search_off_rounded, 'Kayıp eşya ilanı bulunamadı'),
      'Bağış'          => (Icons.volunteer_activism_outlined, 'Henüz bağış ilanı yok'),
      _                => (Icons.inbox_outlined, 'İlan bulunamadı'),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            msg,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Aşağı çekerek yenile',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}