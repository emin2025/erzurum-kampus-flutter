// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erzurum_kampus/screens/NewPostScreenState.dart';
import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';


const _kWebFallback = 'https://etucampusapp.web.app/post';
class PostOptionsBottomSheet extends StatefulWidget {
  const PostOptionsBottomSheet({
    super.key,
    required this.postId,

    required this.isOwner,
    required this.ownerId,
    required this.kategori,
    this.postTitle,
  });

  final String  postId;
  final bool    isOwner;
  final String  ownerId;
  final String? kategori;
  final String? postTitle;

  static Future<void> show({
    required BuildContext context,
    required String postId,
    required bool isOwner,
    required String ownerId,
    required String? kategori,
    String? postTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PostOptionsBottomSheet(
        postId:    postId,
        isOwner:   isOwner,
        ownerId:   ownerId,
        kategori:  kategori,
        postTitle: postTitle,
      ),
    );
  }

  @override
  State<PostOptionsBottomSheet> createState() => _PostOptionsBottomSheetState();
}

class _PostOptionsBottomSheetState extends State<PostOptionsBottomSheet> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool    _isLoading     = false;
  String? _loadingAction;

  String? get _myUid => _auth.currentUser?.uid;

  void _setLoading(String? action) {
    if (mounted) setState(() { _isLoading = action != null; _loadingAction = action; });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYLAŞ
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _sharePost() async {
    Navigator.pop(context);
    final deepLink = '$_kWebFallback?postId=${widget.postId}';
    final kategoriStr = widget.kategori != null ? '\nKategori: ${widget.kategori}' : '';
    final titleStr    = widget.postTitle != null ? '${widget.postTitle}\n' : '';
    await Share.share(
      '${titleStr}Erzurum Kampüs uygulamasında bu ilana göz at!$kategoriStr\n\n$deepLink',
      subject: widget.postTitle ?? 'Erzurum Kampüs İlanı',
    );
  }

  Future<void> _copyLink() async {
    final deepLink = '$_kWebFallback?postId=${widget.postId}';
    await Clipboard.setData(ClipboardData(text: deepLink));
    if (mounted) {
      Navigator.pop(context);
      _snack('Link panoya kopyalandı!', AppColors.success);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DÜZENLE
  // ══════════════════════════════════════════════════════════════════════════

  void _editPost() {
    Navigator.pop(context);
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => NewPostScreen(editPostId: widget.postId)));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SİL (DÜZELTİLDİ)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deletePost() async {
    // Navigator.pop(context); // ❌ BURADAN SİLİNDİ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(postId: widget.postId),
    );
    if (confirmed != true || !mounted) return;

    _setLoading('delete');
    try {
      final snap = await _db.collection('Posts').doc(widget.postId).get();
      if (snap.exists) {
        await _clearStorage(snap.data()!, 'resimler');
        await _clearStorage(snap.data()!, 'videolar');
        await _clearStorage(snap.data()!, 'video_resim');
      }
      await _db.collection('Posts').doc(widget.postId).delete();
      
      if (mounted) {
        _snack('İlanınız başarıyla silindi.', AppColors.success);
        if (Navigator.canPop(context)) Navigator.pop(context); // ✅ BAŞARILI OLUNCA KAPAT
      }
    } catch (e) {
      if (mounted) _snack('Silme başarısız: $e', AppColors.error);
    } finally {
      _setLoading(null);
    }
  }

  Future<void> _clearStorage(Map<String, dynamic> data, String field) async {
    final urls = data[field];
    if (urls is! List) return;
    for (final url in urls) {
      try {
        // FirebaseStorage.instance.refFromURL(url.toString()).delete();
        print('[PostOptions] Storage sil: $url');
      } catch (_) {}
    }
  }
// ══════════════════════════════════════════════════════════════════════════
  //  ŞİKÂYET (DÜZELTİLDİ)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _reportPost() async {
    // Navigator.pop(context); // ❌ BURADAN SİLİNDİ
    if (_myUid == null) { _snack('Giriş yapmalısınız.', AppColors.error); return; }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportReasonDialog(),
    );
    if (reason == null || !mounted) return;

    _setLoading('report');
    try {
      final existing = await _db.collection('Reports')
          .where('reportedPostId', isEqualTo: widget.postId)
          .where('reporterUserId', isEqualTo: _myUid)
          .limit(1).get();

      if (existing.docs.isNotEmpty) {
        _snack('Bu ilanı zaten şikayet ettiniz.', AppColors.warning);
        if (Navigator.canPop(context)) Navigator.pop(context); // İşlem bitince kapat
        return;
      }
      
      await _db.collection('Reports').add({
        'reportedPostId': widget.postId,
        'reportedUserId': widget.ownerId,
        'reporterUserId': _myUid,
        'kategori':       widget.kategori ?? 'Bilinmiyor',
        'reason':         reason,
        'timestamp':      FieldValue.serverTimestamp(),
        'status':         'Bekliyor',
      });
      
      if (mounted) {
        _snack('Şikayetiniz iletildi. Teşekkürler.', AppColors.accent);
        if (Navigator.canPop(context)) Navigator.pop(context); // ✅ BAŞARILI OLUNCA KAPAT
      }
    } catch (e) {
      if (mounted) _snack('Şikayet iletilemedi: $e', AppColors.error);
    } finally {
      _setLoading(null);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ENGELLE (DÜZELTİLDİ)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _blockUser() async {
    // Navigator.pop(context); // ❌ BURADAN SİLİNDİ
    if (_myUid == null) { _snack('Giriş yapmalısınız.', AppColors.error); return; }
    if (_myUid == widget.ownerId) { _snack('Kendinizi engelleyemezsiniz.', AppColors.error); return; }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _BlockConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    _setLoading('block');
    try {
      await _db.collection('users').doc(_myUid)
          .collection('blockedUsers').doc(widget.ownerId)
          .set({
            'blockedUserId': widget.ownerId,
            'blockedAt':     FieldValue.serverTimestamp(),
            'source':        'post', 
          });
          
      if (mounted) {
        _snack('Kullanıcı engellendi. Artık ilanlarını görmeyeceksiniz.', AppColors.error);
        if (Navigator.canPop(context)) Navigator.pop(context); // ✅ BAŞARILI OLUNCA KAPAT
      }
    } catch (e) {
      if (mounted) _snack('Engelleme başarısız: $e', AppColors.error);
    } finally {
      _setLoading(null);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.more_horiz_rounded, color: AppColors.accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Seçenekler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
                Text(widget.kategori ?? 'İlan', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),

          // İlan sahibi seçenekleri
          if (widget.isOwner) ...[
            _tile(icon: Icons.edit_rounded,   label: 'İlanı Düzenle', sub: 'Bilgileri güncelle',
              iconBg: AppColors.accentSoft, iconColor: AppColors.accent, onTap: _editPost, action: 'edit'),
            _tile(icon: Icons.delete_rounded, label: 'İlanı Sil',     sub: 'Bu işlem geri alınamaz',
              iconBg: AppColors.errorSoft, iconColor: AppColors.error, onTap: _deletePost, action: 'delete', destructive: true),
          ] else ...[
            _tile(icon: Icons.flag_rounded,       label: 'İlanı Şikâyet Et',     sub: 'Uygunsuz içerik bildir',
              iconBg: AppColors.errorSoft, iconColor: AppColors.error, onTap: _reportPost, action: 'report', destructive: true),
            _tile(icon: Icons.person_off_rounded, label: 'Kullanıcıyı Engelle', sub: 'Bir daha görmemek için',
              iconBg: const Color(0xFFFFF7ED), iconColor: AppColors.warning, onTap: _blockUser, action: 'block'),
          ],

          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 20, color: Colors.grey.shade100)),

          _tile(icon: Icons.share_rounded, label: 'Paylaş',        sub: 'Arkadaşlarınla paylaş',
            iconBg: const Color(0xFFEFF6FF), iconColor: const Color(0xFF3B82F6), onTap: _sharePost, action: 'share'),
          _tile(icon: Icons.link_rounded,  label: 'Linki Kopyala', sub: 'Panoya kopyala',
            iconBg: const Color(0xFFF0FDF4), iconColor: AppColors.success, onTap: _copyLink, action: 'copy'),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 20, color: Colors.grey.shade100)),

          _tile(icon: Icons.close_rounded, label: 'Kapat', sub: '',
            iconBg: AppColors.surfaceSecondary, iconColor: AppColors.textMuted,
            onTap: () => Navigator.pop(context), action: 'close'),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required String sub,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
    required String action,
    bool destructive = false,
  }) {
    final loading = _isLoading && _loadingAction == action;
    return InkWell(
      onTap: _isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
            child: loading
                ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: iconColor))
                : Icon(icon, size: 22, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: destructive ? AppColors.error : const Color(0xFF1E1B4B))),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          if (!loading)
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Onay ve Seçim Dialogları
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context) => _ConfirmDialog(
    icon: Icons.delete_rounded,
    iconBg: AppColors.errorSoft,
    iconColor: AppColors.error,
    title: 'İlanı Sil',
    message: 'Bu ilanı silmek istediğinize emin misiniz?\nTüm fotoğraf ve videolar kalıcı olarak silinecektir.',
    confirmLabel: 'Evet, Sil',
    confirmColor: AppColors.error,
  );
}

class _BlockConfirmDialog extends StatelessWidget {
  const _BlockConfirmDialog();

  @override
  Widget build(BuildContext context) => _ConfirmDialog(
    icon: Icons.person_off_rounded,
    iconBg: const Color(0xFFFFF7ED),
    iconColor: AppColors.warning,
    title: 'Kullanıcıyı Engelle',
    message: 'Bu kullanıcıyı engellerseniz ilanlarını ve mesajlarını göremezsiniz. Engeli ayarlardan kaldırabilirsiniz.',
    confirmLabel: 'Engelle',
    confirmColor: AppColors.warning,
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final IconData icon;
  final Color    iconBg, iconColor;
  final String   title, message, confirmLabel;
  final Color    confirmColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 28)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog();

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  String? _selected;

  static const _reasons = [
    (value: 'spam',      label: 'Spam / Reklam',       icon: Icons.mark_email_unread_outlined),
    (value: 'fake',      label: 'Yanıltıcı Bilgi',      icon: Icons.info_outline_rounded),
    (value: 'scam',      label: 'Dolandırıcılık',       icon: Icons.gpp_bad_outlined),
    (value: 'offensive', label: 'Hakaret / Uygunsuz',   icon: Icons.sentiment_very_dissatisfied_outlined),
    (value: 'copyright', label: 'Telif Hakkı İhlali',   icon: Icons.copyright_outlined),
    (value: 'other',     label: 'Diğer',                icon: Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Başlık
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.flag_rounded, color: AppColors.error, size: 22)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Şikâyet Et', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
              Text('Neden şikayet ediyorsunuz?', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
          ]),
          const SizedBox(height: 20),

          // Seçenekler
          ..._reasons.map((r) {
            final sel = _selected == r.value;
            return GestureDetector(
              onTap: () => setState(() => _selected = r.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? AppColors.accentSoft : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? AppColors.accent : const Color(0xFFE2E8F0), width: sel ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(r.icon, size: 18, color: sel ? AppColors.accent : const Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: sel ? AppColors.accent : const Color(0xFF1E1B4B)))),
                  if (sel) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent),
                ]),
              ),
            );
          }),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, null),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Text('İptal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.error,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Şikâyet Et', style: TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      ),
    );
  }
}