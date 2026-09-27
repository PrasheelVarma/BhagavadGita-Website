import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Represents the current playback state of the Bhagavad Gita audio.
enum AudioPlaybackState {
  loading,
  playing,
  paused,
  completed,
  error,
}

/// Central controller for the single-track audio player.
///
/// Responsibilities:
/// - Load the bundled audio asset.
/// - Play, pause, seek and restart.
/// - Expose playback position and duration.
/// - Track playback state.
/// - Handle completion and errors.
/// - Own and dispose the underlying AudioPlayer.
class AudioPlayerController extends ChangeNotifier {
  AudioPlayerController();

  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlaybackState _state = AudioPlaybackState.loading;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String? _audioAssetPath;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isDisposed = false;
  bool _operationInProgress = false;

  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<String>? _errorSubscription;

  AudioPlaybackState get state => _state;
  Duration get duration => _duration;
  Duration get position => _position;

  bool get isLoading => _state == AudioPlaybackState.loading;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isPaused => _state == AudioPlaybackState.paused;
  bool get isCompleted => _state == AudioPlaybackState.completed;
  bool get hasError => _state == AudioPlaybackState.error;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _operationInProgress;

  String? get audioAssetPath => _audioAssetPath;

  /// Initializes the bundled audio asset.
  ///
  /// Calling initialize repeatedly with the same asset is safe.
  /// If initialization previously failed, it can be retried.
  Future<void> initialize(String audioAssetPath) async {
    if (_isDisposed) {
      throw StateError('AudioPlayerController has been disposed.');
    }

    if (_isInitialized && _audioAssetPath == audioAssetPath) {
      return;
    }

    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _setState(AudioPlaybackState.loading);

    try {
      await _detachListeners();

      _audioAssetPath = audioAssetPath;

      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      _attachListeners();

      await _audioPlayer.setSource(
        AssetSource(audioAssetPath),
      );

      if (_isDisposed) {
        return;
      }

      _isInitialized = true;
      _position = Duration.zero;

      _setState(AudioPlaybackState.paused);
    } catch (error, stackTrace) {
      _isInitialized = false;
      _audioAssetPath = null;
      _duration = Duration.zero;
      _position = Duration.zero;

      if (!_isDisposed) {
        _setState(AudioPlaybackState.error);
      }

      debugPrint(
        'AudioPlayerController: initialization failed: $error',
      );
      debugPrint('$stackTrace');

      throw AudioInitializationException(
        'Failed to initialize audio.',
        originalError: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// Starts or resumes playback.
  ///
  /// If the track has completed, playback starts again from the beginning.
  Future<void> play() async {
    if (!_canOperate || _operationInProgress) {
      return;
    }

    if (!_isInitialized) {
      return;
    }

    if (isPlaying) {
      return;
    }

    _operationInProgress = true;

    try {
      if (isCompleted) {
        await _audioPlayer.seek(Duration.zero);

        if (_isDisposed) {
          return;
        }

        _position = Duration.zero;
      }

      await _audioPlayer.resume();

      if (_isDisposed) {
        return;
      }

      _setState(AudioPlaybackState.playing);
    } catch (error, stackTrace) {
      _handleOperationError(
        'play',
        error,
        stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (!_canOperate || _operationInProgress) {
      return;
    }

    if (!_isInitialized || !isPlaying) {
      return;
    }

    _operationInProgress = true;

    try {
      await _audioPlayer.pause();

      if (_isDisposed) {
        return;
      }

      _setState(AudioPlaybackState.paused);
    } catch (error, stackTrace) {
      _handleOperationError(
        'pause',
        error,
        stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seeks to the requested position.
  ///
  /// The requested value is automatically clamped between zero
  /// and the known track duration.
  Future<void> seek(Duration requestedPosition) async {
    if (!_canOperate || _operationInProgress) {
      return;
    }

    if (!_isInitialized) {
      return;
    }

    final target = _clampPosition(requestedPosition);

    _operationInProgress = true;

    try {
      await _audioPlayer.seek(target);

      if (_isDisposed) {
        return;
      }

      _position = target;

      // Seeking away from the end means the track is no longer completed.
      if (isCompleted && target < _duration) {
        _setState(AudioPlaybackState.paused);
      } else {
        notifyListeners();
      }
    } catch (error, stackTrace) {
      _handleOperationError(
        'seek',
        error,
        stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  /// Restarts the track from the beginning and starts playback.
  Future<void> restart() async {
    if (!_canOperate || _operationInProgress) {
      return;
    }

    if (!_isInitialized) {
      return;
    }

    _operationInProgress = true;

    try {
      await _audioPlayer.seek(Duration.zero);

      if (_isDisposed) {
        return;
      }

      _position = Duration.zero;

      await _audioPlayer.resume();

      if (_isDisposed) {
        return;
      }

      _setState(AudioPlaybackState.playing);
    } catch (error, stackTrace) {
      _handleOperationError(
        'restart',
        error,
        stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  /// Stops playback and resets the position.
  Future<void> stop() async {
    if (!_canOperate || _operationInProgress) {
      return;
    }

    if (!_isInitialized) {
      return;
    }

    _operationInProgress = true;

    try {
      await _audioPlayer.stop();

      if (_isDisposed) {
        return;
      }

      _position = Duration.zero;
      _setState(AudioPlaybackState.paused);
    } catch (error, stackTrace) {
      _handleOperationError(
        'stop',
        error,
        stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  void _attachListeners() {
    _durationSubscription =
        _audioPlayer.onDurationChanged.listen((duration) {
      if (_isDisposed) {
        return;
      }

      _duration = duration;

      if (_position > duration) {
        _position = duration;
      }

      notifyListeners();
    });

    _positionSubscription =
        _audioPlayer.onPositionChanged.listen((position) {
      if (_isDisposed) {
        return;
      }

      _position = _clampPosition(position);
      notifyListeners();
    });

    _completeSubscription =
        _audioPlayer.onPlayerComplete.listen((_) {
      if (_isDisposed) {
        return;
      }

      _position = _duration;
      _setState(AudioPlaybackState.completed);
    });

    _errorSubscription =
        _audioPlayer.onPlayerError.listen((message) {
      if (_isDisposed) {
        return;
      }

      debugPrint(
        'AudioPlayerController: player error: $message',
      );

      _setState(AudioPlaybackState.error);
    });
  }

  Future<void> _detachListeners() async {
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _completeSubscription?.cancel();
    await _errorSubscription?.cancel();

    _durationSubscription = null;
    _positionSubscription = null;
    _completeSubscription = null;
    _errorSubscription = null;
  }

  Duration _clampPosition(Duration value) {
    if (value < Duration.zero) {
      return Duration.zero;
    }

    if (_duration > Duration.zero && value > _duration) {
      return _duration;
    }

    return value;
  }

  bool get _canOperate => !_isDisposed;

  void _setState(AudioPlaybackState state) {
    if (_isDisposed) {
      return;
    }

    _state = state;
    notifyListeners();
  }

  void _handleOperationError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_isDisposed) {
      return;
    }

    debugPrint(
      'AudioPlayerController: $operation failed: $error',
    );
    debugPrint('$stackTrace');

    _setState(AudioPlaybackState.error);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _errorSubscription?.cancel();

    _durationSubscription = null;
    _positionSubscription = null;
    _completeSubscription = null;
    _errorSubscription = null;

    unawaited(_audioPlayer.stop());
    unawaited(_audioPlayer.dispose());

    super.dispose();
  }
}

/// Thrown when the audio player cannot initialize its audio source.
class AudioInitializationException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AudioInitializationException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (originalError == null) {
      return 'AudioInitializationException: $message';
    }

    return 'AudioInitializationException: $message '
        'Original error: $originalError';
  }
}