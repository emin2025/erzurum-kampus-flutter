// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// Kendi import'larını aşağıdaki yorumları kaldırarak ekle:
// import 'package:your_app/screens/PostDetailScreen.dart';
// import 'package:your_app/screens/ImageDetailScreen.dart';
// import 'package:your_app/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL: PostTeklif
// ─────────────────────────────────────────────────────────────────────────────

class PostTeklif {
  final String postId;
  final String baslik;
  final String? resimUrl;
  final String? fiyat;
  final String? kategori;

  const PostTeklif({
    required this.postId,
    required this.baslik,
    this.resimUrl,
    this.fiyat,
    this.kategori,
  });

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'baslik': baslik,
        'resimUrl': resimUrl,
        'fiyat': fiyat,
        'kategori': kategori,
      };

  factory PostTeklif.fromMap(Map<String, dynamic> map) => PostTeklif(
        postId: map['postId'] ?? '',
        baslik: map['baslik'] ?? '',
        resimUrl: map['resimUrl'],
        fiyat: map['fiyat'],
        kategori: map['kategori'],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHATSCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.hedefUserId,
    this.kategori,
    this.teklifMesaj,
    this.teklifPostId,
    this.teklifPostBaslik,
    this.teklifPostResim,
    this.teklifPostFiyat,
  });

  final String hedefUserId;
  final String? kategori;
  final String? teklifMesaj;
  final String? teklifPostId;
  final String? teklifPostBaslik;
  final String? teklifPostResim;
  final String? teklifPostFiyat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ── Firebase ──────────────────────────────────────────────────────────────
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final String _currentUserId;
  late final String _chatId;

  // ── UI ────────────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl    = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();
  final FocusNode              _focusNode  = FocusNode();

  // ── setState gerektiren (çok nadir değişen) state ─────────────────────────
  String  _hedefAd           = '';
  String? _hedefProfilUrl;
  bool    _isBlockedByMe     = false;
  bool    _isBlockedByTarget = false;
  bool    _isUploadingImage  = false;

  // ── ValueNotifier'lar — setState olmadan rebuild tetikler ─────────────────
  // Bu sayede kullanıcı yazarken mesaj listesi YENİDEN BUILD OLMAZ.
  final ValueNotifier<bool> _hasText        = ValueNotifier(false);
  final ValueNotifier<bool> _isTypingNotif  = ValueNotifier(false);
  final ValueNotifier<bool> _showScrollDown = ValueNotifier(false);

  // ── İç durum ──────────────────────────────────────────────────────────────
  bool _amITyping        = false; // global değil, instance variable
  bool _initialScrollDone = false;
  int  _lastDocCount      = 0;

  // Seen güncellemelerini build dışında topluca yapmak için:
  final Set<DocumentReference> _pendingSeenRefs = {};
  bool _seenFlushScheduled = false;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription? _myBlockSub;
  StreamSubscription? _targetBlockSub;
  StreamSubscription? _typingSub;
  Timer?              _typingTimer;

  // ── Animasyonlar ──────────────────────────────────────────────────────────
  late final AnimationController _fabAnim;

  // ─────────────────────────────────────────────────────────────────────────
  //  INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    final user = _auth.currentUser;
    if (user == null || widget.hedefUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _currentUserId = user.uid;
    _chatId        = _genChatId(_currentUserId, widget.hedefUserId);

    _loadTargetUser();
    _listenBlockStatus();
    _listenTyping();
    _scrollCtrl.addListener(_onScroll);

    // Yalnızca gönder butonunun durumu (hasText) değişirse rebuild yap
    // Mesaj listesi HİÇ ETKİLENMEZ
    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (_hasText.value != hasText) {
        _hasText.value = hasText;
      }
      _sendTypingIndicator(_msgCtrl.text.isNotEmpty);
    });

    // Teklif mesajı varsa input'a yaz
    if (widget.teklifMesaj != null && widget.teklifMesaj!.isNotEmpty) {
      _msgCtrl.text  = widget.teklifMesaj!;
      _hasText.value = true;
    }

    // Teklif varsa ekran açılınca otomatik gönder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.teklifPostId != null &&
          widget.teklifPostId!.isNotEmpty) {
        _sendMessage(autoSendTeklif: true);
      }
    });
  }

  @override
  void dispose() {
    _myBlockSub?.cancel();
    _targetBlockSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _fabAnim.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _hasText.dispose();
    _isTypingNotif.dispose();
    _showScrollDown.dispose();

    // Yazıyor göstergesini kapat
    _db
        .collection('typing')
        .doc(_chatId)
        .collection('users')
        .doc(_currentUserId)
        .delete()
        .catchError((_) {});
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SCROLL
  // ─────────────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 120;
    // ValueNotifier — setState değil, mesaj listesi etkilenmez
    if (_showScrollDown.value == atBottom) {
      _showScrollDown.value = !atBottom;
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animated) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  // Yeni mesaj gelince veya ilk yükleme olunca scroll yönetimi
  void _handleScrollAfterUpdate(int newCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;

      final pos = _scrollCtrl.position;

      // İlk yükleme: animasyonsuz direkt alta git
      if (!_initialScrollDone && newCount > 0) {
        _initialScrollDone = true;
        _lastDocCount = newCount;
        _scrollCtrl.jumpTo(pos.maxScrollExtent);
        return;
      }

      // Yeni mesaj geldi: sadece alta yakınsak kaydır
      if (newCount > _lastDocCount) {
        _lastDocCount = newCount;
        if (pos.maxScrollExtent - pos.pixels < 200) {
          _scrollCtrl.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SEEN GÜNCELLEMELER (build dışında toplu)
  // ─────────────────────────────────────────────────────────────────────────

  // itemBuilder içinde doğrudan Firestore write yaparsak:
  //   write → snapshot → rebuild → write → ... döngüsü oluşur ve titrer.
  // Bunun yerine referansları toplayıp frame bittikten sonra tek batch'te yaparız.
  void _queueSeen(DocumentReference ref) {
    _pendingSeenRefs.add(ref);
    if (_seenFlushScheduled) return;
    _seenFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seenFlushScheduled = false;
      if (_pendingSeenRefs.isEmpty || !mounted) return;
      final batch = _db.batch();
      for (final r in _pendingSeenRefs) {
        batch.update(r, {'seen': true});
      }
      _pendingSeenRefs.clear();
      batch.commit().catchError((_) {});
      _db
          .collection('users')
          .doc(_currentUserId)
          .collection('inbox')
          .doc(widget.hedefUserId)
          .update({'seen': true}).catchError((_) {});
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  YARDIMCI
  // ─────────────────────────────────────────────────────────────────────────

  String _genChatId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  Future<void> _loadTargetUser() async {
    try {
      final doc = await _db.collection('users').doc(widget.hedefUserId).get();
      if (!doc.exists || !mounted) return;
      final d   = doc.data() as Map<String, dynamic>? ?? {};
      final ad  = d['ad']    as String? ?? '';
      final soy = d['soyad'] as String? ?? '';
      setState(() => _hedefAd = '$ad $soy'.trim());

      try {
        final url = await FirebaseStorage.instance
            .ref('profil_images/${widget.hedefUserId}_.jpg')
            .getDownloadURL();
        if (mounted) setState(() => _hedefProfilUrl = url);
      } catch (_) {}
    } catch (e) {
      print('Hedef kullanıcı yüklenemedi: $e');
    }
  }

  void _listenBlockStatus() {
    _myBlockSub = _db
        .collection('users')
        .doc(_currentUserId)
        .collection('blockedUsers')
        .doc(widget.hedefUserId)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _isBlockedByMe = s.exists);
    });

    _targetBlockSub = _db
        .collection('users')
        .doc(widget.hedefUserId)
        .collection('blockedUsers')
        .doc(_currentUserId)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _isBlockedByTarget = s.exists);
    });
  }

  // ── Yazıyor göstergesi ────────────────────────────────────────────────────

  void _sendTypingIndicator(bool isTyping) {
    if (_amITyping == isTyping) return; // Aynı durum ise Firestore'u yorma
    _amITyping = isTyping;

    _typingTimer?.cancel();
    final ref = _db
        .collection('typing')
        .doc(_chatId)
        .collection('users')
        .doc(_currentUserId);

    if (isTyping) {
      ref.set({'typing': true, 'ts': FieldValue.serverTimestamp()});
      _typingTimer = Timer(const Duration(seconds: 3), () {
        ref.delete().catchError((_) {});
        _amITyping = false;
      });
    } else {
      ref.delete().catchError((_) {});
    }
  }

  void _listenTyping() {
    _typingSub = _db
        .collection('typing')
        .doc(_chatId)
        .collection('users')
        .doc(widget.hedefUserId)
        .snapshots()
        .listen((s) {
      // ValueNotifier — setState değil
      _isTypingNotif.value = s.exists;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MESAJ GÖNDERME
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage({String? imageUrl, bool autoSendTeklif = false}) async {
    if (_isBlockedByMe || _isBlockedByTarget) return;

    final text      = _msgCtrl.text.trim();
    final hasTeklif = widget.teklifPostId != null && widget.teklifPostId!.isNotEmpty;

    if (text.isEmpty && imageUrl == null && !autoSendTeklif) return;

    _msgCtrl.clear();
    _hasText.value = false;
    _sendTypingIndicator(false);

    final ts       = DateTime.now().millisecondsSinceEpoch;
    final isImage  = imageUrl != null;
    final isTeklif = hasTeklif && autoSendTeklif;

    if (isTeklif) {
      final teklif = PostTeklif(
        postId  : widget.teklifPostId!,
        baslik  : widget.teklifPostBaslik ?? 'İlan',
        resimUrl: widget.teklifPostResim,
        fiyat   : widget.teklifPostFiyat,
        kategori: widget.kategori,
      );

      final teklifData = {
        'senderId'   : _currentUserId,
        'receiverId' : widget.hedefUserId,
        'message'    : text.isEmpty ? 'Teklif Verdi' : text,
        'imageUrl'   : null,
        'messageType': 'teklif',
        'postTeklif' : teklif.toMap(),
        'timestamp'  : ts,
        'seen'       : false,
        'messageId'  : _db.collection('chats').doc().id,
        'deletedFor' : <String>[],
      };

      await _db
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(teklifData);
      _updateInbox('📦 Teklif: ${teklif.baslik}', ts);
      return;
    }

    final msgData = {
      'senderId'   : _currentUserId,
      'receiverId' : widget.hedefUserId,
      'message'    : isImage ? '' : text,
      'imageUrl'   : imageUrl,
      'messageType': isImage ? 'image' : 'text',
      'postTeklif' : null,
      'timestamp'  : ts,
      'seen'       : false,
      'messageId'  : _db.collection('chats').doc().id,
      'deletedFor' : <String>[],
    };

    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add(msgData);
    _updateInbox(isImage ? '📷 Resim' : text, ts);
  }

  Future<void> _updateInbox(String lastMsg, int ts) async {
    final batch = _db.batch();
    batch.set(
      _db
          .collection('users')
          .doc(_currentUserId)
          .collection('inbox')
          .doc(widget.hedefUserId),
      {
        'otherUserId': widget.hedefUserId,
        'lastMessage': lastMsg,
        'timestamp'  : ts,
        'seen'       : true,
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db
          .collection('users')
          .doc(widget.hedefUserId)
          .collection('inbox')
          .doc(_currentUserId),
      {
        'otherUserId': _currentUserId,
        'lastMessage': lastMsg,
        'timestamp'  : ts,
        'seen'       : false,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ── Resim yükleme ─────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final ref = FirebaseStorage.instance.ref(
          'chat_images/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await _sendMessage(imageUrl: url);
    } catch (_) {
      _snack('Resim yüklenemedi.');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Mesaj silme ───────────────────────────────────────────────────────────

  Future<void> _deleteMessageForMe(DocumentReference ref) async {
    try {
      await ref.update({
        'deletedFor': FieldValue.arrayUnion([_currentUserId]),
      });
    } catch (_) {
      _snack('Mesaj silinemedi.');
    }
  }

  // ── Engelleme ─────────────────────────────────────────────────────────────

  void _toggleBlock() async {
    if (_isBlockedByMe) {
      await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('blockedUsers')
          .doc(widget.hedefUserId)
          .delete();
      _snack('Engel kaldırıldı.');
    } else {
      await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('blockedUsers')
          .doc(widget.hedefUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});
      _snack('Kullanıcı engellendi.');
    }
  }

  // ── Sohbeti sil ───────────────────────────────────────────────────────────

  void _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title  : const Text('Sohbeti Temizle'),
        content: Text(
            '$_hedefAd ile sohbeti sadece sizin için silmek istiyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final msgs  = await _db
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .get();
      final batch = _db.batch();
      for (final doc in msgs.docs) {
        final List<dynamic> df = doc.data()['deletedFor'] ?? [];
        if (!df.contains(_currentUserId)) {
          batch.update(doc.reference, {
            'deletedFor': FieldValue.arrayUnion([_currentUserId]),
          });
        }
      }
      batch.delete(_db
          .collection('users')
          .doc(_currentUserId)
          .collection('inbox')
          .doc(widget.hedefUserId));
      await batch.commit();
      if (mounted) {
        _snack('Sohbet temizlendi.');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Silme hatası: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content : Text(msg),
        behavior: SnackBarBehavior.floating,
        shape   : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin  : const EdgeInsets.all(16),
      ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ZAMAN FORMATI
  // ─────────────────────────────────────────────────────────────────────────

  String _formatTime(int ts) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (dt.year == now.year) return DateFormat('d MMM HH:mm', 'tr').format(dt);
    return DateFormat('d MMM yy', 'tr').format(dt);
  }

  String _formatDateHeader(int ts) {
    final dt   = DateTime.fromMillisecondsSinceEpoch(ts);
    final now  = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    if (dt.year == now.year) return DateFormat('d MMMM', 'tr').format(dt);
    return DateFormat('d MMMM yyyy', 'tr').format(dt);
  }

  bool _isSameDay(int ts1, int ts2) {
    final a = DateTime.fromMillisecondsSinceEpoch(ts1);
    final b = DateTime.fromMillisecondsSinceEpoch(ts2);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar          : _buildAppBar(),
        body: Column(
          children: [
            // RepaintBoundary: mesaj listesi input bar'ın değişiminden izole edildi
            Expanded(
              child: RepaintBoundary(child: _buildMessageList()),
            ),
            // Yazıyor balonu — ValueListenableBuilder, setState yok
            ValueListenableBuilder<bool>(
              valueListenable: _isTypingNotif,
              builder: (_, isTyping, __) =>
                  isTyping ? _buildTypingBubble() : const SizedBox.shrink(),
            ),
            _buildInputBar(),
          ],
        ),
        // Aşağı kaydır butonu — ValueListenableBuilder, setState yok
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _showScrollDown,
          builder: (_, show, __) => show
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: FloatingActionButton.small(
                    onPressed      : _scrollToBottom,
                    backgroundColor: const Color(0xFF15C0A4),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation          : 0,
      backgroundColor    : Colors.white,
      systemOverlayStyle : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon     : const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color    : const Color(0xFF1E1B4B),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {/* TODO: Profile git */},
        child: Row(
          children: [
            _buildAvatar(radius: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hedefAd.isNotEmpty ? _hedefAd : 'Kullanıcı',
                    style: const TextStyle(
                        fontSize  : 15,
                        fontWeight: FontWeight.w700,
                        color     : Color(0xFF1E1B4B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Typing alt başlığı — ValueListenableBuilder ile izole
                  ValueListenableBuilder<bool>(
                    valueListenable: _isTypingNotif,
                    builder: (_, isTyping, __) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isTyping
                          ? const Text(
                              'yazıyor...',
                              key  : ValueKey('typing'),
                              style: TextStyle(
                                  fontSize  : 12,
                                  color     : Color(0xFF15C0A4),
                                  fontWeight: FontWeight.w500),
                            )
                          : const Text(
                              'çevrimiçi',
                              key  : ValueKey('online'),
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<int>(
          icon      : const Icon(Icons.more_vert_rounded, color: Color(0xFF1E1B4B)),
          shape     : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            if (v == 1) {/* TODO: Profile git */}
            if (v == 2) {/* TODO: Şikayet et */}
            if (v == 3) _deleteChat();
            if (v == 4) _toggleBlock();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 1, child: Text('👤  Profile Git')),
            const PopupMenuItem(value: 2, child: Text('🚫  Şikayet Et')),
            PopupMenuItem(
                value: 4,
                child: Text(_isBlockedByMe ? '✅  Engeli Kaldır' : '⛔  Engelle')),
            const PopupMenuItem(
                value: 3,
                child: Text('🗑️  Sohbeti Sil',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatar({double radius = 22}) {
    if (_hedefProfilUrl != null) {
      return CircleAvatar(
        radius         : radius,
        backgroundImage: CachedNetworkImageProvider(_hedefProfilUrl!),
        backgroundColor: const Color(0xFFE0FDF4),
      );
    }
    return CircleAvatar(
      radius         : radius,
      backgroundColor: const Color(0xFFE0FDF4),
      child: Icon(Icons.person_rounded,
          color: const Color(0xFF15C0A4), size: radius),
    );
  }

  // ── Mesaj listesi ─────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
              child: Text('Mesajlar yüklenemedi.',
                  style: TextStyle(color: Color(0xFF94A3B8))));
        }

        // İlk yükleme sırasında liste boşsa spinner göster
        if (snap.connectionState == ConnectionState.waiting &&
            !_initialScrollDone) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF15C0A4), strokeWidth: 2));
        }

        final all     = snap.data?.docs ?? [];
        final visible = all.where((doc) {
          final d  = doc.data() as Map<String, dynamic>;
          final df = d['deletedFor'] as List<dynamic>? ?? [];
          return !df.contains(_currentUserId);
        }).toList();

        // Scroll yönetimi (frame bittikten sonra)
        _handleScrollAfterUpdate(visible.length);

        if (visible.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Henüz mesaj yok\nİlk mesajı sen gönder!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color   : Colors.grey[400],
                      fontSize: 15,
                      height  : 1.5),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller : _scrollCtrl,
          padding    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          cacheExtent: 500, // Kaydırma sırasında daha az rebuild
          itemCount  : visible.length,
          itemBuilder: (ctx, i) {
            final doc  = visible[i];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _currentUserId;
            final ts   = data['timestamp'] as int? ?? 0;

            final showDateHeader = i == 0 ||
                !_isSameDay(
                    ts,
                    (visible[i - 1].data()
                        as Map<String, dynamic>)['timestamp'] as int? ?? 0);

            // ❗ Build aşamasında Firestore write YAPMA
            // Topla, frame bittikten sonra tek seferde batch gönder
            if (!isMe && data['seen'] == false) {
              _queueSeen(doc.reference);
            }

            return Column(
              // key eklemek Flutter'ın listeyi doğru reconcile etmesini sağlar
              // Silme/ekleme sırasında titreme bu sayede önlenir
              key     : ValueKey(doc.id),
              children: [
                if (showDateHeader) _buildDateHeader(_formatDateHeader(ts)),
                _buildBubble(doc, data, isMe, ts),
              ],
            );
          },
        );
      },
    );
  }

  // ── Tarih başlığı ─────────────────────────────────────────────────────────

  Widget _buildDateHeader(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color       : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize  : 11,
                      fontWeight: FontWeight.w600,
                      color     : Color(0xFF64748B))),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  // ── Mesaj balonu ──────────────────────────────────────────────────────────

  Widget _buildBubble(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isMe,
    int ts,
  ) {
    final type     = data['messageType'] as String? ?? 'text';
    final isTeklif = type == 'teklif';
    final isImage  = type == 'image';
    final seen     = data['seen'] as bool? ?? false;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(doc),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 4,
            left  : isMe ? 56 : 0,
            right : isMe ? 0 : 56,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isTeklif)
                _buildTeklifCard(data, isMe)
              else
                _buildNormalBubble(data, isMe, isImage),
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTime(ts),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        seen ? Icons.done_all_rounded : Icons.done_rounded,
                        size : 13,
                        color: seen
                            ? const Color(0xFF15C0A4)
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Normal metin / resim balonu ───────────────────────────────────────────

  Widget _buildNormalBubble(
      Map<String, dynamic> data, bool isMe, bool isImage) {
    final imageUrl = data['imageUrl'] as String?;
    final message  = data['message']  as String? ?? '';

    return Container(
      padding: isImage
          ? const EdgeInsets.all(3)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color       : isMe ? const Color(0xFF15C0A4) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft    : const Radius.circular(18),
          topRight   : const Radius.circular(18),
          bottomLeft : Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
              color    : Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset   : const Offset(0, 2)),
        ],
      ),
      child: isImage && imageUrl != null
          ? _buildImageMessage(imageUrl)
          : Text(message,
              style: TextStyle(
                  color   : isMe ? Colors.white : const Color(0xFF1E1B4B),
                  fontSize: 14.5,
                  height  : 1.4)),
    );
  }

  // ── Resim mesajı ──────────────────────────────────────────────────────────

  Widget _buildImageMessage(String url) {
    return GestureDetector(
      onTap: () {
        // TODO: ImageDetailScreen'e aç
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => ImageDetailScreen(imageUrls: [url], initialIndex: 0),
        // ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl   : url,
          width      : 220,
          height     : 280,
          fit        : BoxFit.cover,
          placeholder: (_, __) => Container(
            width : 220,
            height: 280,
            color : const Color(0xFFE2E8F0),
            child : const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF15C0A4), strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width : 220,
            height: 280,
            color : const Color(0xFFE2E8F0),
            child : const Icon(Icons.broken_image_outlined,
                color: Color(0xFF94A3B8), size: 40),
          ),
        ),
      ),
    );
  }

  // ── Teklif kartı ──────────────────────────────────────────────────────────

  Widget _buildTeklifCard(Map<String, dynamic> data, bool isMe) {
    final teklifMap = data['postTeklif'] as Map<String, dynamic>?;
    if (teklifMap == null) return const SizedBox.shrink();

    final teklif = PostTeklif.fromMap(teklifMap);
    final mesaj  = data['message'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        // TODO: PostDetailScreen'e git
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => PostDetailScreen(postId: teklif.postId, currentUserId: _currentUserId),
        // ));
      },
      child: Container(
        width: 270,
        decoration: BoxDecoration(
          color       : isMe ? const Color(0xFF0D9488) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft    : const Radius.circular(18),
            topRight   : const Radius.circular(18),
            bottomLeft : Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
                color    : Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset   : const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft    : const Radius.circular(18),
            topRight   : const Radius.circular(18),
            bottomLeft : Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── İlan resmi ──
              if (teklif.resimUrl != null && teklif.resimUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl   : teklif.resimUrl!,
                  height     : 140,
                  width      : double.infinity,
                  fit        : BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 140,
                    color : isMe
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFF1F5F9),
                    child : const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF15C0A4), strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 100,
                    color : isMe
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFF1F5F9),
                    child : Icon(Icons.image_not_supported_outlined,
                        color: isMe ? Colors.white54 : const Color(0xFF94A3B8),
                        size : 36),
                  ),
                )
              else
                Container(
                  height: 80,
                  color : isMe
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFF1F5F9),
                  child : Icon(Icons.storefront_outlined,
                      color: isMe ? Colors.white70 : const Color(0xFF15C0A4),
                      size : 36),
                ),

              // ── İlan bilgisi ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.15)
                            : const Color(0xFFE0FDF4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('📦 Teklif',
                          style: TextStyle(
                              fontSize     : 10,
                              fontWeight   : FontWeight.w700,
                              color        : isMe
                                  ? Colors.white
                                  : const Color(0xFF15C0A4),
                              letterSpacing: 0.3)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      teklif.baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize  : 13,
                          fontWeight: FontWeight.w700,
                          color     : isMe ? Colors.white : const Color(0xFF1E1B4B),
                          height    : 1.3),
                    ),
                    if (teklif.fiyat != null && teklif.fiyat!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        teklif.fiyat!.startsWith('₺')
                            ? teklif.fiyat!
                            : '${teklif.fiyat} ₺',
                        style: TextStyle(
                            fontSize  : 15,
                            fontWeight: FontWeight.w800,
                            color     : isMe
                                ? Colors.white
                                : const Color(0xFF15C0A4)),
                      ),
                    ],
                    if (mesaj.isNotEmpty && mesaj != 'Teklif Verdi') ...[
                      Divider(
                          height: 16,
                          color : isMe
                              ? Colors.white30
                              : const Color(0xFFE2E8F0)),
                      Text(mesaj,
                          style: TextStyle(
                              fontSize: 13,
                              color   : isMe
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF475569),
                              height  : 1.4)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size : 12,
                            color: isMe
                                ? Colors.white70
                                : const Color(0xFF15C0A4)),
                        const SizedBox(width: 4),
                        Text('İlana Git',
                            style: TextStyle(
                                fontSize  : 11,
                                fontWeight: FontWeight.w600,
                                color     : isMe
                                    ? Colors.white70
                                    : const Color(0xFF15C0A4))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Yazıyor balonu ────────────────────────────────────────────────────────

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 6, top: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color       : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft    : Radius.circular(18),
              topRight   : Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft : Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                  color    : Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset   : const Offset(0, 2)),
            ],
          ),
          child: const _TypingDots(),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final isBlocked = _isBlockedByMe || _isBlockedByTarget;
    return Container(
      decoration: BoxDecoration(
        color    : Colors.white,
        boxShadow: [
          BoxShadow(
              color    : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset   : const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top  : false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child  : isBlocked ? _buildBlockedBar() : _buildActiveBar(),
        ),
      ),
    );
  }

  Widget _buildBlockedBar() {
    return Container(
      width     : double.infinity,
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        _isBlockedByMe
            ? '⛔  Bu kullanıcıyı engellediniz.'
            : '🚫  Bu kullanıcı sizi engelledi.',
        textAlign: TextAlign.center,
        style: const TextStyle(
            color     : Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize  : 13),
      ),
    );
  }

  Widget _buildActiveBar() {
    return Row(
      children: [
        // ── Resim butonu ──
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickImage,
          child: AnimatedContainer(
            duration  : const Duration(milliseconds: 150),
            width     : 42,
            height    : 42,
            decoration: BoxDecoration(
              color       : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _isUploadingImage
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child  : CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF15C0A4)),
                  )
                : const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF64748B), size: 22),
          ),
        ),
        const SizedBox(width: 8),

        // ── Text field ──
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color       : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller     : _msgCtrl,
              focusNode      : _focusNode,
              maxLines       : null,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                  fontSize: 14.5, color: Color(0xFF1E1B4B)),
              decoration: const InputDecoration(
                hintText      : 'Mesajınızı yazın...',
                hintStyle     : TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 14.5),
                border        : InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Gönder butonu — ValueListenableBuilder ile izole ──
        // Bu sayede her harf yazıldığında SADECE bu buton rebuild olur.
        // Mesaj listesi, AppBar veya diğer hiçbir widget etkilenmez.
        ValueListenableBuilder<bool>(
          valueListenable: _hasText,
          builder: (_, hasText, __) => GestureDetector(
            onTap: hasText ? _sendMessage : null,
            child: AnimatedContainer(
              duration  : const Duration(milliseconds: 150),
              width     : 44,
              height    : 44,
              decoration: BoxDecoration(
                gradient: hasText
                    ? const LinearGradient(
                        colors: [Color(0xFF15C0A4), Color(0xFF0EA5E9)],
                        begin : Alignment.topLeft,
                        end   : Alignment.bottomRight,
                      )
                    : null,
                color       : hasText ? null : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
                boxShadow: hasText
                    ? [
                        BoxShadow(
                            color    : const Color(0xFF15C0A4).withOpacity(0.4),
                            blurRadius: 10,
                            offset   : const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: hasText ? Colors.white : const Color(0xFF94A3B8),
                size : 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mesaj seçenekleri (uzun basış) ────────────────────────────────────────

  void _showMessageOptions(QueryDocumentSnapshot doc) {
    final data    = doc.data() as Map<String, dynamic>;
    final message = data['message'] as String? ?? '';

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context         : context,
      backgroundColor : Colors.transparent,
      builder         : (_) => Container(
        margin    : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin    : const EdgeInsets.only(top: 12, bottom: 16),
              width     : 40,
              height    : 4,
              decoration: BoxDecoration(
                color       : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  message,
                  maxLines : 2,
                  overflow : TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
            const Divider(height: 24),
            if (message.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF1E1B4B)),
                title  : const Text('Kopyala'),
                onTap  : () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  _snack('Kopyalandı.');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title  : const Text('Benim İçin Sil',
                  style: TextStyle(color: Colors.red)),
              onTap  : () {
                Navigator.pop(context);
                _deleteMessageForMe(doc.reference);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  YAZMA ANİMASYONU (üç nokta)
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync   : this,
        duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anims = List.generate(3, (i) {
      final start = i * 0.2;
      return Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(
        parent: _ctrl,
        curve : Interval(start, start + 0.4, curve: Curves.easeInOut),
      ));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder  : (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children    : List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
            child  : Transform.translate(
              offset: Offset(0, _anims[i].value),
              child : Container(
                width     : 8,
                height    : 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF94A3B8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}