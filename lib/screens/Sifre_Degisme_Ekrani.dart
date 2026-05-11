// ignore_for_file: avoid_print
import 'package:erzurum_kampus/screens/forgot_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart'; // Kendi renk dosyanın yolunu ayarla

// Şifremi Unuttum ekranının import'unu kendi projene göre ayarla:
// import 'forgot_password_screen.dart'; 

class SifreDegismeEkrani extends StatefulWidget {
  const SifreDegismeEkrani({super.key});

  @override
  State<SifreDegismeEkrani> createState() => _SifreDegismeEkraniState();
}

class _SifreDegismeEkraniState extends State<SifreDegismeEkrani> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Kontrolcüler
  final TextEditingController _eskiSifreController = TextEditingController();
  final TextEditingController _yeniSifreController = TextEditingController();
  final TextEditingController _yeniSifreTekrarController = TextEditingController();

  // Şifre görünürlük durumları
  bool _obscureEski = true;
  bool _obscureYeni = true;
  bool _obscureTekrar = true;

  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Sayfa açılış animasyonu
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _eskiSifreController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreTekrarController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── ŞİFRE GÜNCELLEME İŞLEMİ (FIREBASE) ───────────────────────────────────
  Future<void> _sifreyiGuncelle() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Firebase güvenlik gereği önce kullanıcının mevcut şifresini doğruluyoruz (Re-authenticate)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _eskiSifreController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Doğrulama başarılıysa yeni şifreyi atıyoruz
      await user.updatePassword(_yeniSifreController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreniz başarıyla güncellendi! 🔒', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // İşlem bitince sayfayı kapat
      }
    } on FirebaseAuthException catch (e) {
      String hataMesaji = 'Bir hata oluştu.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        hataMesaji = 'Mevcut şifrenizi yanlış girdiniz.';
      } else if (e.code == 'weak-password') {
        hataMesaji = 'Yeni şifreniz çok zayıf. Daha güçlü bir şifre belirleyin.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hataMesaji), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── EKRAN ÇİZİMİ (UI) ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Şifre İşlemleri', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // Ekrana tıklayınca klavyeyi gizle
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst İkon ve Bilgilendirme
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, size: 64, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Hesap Güvenliği',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Şifrenizi yenilemek için mevcut şifrenizi doğrulamalısınız.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Eski Şifre Alanı
                  _buildSectionTitle('Mevcut Şifreniz'),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: _eskiSifreController,
                    label: 'Şu anki şifrenizi girin',
                    isObscured: _obscureEski,
                    onToggleVisibility: () => setState(() => _obscureEski = !_obscureEski),
                    validator: (val) => val == null || val.isEmpty ? 'Mevcut şifre boş bırakılamaz' : null,
                  ),
                  
                  // 🔥 ŞİFREMİ UNUTTUM BUTONU 🔥
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Şifremi Unuttum',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Yeni Şifre Alanı
                  _buildSectionTitle('Yeni Şifre'),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: _yeniSifreController,
                    label: 'Yeni şifrenizi belirleyin',
                    isObscured: _obscureYeni,
                    onToggleVisibility: () => setState(() => _obscureYeni = !_obscureYeni),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Yeni şifre boş bırakılamaz';
                      if (val.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Yeni Şifre Tekrar Alanı
                  _buildSectionTitle('Yeni Şifre (Tekrar)'),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: _yeniSifreTekrarController,
                    label: 'Yeni şifrenizi tekrar girin',
                    isObscured: _obscureTekrar,
                    onToggleVisibility: () => setState(() => _obscureTekrar = !_obscureTekrar),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Şifre tekrarı boş bırakılamaz';
                      if (val != _yeniSifreController.text) return 'Şifreler birbiriyle eşleşmiyor!';
                      return null;
                    },
                  ),

                  const SizedBox(height: 48),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _sifreyiGuncelle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: AppColors.accent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('Şifreyi Güncelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TASARIM YARDIMCILARI ───────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 0.5),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textMuted),
          onPressed: onToggleVisibility,
          splashRadius: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}