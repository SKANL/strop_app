import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:uuid/uuid.dart';

class AudioRecordingWidget extends StatefulWidget {
  const AudioRecordingWidget({
    required this.onRecordingComplete,
    super.key,
  });

  final ValueChanged<String> onRecordingComplete;

  @override
  State<AudioRecordingWidget> createState() => _AudioRecordingWidgetState();
}

class _AudioRecordingWidgetState extends State<AudioRecordingWidget> {
  late final record.AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _path;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = record.AudioRecorder();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audioRecorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/${const Uuid().v4()}.m4a';

        await _audioRecorder.start(const record.RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _path = null;
          _duration = Duration.zero;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _duration += const Duration(seconds: 1);
          });
        });
      }
    } on Exception catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();

      setState(() {
        _isRecording = false;
        _path = path;
      });

      if (path != null) {
        widget.onRecordingComplete(path);
        unawaited(_simulateTranscription());
      }
    } on Exception catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _play() async {
    try {
      if (_path != null) {
        await _audioPlayer.play(DeviceFileSource(_path!));
        setState(() {
          _isPlaying = true;
        });
      }
    } on Exception catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } on Exception catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Future<void> _delete() async {
    try {
      await _stop();
      if (_path != null) {
        final file = File(_path!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }

      setState(() {
        _path = null;
        _duration = Duration.zero;
      });
    } on Exception catch (e) {
      debugPrint('Error deleting audio: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  bool _isTranscribing = false;
  String? _transcription;

  Future<void> _simulateTranscription() async {
    setState(() {
      _isTranscribing = true;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isTranscribing = false;
        _transcription =
            'Incidencia reportada en la zona norte. '
            'Requiere mantenimiento preventivo en la estructura principal.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shadcn.Card(
            child: Column(
              children: [
                Row(
                  children: [
                    shadcn.Button.ghost(
                      onPressed: _isPlaying ? _stop : _play,
                      child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatDuration(_duration)),
                    const Spacer(),
                    shadcn.Button.ghost(
                      onPressed: _delete,
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
                if (_isTranscribing)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Transcribing audio...'),
                      ],
                    ),
                  )
                else if (_transcription != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _transcription!,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      onLongPress: () {
        if (!_isRecording) {
          unawaited(_startRecording());
        }
      },
      onLongPressEnd: (_) {
        if (_isRecording) {
          unawaited(_stopRecording());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: _isRecording
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecording
                ? Colors.red
                : Colors.grey.withValues(alpha: 0.2),
            width: _isRecording ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing microphone icon when recording
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: Icon(
                _isRecording ? Icons.stop_circle : Icons.mic,
                color: _isRecording ? Colors.red : Colors.grey[700],
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRecording ? 'Recording...' : 'Add Audio Note',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _isRecording ? Colors.red : Colors.grey[800],
                  ),
                ),
                if (_isRecording)
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                  )
                else
                  Text(
                    'Tap or hold to record',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
