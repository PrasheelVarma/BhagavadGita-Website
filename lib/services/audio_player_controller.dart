import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Playback states for the audio player.
enum AudioPlaybackState {
  loading,
  playing,
  paused,
  completed,
  error,
}

/// Central audio controller for managing playback of a single audio track.
///
/// This class provides a production-ready interface for:
/// - Loading audio from bundled assets
/// - Playing, pausing, and seeking
/// - Tracking playback state and position
/// - Handling completion and replay
/// - Managing resources safely
///
/// The controller maintains a single [AudioPlayer] instance and properly
/// manages its lifecycle, including listener cleanup on disposal.
class AudioPlayerController with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Playback state
  AudioPlaybackState _state = AudioPlaybackState.loading;
  
  // Track metadata
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // Track the initialized audio asset path
  String? _audioAssetPath;
  
  // Track if controller has been disposed
  bool _isDisposed = false;
  
  // StreamSubscription for proper cleanup
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _completeSubscription;
  StreamSubscription? _errorSubscription;

  // Getters for public access
  AudioPlaybackState get state => _state;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isPaused => _state == AudioPlaybackState.paused;
  bool get isCompleted => _state == AudioPlaybackState.completed;
  bool get isLoading => _state == AudioPlaybackState.loading;
  bool get hasError => _state == AudioPlaybackState.error;
  bool get isInitialized => _audioAssetPath != null;
  String? get audioAssetPath => _audioAssetPath;

  // AudioPlayer for direct access when needed
  AudioPlayer get player => _audioPlayer;

  /// Initialize the controller with an audio asset.
  ///
  /// This method:
  /// - Sets the audio source
  /// - Loads the duration
  /// - Prepares the player for playback
  ///
  /// [audioAssetPath] is the path to the bundled asset (e.g., 'audio.m4a').
  ///
  /// Throws an [AudioInitializationException] if initialization fails.
  Future<void> initialize(String audioAssetPath) async {
    // Prevent re-initialization with a different path
    if (_isDisposed) {
      throw AudioInitializationException('Cannot initialize: controller is disposed');
    }
    if (_audioAssetPath != null && _audioAssetPath != audioAssetPath) {
      throw AudioInitializationException('Cannot initialize: already initialized with a different asset');
    }
    
    if (_audioAssetPath != null) {
      // Already initialized with the same asset
      return;
    }

    _audioAssetPath = audioAssetPath;
    _state = AudioPlaybackState.loading;
    notifyListeners();

    try {
      // Set the source
      await _audioPlayer.setSource(AssetSource(audioAssetPath));
      
      // Attach listeners after source is set
      _attachListeners();
      
      // The duration will be set via the onDurationChanged callback
      // Wait a brief moment for duration to be populated
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!_isDisposed) {
        _state = AudioPlaybackState.paused;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      if (!_isDisposed) {
        _state = AudioPlaybackState.error;
        _errorSubscription?.cancel();
        _errorSubscription = null;
        notifyListeners();
        
        debugPrint('AudioPlayerController: Initialization failed - $e');
        debugPrint('Stack trace: $stackTrace');
        
        throw AudioInitializationException(
          'Failed to initialize audio: $e',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Start or resume playback.
  ///
  /// If the audio has been completed, this will restart from the beginning.
  /// If already playing, this is a no-op.
  Future<void> play() async {
    if (_isDisposed) {
      return;
    }
    
    if (_state == AudioPlaybackState.playing) {
      return;
    }

    try {
      // If completed, restart from beginning
      if (_state == AudioPlaybackState.completed) {
        await _audioPlayer.seek(Duration.zero);
        _position = Duration.zero;
        notifyListeners();
      }
      
      await _audioPlayer.resume();
      
      if (!_isDisposed) {
        _state = AudioPlaybackState.playing;
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _state = AudioPlaybackState.error;
        notifyListeners();
        debugPrint('AudioPlayerController: Play failed - $e');
      }
    }
  }

  /// Pause playback.
  ///
  /// If already paused or not started, this is a no-op.
  Future<void> pause() async {
    if (_isDisposed) {
      return;
    }
    
    if (_state == AudioPlaybackState.paused || 
        _state == AudioPlaybackState.loading || 
        _state == AudioPlaybackState.completed) {
      return;
    }

    try {
      await _audioPlayer.pause();
      
      if (!_isDisposed) {
        _state = AudioPlaybackState.paused;
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _state = AudioPlaybackState.error;
        notifyListeners();
        debugPrint('AudioPlayerController: Pause failed - $e');
      }
    }
  }

  /// Toggle between play and pause.
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to a specific position in the audio track.
  ///
  /// [position] is the target position in the track.
  Future<void> seek(Duration position) async {
    if (_isDisposed) {
      return;
    }
    
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    if (position > _duration) {
      position = _duration;
    }

    try {
      await _audioPlayer.seek(position);
      
      if (!_isDisposed) {
        _position = position;
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _state = AudioPlaybackState.error;
        notifyListeners();
        debugPrint('AudioPlayerController: Seek failed - $e');
      }
    }
  }

  /// Restart playback from the beginning.
  Future<void> restart() async {
    await seek(Duration.zero);
    await play();
  }

  /// Stop playback and reset position.
  ///
  /// This pauses playback and resets position to zero.
  Future<void> stop() async {
    if (_isDisposed) {
      return;
    }
    
    try {
      await _audioPlayer.stop();
      
      if (!_isDisposed) {
        _state = AudioPlaybackState.paused;
        _position = Duration.zero;
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _state = AudioPlaybackState.error;
        notifyListeners();
        debugPrint('AudioPlayerController: Stop failed - $e');
      }
    }
  }

  /// Attach event listeners from the audio player.
  void _attachListeners() {
    // Duration changed - set the track duration
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!_isDisposed && duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });

    // Position changed - update current position
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!_isDisposed && position != null) {
        // Cap position at duration to prevent overshoot
        if (position >= _duration && _duration > Duration.zero) {
          // Handle completion
          _handleComplete();
        } else {
          _position = position;
          notifyListeners();
        }
      }
    });

    // Player completed - track finished playing
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!_isDisposed) {
        _handleComplete();
      }
    });

    // Error handling
    _errorSubscription = _audioPlayer.onError.listen((event) {
      if (!_isDisposed) {
        debugPrint('AudioPlayerController: Audio player error - $event');
        _state = AudioPlaybackState.error;
        notifyListeners();
      }
    });
  }

  /// Handle track completion state.
  void _handleComplete() {
    _state = AudioPlaybackState.completed;
    _position = _duration;
    notifyListeners();
  }

  /// Remove all event listeners to prevent memory leaks.
  void _detachListeners() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _errorSubscription?.cancel();

    _durationSubscription = null;
    _positionSubscription = null;
    _completeSubscription = null;
    _errorSubscription = null;
  }

  /// Dispose all resources.
  ///
  /// This method:
  /// - Stops playback
  /// - Detaches all listeners
  /// - Disposes the audio player
  ///
  /// After disposal, the controller cannot be used and will throw
  /// [AudioInitializationException] on any method calls.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    
    _isDisposed = true;
    
    // Stop playback first
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // Ignore errors during disposal
      debugPrint('AudioPlayerController: Error stopping during dispose - $e');
    }

    // Detach listeners to prevent callbacks after disposal
    _detachListeners();

    // Dispose the audio player
    await _audioPlayer.dispose();
    
    debugPrint('AudioPlayerController: Disposed successfully');
  }

  @override
  void notifyListeners() {
    // Prevent notifications after disposal
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}

/// Exception thrown when audio initialization fails.
class AudioInitializationException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  AudioInitializationException(this.message, {this.originalError, this.stackTrace});

  @override
  String toString() {
    if (originalError != null && stackTrace != null) {
      return 'AudioInitializationException: $message\nOriginal error: $originalError\n$stackTrace';
    }
    return 'AudioInitializationException: $message';
  }
}
