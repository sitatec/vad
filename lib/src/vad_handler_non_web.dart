// vad_handler_non_web.dart

import 'package:flutter/cupertino.dart';
import 'package:record/record.dart';
import 'package:vad/src/vad_handler_base.dart';
import 'dart:async';
import 'vad_event.dart';
import 'vad_iterator.dart';

class VadHandlerNonWeb implements VadHandlerBase {
  final AudioRecorder _audioRecorder = AudioRecorder();
  late VadIterator _vadIterator;
  StreamSubscription<List<int>>? _audioStreamSubscription;
  String modelPath;
  bool isDebug = false;
  bool _isInitialized = false;
  static const int sampleRate = 16000;

  final _onSpeechEndController = StreamController<List<double>>.broadcast();
  final _onSpeechStartController = StreamController<void>.broadcast();
  final _onVADMisfireController = StreamController<void>.broadcast();
  final _onErrorController = StreamController<String>.broadcast();

  @override
  Stream<List<double>> get onSpeechEnd => _onSpeechEndController.stream;

  @override
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;

  @override
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;

  @override
  Stream<String> get onError => _onErrorController.stream;

  VadHandlerNonWeb({required this.isDebug, this.modelPath = 'packages/vad/assets/models/silero_vad.onnx'});

  Future<void> initializeVAD() async {
    if (isDebug) debugPrint('VadHandlerNonWeb: Initializing VAD');
    await _vadIterator.initModel(modelPath);
    _vadIterator.setVadEventCallback(_handleVadEvent);
    _isInitialized = true;
  }

  void _handleVadEvent(VadEvent event) {
    if (isDebug) debugPrint('VadHandlerNonWeb: VAD Event: ${event.type} with message ${event.message}');
    switch (event.type) {
      case VadEventType.start:
        _onSpeechStartController.add(null);
        break;
      case VadEventType.end:
        if (event.audioData != null) {
          final int16List = event.audioData!.buffer.asInt16List();
          final floatSamples = int16List.map((e) => e / 32768.0).toList();
          _onSpeechEndController.add(floatSamples);
        }
        break;
      case VadEventType.misfire:
        _onVADMisfireController.add(null);
        break;
      case VadEventType.error:
        _onErrorController.add(event.message);
        break;
      default:
        break;
    }
  }

  @override
  Future<void> startListening({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false
  }) async {
    if (!_isInitialized) {
      _vadIterator = VadIterator(
          isDebug: isDebug,
          sampleRate: sampleRate,
          frameSamples: frameSamples,
          positiveSpeechThreshold: positiveSpeechThreshold,
          negativeSpeechThreshold: negativeSpeechThreshold,
          redemptionFrames: redemptionFrames,
          preSpeechPadFrames: preSpeechPadFrames,
          minSpeechFrames: minSpeechFrames,
          submitUserSpeechOnPause: submitUserSpeechOnPause
      );
      await initializeVAD();
    }

    bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _onErrorController.add('VadHandlerNonWeb: No permission to record audio.');
      if (isDebug) debugPrint('VadHandlerNonWeb: No permission to record audio.');
      return;
    }

    // Start recording with a stream
    final stream = await _audioRecorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _vadIterator.sampleRate,
        bitRate: 16,
        numChannels: 1,
        echoCancel: true,
        autoGain: true,
        noiseSuppress: true
    ));

    _audioStreamSubscription = stream.listen((data) async {
      await _vadIterator.processAudioData(data);
    });
  }

  @override
  Future<void> stopListening() async {
    if (isDebug) debugPrint('stopListening');
    try {
      // Before stopping the audio stream, handle forced speech end if needed
      if (_vadIterator.submitUserSpeechOnPause) {
        _vadIterator.forceEndSpeech();
      }

      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _audioRecorder.stop();
      _vadIterator.reset();
    } catch (e) {
      _onErrorController.add(e.toString());
      if (isDebug) debugPrint('Error stopping audio stream: $e');
    }
  }


  @override
  void dispose() {
    if (isDebug) debugPrint('VadHandlerNonWeb: dispose');
    stopListening();
    _vadIterator.release();
    _onSpeechEndController.close();
    _onSpeechStartController.close();
    _onVADMisfireController.close();
    _onErrorController.close();
  }
}

VadHandlerBase createVadHandler({required isDebug, modelPath}) => VadHandlerNonWeb(isDebug: isDebug, modelPath: modelPath);
