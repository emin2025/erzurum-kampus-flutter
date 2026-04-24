// ignore_for_file: avoid_print

import 'package:erzurum_kampus/screens/InboxScreen.dart';
import 'package:erzurum_kampus/screens/ProfilDuzenle.dart';
import 'package:erzurum_kampus/screens/Sifre_Degisme_Ekrani.dart';
import 'package:erzurum_kampus/screens/login_screen.dart';
import 'package:erzurum_kampus/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart'; // Renk dosyanın yolunu buraya göre ayarla

// Sayfa Yönlendirmeleri - Kendi projene göre import yollarını kontrol et
import 'ProfileScreen.dart'; 
// import 'ProfilDuzenle.dart';
// import 'Sifre_Degisme_Ekrani.dart';

/// Ekranın sağından kayarak açılan özel seçenekler menüsü (Java'daki DialogSlideFromRight)
void showOptionsSideMenu(BuildContext context, {required String paylasimTuru}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Seçenekler Menüsü",
    barrierColor: Colors.black.withOpacity(0.5), // Arka plan karartması
    transitionDuration: const Duration(milliseconds: 350), // Kayma hızı
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight, // Sağa yasla
        child: Material(
          elevation: 16,
          // Sadece sol köşeleri yuvarlatılmış modern tasarım
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.75, // Ekranın %75'i (Java'daki ile aynı)
            height: MediaQuery.of(context).size.height,
            child: _OptionsMenuContent(tur: paylasimTuru),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Sağdan sola kayma animasyonu
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
  );
}

class _OptionsMenuContent extends StatefulWidget {
  final String tur;
  const _OptionsMenuContent({required this.tur});

  @override
  State<_OptionsMenuContent> createState() => _OptionsMenuContentState();
}

class _OptionsMenuContentState extends State<_OptionsMenuContent> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _currentUser;
  bool _isLoading = true;

  String _userName = 'Kullanıcı';
  String _userEmail = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserData();
  }

  // 🔥 Java'daki fetchUserData() metodunun Dart karşılığı
  Future<void> _fetchUserData() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        
        final ad = data?['ad'] as String?;
        final soyad = data?['soyad'] as String?;
        final email = data?['email'] as String?;
        final profilResmiUrl = data?['profilResmiUrl'] as String?;

        setState(() {
          if (ad != null && soyad != null) {
            _userName = '$ad $soyad';
          } else if (ad != null) {
            _userName = ad;
          }

          _userEmail = email ?? _currentUser!.email ?? '';
          _profileImageUrl = profilResmiUrl;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Kullanıcı verisi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cikisYap() async {
    // Çıkış onayı dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumu Kapat'),
        content: const Text('Mevcut hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (_currentUser != null) {
          await _db.collection('users').doc(_currentUser!.uid).update({
            'pushToken': FieldValue.delete(),
          });
        }
      } catch (_) {} 

      await _auth.signOut();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum kapatıldı')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = _currentUser != null;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // ── ÜST PROFİL ALANI ──
            if (isLoggedIn)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: _currentUser!.uid,
                        kategori: widget.tur,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  width: double.infinity,
                  color: AppColors.surface,
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.accentSoft,
                          backgroundImage: _profileImageUrl != null 
                              ? NetworkImage(_profileImageUrl!) 
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person_rounded, size: 40, color: AppColors.accent)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        if (_userEmail.isNotEmpty)
                          Text(
                            _userEmail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                ),
              ),

            const Divider(height: 1, color: AppColors.border),

            // ── MENÜ LİSTESİ ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (isLoggedIn) ...[
                      _MenuRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Profilim',
                        isPrimary: true,
                        onTap: () {
                          Navigator.pop(context); // Menüyü kapat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: _currentUser!.uid,
                                kategori: widget.tur,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _MenuRow(
                        icon: Icons.edit_outlined,
                        title: 'Profili Düzenle',
                       onTap: () {
                      Navigator.pop(context); // Önce sağ menüyü zarifçe kapatıyoruz
    
                      // Ardından ultra lüks Profil Düzenleme sayfamızı açıyoruz:
                             Navigator.push(
                             context, 
                         MaterialPageRoute(builder: (context) => const ProfilDuzenle()),
                                       );
                                    },
                      ),
                      _MenuRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Sohbet',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InboxScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Şifre İşlemleri',
                       onTap: () {
                      Navigator.pop(context); // Sağ menüyü kapat
                          Navigator.push(
                       context, 
                       MaterialPageRoute(builder: (_) => const SifreDegismeEkrani())
                             );
                           },
                      ),
                      _MenuRow(
                        icon: Icons.help_outline_rounded,
                        title: 'Yardım ve Destek',
                        onTap: () {
                          Navigator.pop(context); // Sağ paneli kapat
                          _showUltraModernSupportBottomSheet(context); // Destek panelini alttan aç
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 56, right: 16, top: 4, bottom: 12),
                        child: Text(
                          "Bize uygulama içinden öneri ve şikayetlerinizi iletebilirsiniz.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ] else ...[
                      // GİRİŞ YAPMAMIŞ KULLANICI MENÜSÜ
                      _MenuRow(
                        icon: Icons.person_add_outlined,
                        title: 'Kayıt Ol',
                        iconColor: Colors.green,
                        isPrimary: true,
                        onTap: () {
                          Navigator.pop(context); 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())); 
                        },
                      ),
                    ],

                    const Divider(height: 24, color: AppColors.border),

                    // ── GİRİŞ / ÇIKIŞ BUTONU ──
                    if (isLoggedIn)
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        title: 'Oturumu Kapat',
                        iconColor: Colors.redAccent,
                        textColor: Colors.redAccent,
                        onTap: _cikisYap,
                      )
                    else
                      _MenuRow(
                        icon: Icons.login_rounded,
                        title: 'Giriş Yap',
                        iconColor: Colors.blueAccent,
                        textColor: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(context); 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı Menü Satırı Tasarımı ──
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? iconColor;
  final Color? textColor;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isPrimary = false,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.accentSoft,
      highlightColor: AppColors.accentSoft.withOpacity(0.3),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPrimary ? 20 : 28, 
          vertical: isPrimary ? 16 : 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isPrimary ? 24 : 22,
              color: iconColor ?? (isPrimary ? AppColors.accent : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  YARDIM VE DESTEK (ULTRA MODERN BOTTOM SHEET)
// ══════════════════════════════════════════════════════════════════════════

void _showUltraModernSupportBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Klavyenin üzerine çıkabilmesi için gerekli
    backgroundColor: Colors.transparent,
    builder: (context) => const _SupportBottomSheetContent(),
  );
}

class _SupportBottomSheetContent extends StatefulWidget {
  const _SupportBottomSheetContent();

  @override
  State<_SupportBottomSheetContent> createState() => _SupportBottomSheetContentState();
}

class _SupportBottomSheetContentState extends State<_SupportBottomSheetContent> {
  final TextEditingController _feedbackController = TextEditingController();
  final List<String> _categories = ['Öneri', 'Hata Bildirimi', 'Şikayet', 'Soru', 'Diğer'];
  String _selectedCategory = 'Öneri';
  bool _isLoading = false;

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen detaylı bir açıklama yazın.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('SupportRequests').add({
        'userId': user?.uid ?? 'Anonim',
        'kategori': _selectedCategory,
        'mesaj': text,
        'tarih': FieldValue.serverTimestamp(),
        'durum': 'Bekliyor', // Admin paneli vs. için
      });

      if (!mounted) return;
      Navigator.pop(context); // Sheet'i kapat

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesajınız başarıyla iletildi. Teşekkür ederiz!'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Klavyenin açık olup olmadığını ve yüksekliğini hesaplamak için
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle (Kaydırma Çubuğu)
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Başlık Alanı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bize Ulaşın',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Nasıl yardımcı olabiliriz?',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Kategori Seçimi (Yatay Kaydırılabilir Şık Tipler)
            const Text(
              'Konu Başlığı Seçin',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Metin Alanı
            const Text(
              'Detaylar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Aklınızdakileri bizimle paylaşın...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Gönder Butonu
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Text(
                        'Gönder',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}