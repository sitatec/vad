# Flutter VAD Package for Web
Flutter VAD Package is a simple Dart binding for the [VAD JavaScript library](https://github.com/ricky0123/vad) . This package provides access to a Voice Activity Detection (VAD) system, allowing Flutter web applications to start and stop VAD-based listening and handle various VAD events.
## Getting Started

### Prerequisites

Ensure that you include the following in your web app’s HTML file to load the VAD library:


```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@ricky0123/vad-web@0.0.19/dist/bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/keyur2maru/vad_dart/dist/vad_dart.js"></script>
```

### Installation
Add this package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  vad: ^0.0.1
```

Then import the package in your Dart file:


```dart
import 'package:vad/vad.dart';
```

### Usage

1. **Initialize `VADHandler`:**  Set up the `VADHandler` to manage VAD sessions and handle events.

2. **Start Listening:**  Call `startListening()` to begin listening for voice activity.

3. **Handle Events:**  The package provides event streams to listen for VAD triggers such as speech start, speech end, errors, and misfires.

#### Example


```dart
import 'package:vad/vad.dart';

void main() {
  final vadHandler = VADHandler();

  vadHandler.onSpeechStart.listen((_) {
    print("Speech started.");
  });

  vadHandler.onSpeechEnd.listen((audioData) {
    print("Speech ended with audio data: $audioData");
  });

  vadHandler.onError.listen((error) {
    print("Error: $error");
  });

  vadHandler.startListening();
}
```

### VADHandler API

- `startListening({positiveSpeechThreshold, negativeSpeechThreshold, preSpeechPadFrames, redemptionFrames, frameSamples, minSpeechFrames, submitUserSpeechOnPause})`: Start the VAD with configurable parameters.

- `stopListening()`: Stop the VAD session.

- **Event Streams:**
    - `onSpeechEnd`: Triggered when speech ends with optional audio data.

    - `onSpeechStart`: Triggered when speech starts.

    - `onVADMisfire`: Triggered when the VAD misfires.

    - `onError`: Triggered when an error occurs.

### Cleaning Up
Call `dispose()` on the `VADHandler` to close all streams when they’re no longer needed.

```dart
vadHandler.dispose();
```

## License

This project is licensed under the MIT License. See the LICENSE file for details.


---