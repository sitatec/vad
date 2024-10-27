// vad_handler_base.dart

import 'dart:async';

abstract class VadHandlerBase {
  Stream<List<double>> get onSpeechEnd;
  Stream<void> get onSpeechStart;
  Stream<void> get onVADMisfire;
  Stream<String> get onError;

  void startListening({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false
  });

  void stopListening();
  void dispose();
}