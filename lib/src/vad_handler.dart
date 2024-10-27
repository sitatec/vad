// vad_handler.dart

import 'package:vad/src/vad_handler_base.dart';
import 'vad_handler_web.dart' if (dart.library.io) 'vad_handler_non_web.dart' as implementation;

class VadHandler {
  static VadHandlerBase create({required bool isDebug}) {
    return implementation.createVadHandler(isDebug: isDebug);
  }
}
