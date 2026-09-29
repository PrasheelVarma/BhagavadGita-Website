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
  bool get canRestart => isCompleted;

  String? get audioAssetPath => _audioAssetPath;

  /// Resets the controller to a clean state.
  ///
  /// This clears error state and resets internal flags
  /// without disposing the controller. The audio asset path
  /// is preserved so recovery can reinitialize with the same asset.
  void reset() {
    _isInitialized = false;
    // Preserve _audioAssetPath for recovery
    _duration = Duration.zero;
    _position = Duration.zero;
    _operationInProgress = false;
    _state = AudioPlaybackState.loading;
  }

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

    // If already initializing, wait for completion
    if (_isInitializing) {
      return;
    }

    // If in error state, reset before retrying
    if (hasError && _audioAssetPath == audioAssetPath) {
      reset();
    }

    _isInitializing = true;
    _operationInProgress = true;
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
      _operationInProgress = false;

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
      _operationInProgress = false;
    }
  }

  /// Starts or resumes playback.
  ///
  /// If the track has completed, playback starts again from the beginning.
  Future<void> play() async {
    if (!_canOperate) {
      return;
    }

    // Don't start if not initialized or in error state
    if (!_isInitialized || hasError) {
      return;
    }

    // If already playing, nothing to do
    if (isPlaying) {
      return;
    }

    // If loading, wait for initialization
    if (isLoading) {
      return;
    }

    _operationInProgress = true;

    try {
      // If completed, restart from beginning
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
      _handleOperationError('play', error, stackTrace);
    } finally {
      _operationInProgress = false;
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (!_canOperate) {
      return;
    }

    // If not initialized, in error state, or not playing, nothing to do
    if (!_isInitialized || hasError || !isPlaying) {
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
      _handleOperationError('pause', error, stackTrace);
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
    if (!_canOperate) {
      return;
    }

    // Don't seek if not initialized or in error state
    if (!_isInitialized || hasError) {
      return;
    }

    // Don't seek while loading
    if (isLoading) {
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
      _handleOperationError('seek', error, stackTrace);
    } finally {
      _operationInProgress = false;
    }
  }

  /// Restarts the track from the beginning and starts playback.
  ///
  /// This is useful when the track has completed and the user wants to replay.
  Future<void> restart() async {
    if (!_canOperate) {
      return;
    }

    // Don't restart if not initialized, in error state, or not completed
    if (!_isInitialized || hasError || !isCompleted) {
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
      _handleOperationError('restart', error, stackTrace);
    } finally {
      _operationInProgress = false;
    }
  }

  /// Stops playback and resets the position.
  Future<void> stop() async {
    if (!_canOperate) {
      return;
    }

    // Don't stop if not initialized or in error state
    if (!_isInitialized || hasError) {
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
      _handleOperationError('stop', error, stackTrace);
    } finally {
      _operationInProgress = false;
    }
  }

  /// Attempts to recover from an error state by reinitializing
  /// the previously configured audio asset.
  ///
  /// Returns true if recovery was started successfully.
  /// The recovery process is asynchronous - the controller will
  /// transition through loading state during recovery.
  Future<bool> tryRecover() async {
    if (!_isDisposed && hasError && _audioAssetPath != null) {
      reset();
      try {
        await initialize(_audioAssetPath!);
        return true;
      } on AudioInitializationException {
        // Initialization failed, stay in error state
        return false;
      } catch (e) {
        // Unexpected error, stay in error state
        return false;
      }
    }
    return false;
  }

  void _attachListeners() {
    _durationSubscription =
        _audioPlayer.onDurationChanged.listen((duration) {
      if (_isDisposed) {
        return;
      }

      _duration = duration;

      // Clamp current position to new duration
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

      _operationInProgress = false;
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

    _operationInProgress = false;
    _setState(AudioPlaybackState.error);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _operationInProgress = false;

    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _errorSubscription?.cancel();

    _durationSubscription = null;
    _positionSubscription = null;
    _completeSubscription = null;
    _errorSubscription = null;

    // Await the stop to ensure clean shutdown
    unawaited(_audioPlayer.stop().then((_) {
      return _audioPlayer.dispose();
    }).onError((error, stackTrace) {
      debugPrint('AudioPlayerController: error during dispose: $error');
    }));

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
