// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

// Kendi yollarını kontrol et
import 'ChatScreen.dart';
import '../theme/app_colors.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mesajlarım')),
        body: const Center(child: Text("Lütfen giriş yapın.")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mesajlarım', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(_currentUserId)
            .collection('inbox')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Bir hata oluştu."));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Henüz hiç mesajın yok.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, color: AppColors.border),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _InboxTile(
                data: data,
                currentUserId: _currentUserId,
                onDeleteChat: (targetId) => _clearChatHistory(targetId),
              );
            },
          );
        },
      ),
    );
  }

  // ── SOHBETİ TEMİZLEME MANTIĞI (Java'daki clearChatHistoryForCurrentUser karşılığı) ──
  Future<void> _clearChatHistory(String otherUserId) async {
    final chatId = _currentUserId.compareTo(otherUserId) < 0
        ? '${_currentUserId}_$otherUserId'
        : '${otherUserId}_$_currentUserId';

    try {
      final querySnapshot = await _db.collection('chats').doc(chatId).collection('messages').get();
      final batch = _db.batch();
      bool shouldCommit = false;

      // Tüm mesajlara "deletedFor" bilgisini ekle
      for (var doc in querySnapshot.docs) {
        List<dynamic> deletedFor = doc.data()['deletedFor'] ?? [];
        if (!deletedFor.contains(_currentUserId)) {
          deletedFor.add(_currentUserId);
          batch.update(doc.reference, {'deletedFor': deletedFor});
          shouldCommit = true;
        }
      }

      // Kendi inbox'ından sil
      final inboxRef = _db.collection('users').doc(_currentUserId).collection('inbox').doc(otherUserId);
      batch.delete(inboxRef);
      shouldCommit = true;

      if (shouldCommit) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sohbet geçmişi temizlendi.')),
          );
        }
      }
    } catch (e) {
      print('Sohbet silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sohbet temizlenirken bir hata oluştu.')),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Her Bir Sohbet Satırı (Tile)
// ══════════════════════════════════════════════════════════════════════════════
class _InboxTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final String currentUserId;
  final Function(String) onDeleteChat;

  const _InboxTile({
    required this.data,
    required this.currentUserId,
    required this.onDeleteChat,
  });

  @override
  State<_InboxTile> createState() => _InboxTileState();
}

class _InboxTileState extends State<_InboxTile> {
  String _name = "Bilinmeyen Kullanıcı";
  String? _profileUrl;

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
  }

  // Java'daki kullanıcı adı ve soyadı çekme işlemi
  Future<void> _loadOtherUserInfo() async {
    final otherId = widget.data['otherUserId'];
    if (otherId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
      if (doc.exists && mounted) {
        final d = doc.data();
        final ad = d?['ad'] as String? ?? '';
        final soyad = d?['soyad'] as String? ?? '';
        
        setState(() {
          _name = _capitalize(ad) + " " + _capitalize(soyad);
        });

        // Glide yerine Firebase Storage'dan profil resmini çekip NetworkImage'a verme
        try {
          final url = await FirebaseStorage.instance.ref('profil_images/${otherId}_.jpg').getDownloadURL();
          if (mounted) setState(() => _profileUrl = url);
        } catch (_) {}
      }
    } catch (e) {
      print("Kullanıcı bilgisi çekilemedi: $e");
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Java'daki SimpleDateFormat karşılığı
  String _formatTime(dynamic ts) {
    if (ts == null) return "";
    
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      return "";
    }

    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    // Eğer dün ise
    if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
      return 'Dün';
    }
    return DateFormat('dd MMM', 'tr_TR').format(dt); // Örn: 12 Nis
  }

  @override
  Widget build(BuildContext context) {
    final otherId = widget.data['otherUserId'];
    final lastMsg = widget.data['lastMessage'] ?? "Mesaj yok";
    final seen = widget.data['seen'] ?? true;
    final timeStr = _formatTime(widget.data['timestamp']);

    if (otherId == null) return const SizedBox.shrink(); // Çökme Önlemi

    return InkWell(
      // Tıklayınca Sohbete Git
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(hedefUserId: otherId)),
        );
      },
      // ── UZUN BASINCA SİLME İŞLEMİ ──
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sohbeti Temizle'),
            content: const Text(
                'Bu kullanıcıyla olan tüm sohbet geçmişini SADECE sizin için silmek istiyor musunuz? Bu işlem geri alınamaz.'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDeleteChat(otherId); // Üst widget'a silme emrini gönder
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Evet, Temizle', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Profil Resmi
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accentSoft,
              backgroundImage: _profileUrl != null ? NetworkImage(_profileUrl!) : null,
              child: _profileUrl == null ? const Icon(Icons.person_rounded, color: AppColors.accent, size: 30) : null,
            ),
            const SizedBox(width: 16),
            // Mesaj ve İsim Detayları
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _name,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: seen ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: seen ? Colors.grey : AppColors.textPrimary,
                          fontWeight: seen ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: seen ? Colors.grey[600] : AppColors.textPrimary,
                            fontWeight: seen ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      // Mavi Nokta (Okunmamış Mesaj Belirteci)
                      if (!seen) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF15C0A4), // Mavi/Yeşil okundu noktası
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}