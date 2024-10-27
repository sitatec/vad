// vad_handler_web.dart

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'vad_handler_base.dart';

@JS('startListeningImpl')
external void startListeningImpl(
    double positiveSpeechThreshold,
    double negativeSpeechThreshold,
    int preSpeechPadFrames,
    int redemptionFrames,
    int frameSamples,
    int minSpeechFrames,
    bool submitUserSpeechOnPause);

@JS('stopListeningImpl')
external void stopListeningImpl();

@JS('isListeningNow')
external bool isListeningNow();

@JS('logMessage')
external void logMessage(String message);

@JS('callDartFunction')
external void executeDartHandler();

class VadHandlerWeb implements VadHandlerBase {
  final StreamController<List<double>> _onSpeechEndController =
  StreamController<List<double>>.broadcast();
  final StreamController<void> _onSpeechStartController =
  StreamController<void>.broadcast();
  final StreamController<void> _onVADMisfireController =
  StreamController<void>.broadcast();
  final StreamController<String> _onErrorController =
  StreamController<String>.broadcast();

  bool isDebug = false;

  VadHandlerWeb({required bool isDebug}) {
    globalContext['executeDartHandler'] = handleEvent.toJS;
    isDebug = isDebug;
  }

  @override
  Stream<List<double>> get onSpeechEnd => _onSpeechEndController.stream;

  @override
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;

  @override
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;

  @override
  Stream<String> get onError => _onErrorController.stream;

  @override
  void startListening({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false
  }) {
    if (isDebug) {
      debugPrint('VadHandlerWeb: startListening: Calling startListeningImpl with parameters: '
          'positiveSpeechThreshold: $positiveSpeechThreshold, '
          'negativeSpeechThreshold: $negativeSpeechThreshold, '
          'preSpeechPadFrames: $preSpeechPadFrames, '
          'redemptionFrames: $redemptionFrames, '
          'frameSamples: $frameSamples, '
          'minSpeechFrames: $minSpeechFrames, '
          'submitUserSpeechOnPause: $submitUserSpeechOnPause');
    }
    startListeningImpl(
        positiveSpeechThreshold,
        negativeSpeechThreshold,
        preSpeechPadFrames,
        redemptionFrames,
        frameSamples,
        minSpeechFrames,
        submitUserSpeechOnPause
    );
  }

  void handleEvent(String eventType, String payload) {
    try {
      Map<String, dynamic> eventData =
      payload.isNotEmpty ? json.decode(payload) : {};

      switch (eventType) {
        case 'onError':
          if (isDebug) {
            debugPrint('VadHandlerWeb: onError: ${eventData['error']}');
          }
          _onErrorController.add(payload);
          break;
        case 'onSpeechEnd':
          if (eventData.containsKey('audioData')) {
            final List<double> audioData = (eventData['audioData'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
            if (isDebug) {
              debugPrint('VadHandlerWeb: onSpeechEnd: first 5 samples: ${audioData.sublist(0, 5)}');
            }
            _onSpeechEndController.add(audioData);
          } else {
            if (isDebug) {
              debugPrint('Invalid VAD Data received: $eventData');
            }
          }
          break;
        case 'onSpeechStart':
          if (isDebug) {
            debugPrint('VadHandlerWeb: onSpeechStart');
          }
          _onSpeechStartController.add(null);
          break;
        case 'onVADMisfire':
          if (isDebug) {
            debugPrint('VadHandlerWeb: onVADMisfire');
          }
          _onVADMisfireController.add(null);
          break;
        default:
          debugPrint("Unknown event: $eventType");
      }
    } catch (e, st) {
      debugPrint('Error handling event: $e');
      debugPrint('Stack Trace: $st');
    }
  }

  @override
  void dispose() {
    if (isDebug) {
      debugPrint('VadHandlerWeb: dispose');
    }
    _onSpeechEndController.close();
    _onSpeechStartController.close();
    _onVADMisfireController.close();
    _onErrorController.close();
  }

  @override
  void stopListening() {
    if (isDebug) {
      debugPrint('VadHandlerWeb: stopListening');
    }
    stopListeningImpl();
  }
}

VadHandlerBase createVadHandler({required isDebug}) => VadHandlerWeb(isDebug: isDebug);