// ignore_for_file: avoid_print
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart'; // Kendi renk dosyanızın yolu

class ProfilDuzenle extends StatefulWidget {
  const ProfilDuzenle({super.key});

  @override
  State<ProfilDuzenle> createState() => _ProfilDuzenleState();
}

class _ProfilDuzenleState extends State<ProfilDuzenle> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  // Kontrolcüler
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _bolumController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  
  String? _mevcutProfilUrl;
  File? _secilenResim;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    
    // Sayfa açılış animasyonu
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    
    _kullaniciVerileriniCek();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telefonController.dispose();
    _bolumController.dispose();
    _bioController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── VERİ ÇEKME ─────────────────────────────────────────────────────────────
  Future<void> _kullaniciVerileriniCek() async {
    if (_currentUser == null) return;
    try {
      final doc = await _db.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _adController.text = data['ad'] ?? '';
          _soyadController.text = data['soyad'] ?? '';
          _telefonController.text = data['telefon'] ?? '';
          _bolumController.text = data['bolum'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _mevcutProfilUrl = data['profilResmiUrl'];
          _isLoading = false;
        });
        _animController.forward(); // Veriler gelince animasyonla göster
      }
    } catch (e) {
      print('Veri çekme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── RESİM SEÇME ────────────────────────────────────────────────────────────
  Future<void> _resimSec(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Optimize edilmiş boyut
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _secilenResim = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Resim seçme hatası: $e');
    }
  }

  void _resimSecenekleriniGoster() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Profil Fotoğrafı Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ModalButton(icon: Icons.camera_alt_rounded, label: 'Kamera', color: AppColors.accent, onTap: () {
                  Navigator.pop(context);
                  _resimSec(ImageSource.camera);
                }),
                _ModalButton(icon: Icons.photo_library_rounded, label: 'Galeri', color: Colors.blueAccent, onTap: () {
                  Navigator.pop(context);
                  _resimSec(ImageSource.gallery);
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── VERİ KAYDETME ──────────────────────────────────────────────────────────
  Future<void> _profiliKaydet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      String? yeniResimUrl = _mevcutProfilUrl;

      // 1. Eğer yeni resim seçildiyse Storage'a yükle
      if (_secilenResim != null) {
        final ref = _storage.ref().child('profil_images/${_currentUser!.uid}_.jpg');
        await ref.putFile(_secilenResim!);
        yeniResimUrl = await ref.getDownloadURL();
      }

      // 2. Firestore'u güncelle
      await _db.collection('users').doc(_currentUser!.uid).update({
        'ad': _adController.text.trim(),
        'soyad': _soyadController.text.trim(),
        'telefon': _telefonController.text.trim(),
        'bolum': _bolumController.text.trim(),
        'bio': _bioController.text.trim(),
        if (yeniResimUrl != null) 'profilResmiUrl': yeniResimUrl,
        'sonGuncelleme': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profiliniz başarıyla güncellendi! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Düzenleme sayfasından çık
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── EKRAN ÇİZİMİ (UI) ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Profili Düzenle', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(), // Ekrana tıklayınca klavyeyi kapat
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Avatar Bölümü
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Hero(
                                tag: 'profile_avatar',
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 4),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                 child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey.shade100,
                                    backgroundImage: _secilenResim != null
                                        ? FileImage(_secilenResim!) as ImageProvider
                                        : (_mevcutProfilUrl != null && _mevcutProfilUrl!.isNotEmpty
                                            ? CachedNetworkImageProvider(_mevcutProfilUrl!) // 🔥 CACHE SİSTEMİ EKLENDİ
                                            : null),
                                    child: (_secilenResim == null && (_mevcutProfilUrl == null || _mevcutProfilUrl!.isEmpty))
                                        ? const Icon(Icons.person_rounded, size: 50, color: Colors.grey)
                                        : null,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _resimSecenekleriniGoster,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Alanları
                        _buildSectionTitle('Kişisel Bilgiler'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _adController, label: 'Ad', icon: Icons.person_outline_rounded)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _soyadController, label: 'Soyad')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bolumController,
                          label: 'Bölüm / Fakülte',
                          icon: Icons.school_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _telefonController,
                          label: 'Telefon Numarası',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 32),
                        _buildSectionTitle('Hakkımda'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Kendinizden bahsedin...',
                          icon: Icons.edit_note_rounded,
                          maxLines: 4,
                          maxLength: 150,
                        ),

                        const SizedBox(height: 40),

                        // Kaydet Butonu
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _profiliKaydet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: AppColors.accent.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 40), // Alt boşluk
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      validator: (value) {
        if (label == 'Ad' || label == 'Soyad') {
          if (value == null || value.trim().isEmpty) return 'Bu alan boş bırakılamaz';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
        filled: true,
        fillColor: Colors.white,
        counterText: "", // maxLength altındaki sayacı gizler (isteğe bağlı)
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

// Bottom Sheet içindeki buton tasarımı
class _ModalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModalButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}