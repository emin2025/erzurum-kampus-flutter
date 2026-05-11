// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erzurum_kampus/screens/NewPostScreenState.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// Kendi yollarını kontrol et
import '../theme/app_colors.dart';
import 'PostCard.dart';
import 'Post.dart';
import 'ProfilDuzenle.dart';
// import 'IlanVerScreen.dart'; // ← İlan verme ekranını buraya import et
// import 'ChatScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    this.nereden = 'postProfili',
    this.kategori,
  });

  final String userId;
  final String nereden;
  final String? kategori;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;
  bool _showFavorites = false;

  // Sayfa açılış animasyonu
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchUserData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await _db.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() {
          _userData    = doc.data();
          _isLoadingUser = false;
        });
        _fadeCtrl.forward();
      } else {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      print('Profil çekme hatası: $e');
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // ── Telefon arama ─────────────────────────────────────────────────────────
  Future<void> _aramaYap(String telefon) async {
    final uri = Uri(scheme: 'tel', path: telefon);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content  : Text('Arama başlatılamadı.'),
            behavior : SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _currentUserId;

    final ad      = _userData?['ad']    as String? ?? '';
    final soyad   = _userData?['soyad'] as String? ?? '';
    final fullName = ad.isNotEmpty ? '$ad $soyad'.trim() : 'Bilinmeyen Kullanıcı';

    final profileImageUrl = _userData?['profilResmiUrl'] as String?;
    final bio             = (_userData?['bio']    as String? ?? '').trim();
    final bolum           = (_userData?['bolum']  as String? ?? '').trim();
    final telefon         = (_userData?['telefon'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,

    // ── FAB: Sağ alta, ilan verme ─────────────────────────────────────────
      floatingActionButton: isOwnProfile
          ? FloatingActionButton.extended(
              heroTag        : 'ilan_ver_fab',
              onPressed      : () {
                
                 Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const NewPostScreen(),
              ));
              },
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation      : 6,
              icon           : const Icon(Icons.add_rounded, size: 22),
              label          : const Text(
                'İlan Ver',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )
          : null,
      // 👇 Sadece bu satır değişti (startFloat -> endFloat) 👇
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation      : 0,
        title: Text(
          isOwnProfile ? 'Profilim' : 'Kullanıcı Profili',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon     : const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilDuzenle()),
              ),
            ),
        ],
      ),

      body: _isLoadingUser
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Profil Kartı ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 20, right: 20, top: 8, bottom: 8),
                      child: Column(
                        children: [
                          // Avatar
                          Hero(
                            tag : 'profile_${widget.userId}',
                            child: Container(
                              decoration: BoxDecoration(
                                shape    : BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color     : AppColors.accent.withOpacity(0.2),
                                    blurRadius: 24,
                                    offset    : const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius         : 54,
                                backgroundColor: AppColors.surfaceSecondary,
                                backgroundImage: profileImageUrl != null
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                                child: profileImageUrl == null
                                    ? const Icon(Icons.person_rounded,
                                        size : 50,
                                        color: AppColors.accent)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // İsim
                          Text(
                            fullName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color     : AppColors.textPrimary,
                                ),
                          ),

                          // Bölüm rozeti (varsa)
                          if (bolum.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_rounded,
                                      size : 14,
                                      color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    bolum,
                                    style: TextStyle(
                                      fontSize  : 13,
                                      fontWeight: FontWeight.w600,
                                      color     : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Bio (varsa)
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color : AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── Bilgi Satırları (Telefon) ─────────────────────
                          if (telefon.isNotEmpty)
                            _buildInfoTile(
                              icon    : Icons.phone_rounded,
                              label   : telefon,
                              onTap   : () => _aramaYap(telefon),
                              trailing: Icon(
                                Icons.call_rounded,
                                size : 18,
                                color: AppColors.accent,
                              ),
                            ),

                          if (telefon.isNotEmpty) const SizedBox(height: 8),

                          // ── Mesaj Gönder Butonu (başkasının profili) ──────
                          if (!isOwnProfile) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // TODO: ChatScreen'e yönlendir
                                },
                                icon : const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18),
                                label: const Text('Mesaj Gönder'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // ── Tab Bar ───────────────────────────────────────
                          if (isOwnProfile)
                            _buildTabBar()
                          else
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'İlanları',
                                style: TextStyle(
                                  fontSize  : 18,
                                  fontWeight: FontWeight.w800,
                                  color     : AppColors.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── İlanlar / Favoriler ───────────────────────────────────
                  _showFavorites
                      ? _buildFavoritePostsSliver()
                      : _buildUserPostsSliver(isOwnProfile),

                  // Alt boşluk (FAB için extra)
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  YARDIMCI WİDGETLAR
  // ─────────────────────────────────────────────────────────────────────────

  /// Tek bir bilgi satırı (Telefon, vb.)
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.accent.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color     : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset    : const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color       : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize  : 14,
                  fontWeight: FontWeight.w600,
                  color     : AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// Gönderiler / Favoriler tab bar
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color    : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset   : const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(
            label   : 'Gönderilerim',
            icon    : Icons.grid_view_rounded,
            selected: !_showFavorites,
            onTap   : () => setState(() => _showFavorites = false),
          ),
          _buildTabItem(
            label   : 'Favorilerim',
            icon    : Icons.favorite_border_rounded,
            selected: _showFavorites,
            onTap   : () => setState(() => _showFavorites = true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration : const Duration(milliseconds: 220),
          curve    : Curves.easeOut,
          padding  : const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color       : selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size : 16,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize  : 13,
                  fontWeight: FontWeight.w700,
                  color     : selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Boş durum widget'ı ────────────────────────────────────────────────────

  Widget _buildEmptyState({required IconData icon, required String text}) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48.0),
          child: Column(
            children: [
              Icon(icon, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(text,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  İLANLAR SLİVERİ
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUserPostsSliver(bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('Posts')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child  : CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
                child: Text('Bir hata oluştu: ${snapshot.error}')),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            text: isOwnProfile
                ? 'Henüz hiç ilan paylaşmadın.'
                : 'Bu kullanıcının ilanı yok.',
          );
        }

        final posts = docs
            .map((doc) =>
                Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .whereType<Post>()
            .toList()
          ..sort((a, b) {
            final tA = a.timestamp;
            final tB = b.timestamp;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
          sliver : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => PostCard(
                key          : ValueKey(posts[index].documentId),
                post         : posts[index],
                currentUserId: _currentUserId,
                onTap        : () {},
                onMessage    : () {},
                onBookmark   : () {},
              ),
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FAVORİLER SLİVERİ
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFavoritePostsSliver() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(widget.userId)
          .collection('favorites')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, favSnapshot) {
        if (favSnapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child  : CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          );
        }

        if (favSnapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
                child: Text(
                    'Favoriler alınırken hata oluştu: ${favSnapshot.error}')),
          );
        }

        final favDocs = favSnapshot.data?.docs ?? [];

        if (favDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border_rounded,
            text: 'Henüz favorilenmiş ilan yok.',
          );
        }

        List<String> postIds = favDocs
            .map((doc) => doc['postId'] as String?)
            .whereType<String>()
            .toList();

        if (postIds.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox());
        }

        if (postIds.length > 30) postIds = postIds.sublist(0, 30);

        return FutureBuilder<QuerySnapshot>(
          future : _db
              .collection('Posts')
              .where('documentId', whereIn: postIds)
              .get(),
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child  : CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
              );
            }

            final postDocs = postSnapshot.data?.docs ?? [];
            if (postDocs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.search_off_rounded,
                text: 'Favori ilanlar bulunamadı.',
              );
            }

            final posts = postDocs
                .map((doc) =>
                    Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                .whereType<Post>()
                .toList();

            posts.sort((a, b) {
              final idA    = a.documentId ?? '';
              final idB    = b.documentId ?? '';
              int indexA   = postIds.indexOf(idA);
              int indexB   = postIds.indexOf(idB);
              if (indexA == -1) indexA = 9999;
              if (indexB == -1) indexB = 9999;
              return indexA.compareTo(indexB);
            });

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
              sliver : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PostCard(
                    key          : ValueKey(posts[index].documentId),
                    post         : posts[index],
                    currentUserId: _currentUserId,
                    onTap        : () {},
                    onMessage    : () {},
                    onBookmark   : () {},
                  ),
                  childCount: posts.length,
                ),
              ),
            );
          },
        );
      },
    );
  }
}