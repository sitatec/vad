// vad_event.dart
import 'dart:typed_data';

/// VadEventType enum used by non-web VAD handler
enum VadEventType {
  /// Speech start event
  start,

  /// Real speech start event
  realStart,

  /// Speech end event
  end,

  /// VAD misfire event
  misfire,

  /// Error event
  error,
}

/// VadEvent class
class VadEvent {
  /// VadEventType
  final VadEventType type;

  /// Timestamp
  final double timestamp;

  /// Message
  final String message;

  /// Audio data
  final Uint8List? audioData;

  /// Constructor
  VadEvent({
    required this.type,
    required this.timestamp,
    required this.message,
    this.audioData,
  });
}
