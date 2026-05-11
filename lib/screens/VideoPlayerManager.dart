// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerManager — Java'daki PostAdapter.activeVideoAdapter + activePostPosition
// mantığının Dart/Flutter karşılığı.
//
// Aynı anda sadece bir video oynatılır. Yeni bir video başladığında
// onceki duraklatılır. Java'daki:
//   if (activeVideoAdapter != null && activePostPosition != position) {
//     activeVideoAdapter.releaseAllPlayers();
//   }
// ─────────────────────────────────────────────────────────────────────────────

typedef PauseCallback = void Function();

class VideoPlayerManager {
  VideoPlayerManager._();
  static final VideoPlayerManager instance = VideoPlayerManager._();

  PauseCallback? _activePlayerPause;
  String? _activePostId;

  /// Yeni video başlatıldığında çağrılır.
  /// Önceki aktif oynatıcı durdurulur.
  void setActive({
    required String postId,
    required PauseCallback pauseCallback,
  }) {
    if (_activePostId != null &&
        _activePostId != postId &&
        _activePlayerPause != null) {
      _activePlayerPause!(); // Önceki videoyu durdur
    }
    _activePostId = postId;
    _activePlayerPause = pauseCallback;
  }

  /// Video kapatıldığında çağrılır.
  void clearActive(String postId) {
    if (_activePostId == postId) {
      _activePostId = null;
      _activePlayerPause = null;
    }
  }

  /// Tüm oynatıcıları durdur (Java'daki releaseAllPlayers() → feed yenilendiğinde).
  void pauseAll() {
    _activePlayerPause?.call();
    _activePostId = null;
    _activePlayerPause = null;
  }
}