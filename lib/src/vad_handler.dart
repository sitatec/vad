// vad_handler.dart

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
  final StreamController<List<double>> _onSpeechEndController = StreamController<List<double>>.broadcast();
  final StreamController<void> _onSpeechStartController = StreamController<void>.broadcast();
  final StreamController<void> _onVADMisfireController = StreamController<void>.broadcast();
  final StreamController<String> _onErrorController = StreamController<String>.broadcast();

  VADHandler() {
    globalContext['executeDartHandler'] = handleEvent.toJS;
  }

  Stream<List<double>> get onSpeechEnd => _onSpeechEndController.stream;
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;
  Stream<String> get onError => _onErrorController.stream;

  void startListening({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false
  }) {
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
      Map<String, dynamic> eventData = payload.isNotEmpty ? json.decode(payload) : {};

      switch (eventType) {
        case 'onError':
          _onErrorController.add(payload);
          break;
        case 'onSpeechEnd':
          if (eventData.containsKey('audioData')) {
            // Convert the JSON array back to List<double>
            final List<double> audioData = (eventData['audioData'] as List)
                .map((e) => (e as num).toDouble())
                .toList();

            // Pass raw audio data through
            _onSpeechEndController.add(audioData);
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