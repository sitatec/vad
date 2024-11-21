// vad_event.dart
import 'dart:typed_data';

enum VadEventType { start, end, misfire, error }

class VadEvent {
  final VadEventType type;
  final double timestamp;
  final String message;
  final Uint8List? audioData;

  VadEvent({
    required this.type,
    required this.timestamp,
    required this.message,
    this.audioData,
  });
}
