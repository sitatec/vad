import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/cupertino.dart';

@JS('startListeningImpl')
external void startListeningImpl(double positiveSpeechThreshold, double negativeSpeechThreshold, int preSpeechPadFrames, int redemptionFrames, int frameSamples, int minSpeechFrames, bool submitUserSpeechOnPause);

@JS('stopListening')
external void stopListening();

@JS('isListeningNow')
external bool isListeningNow();

@JS('logMessage')
external void logMessage(String message);

@JS('callDartFunction')
external void executeDartHandler();

class VADHandler {
  final StreamController<String> _onSpeechEndController = StreamController<String>.broadcast();
  final StreamController<void> _onSpeechStartController = StreamController<void>.broadcast();
  final StreamController<void> _onVADMisfireController = StreamController<void>.broadcast();
  final StreamController<String> _onErrorController = StreamController<String>.broadcast();

  VADHandler() {
    globalContext['executeDartHandler'] = handleEvent.toJS;
  }

  Stream<String> get onSpeechEnd => _onSpeechEndController.stream;
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;
  Stream<String> get onError => _onErrorController.stream;

  void startListening({positiveSpeechThreshold = 0.5, negativeSpeechThreshold = 0.5 - 0.15, preSpeechPadFrames = 1, redemptionFrames = 8, frameSamples = 1536, minSpeechFrames = 3, submitUserSpeechOnPause = false}) {
    startListeningImpl(
        positiveSpeechThreshold,
        negativeSpeechThreshold,
        preSpeechPadFrames,
        redemptionFrames,
        frameSamples,
        minSpeechFrames,
        submitUserSpeechOnPause);
  }

  void handleEvent(String eventType, String payload) {
    try {
      Map<String, dynamic> eventData = payload.isNotEmpty ? json.decode(payload) : {};

      switch (eventType) {
        case 'onError':
          _onErrorController.add(payload);
          break;
        case 'onSpeechEnd':
          if (eventData.containsKey('audioData')) {
            _onSpeechEndController.add(eventData['audioData']);
          } else {
            debugPrint('Invalid VAD Data received: $eventData');
          }
          break;
        case 'onSpeechStart':
          _onSpeechStartController.add(null);
          break;
        case 'onVADMisfire':
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

  void dispose() {
    _onSpeechEndController.close();
    _onSpeechStartController.close();
    _onVADMisfireController.close();
    _onErrorController.close();
  }
}

