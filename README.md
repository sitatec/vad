# VAD
VAD is a Flutter library for Voice Activity Detection (VAD) across **iOS** , **Android** , and **Web**  platforms. This package allows applications to start and stop VAD-based listening and handle various VAD events seamlessly.
Under the hood, the VAD Package uses `dart:js_interop` for Web to run [VAD JavaScript library](https://github.com/ricky0123/vad) and 'package:onnxruntime' for iOS and Android using a custom API with full-feature parity with the JavaScript library.
The package provides a simple API to start and stop VAD listening, configure VAD parameters, and handle VAD events such as speech start, speech end, errors, and misfires.

## Table of Contents
- [Live Demo](#live-demo)
- [Features](#features)

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
    - [Web](#web)

    - [iOS](#ios)

    - [Android](#android)

- [Installation](#installation)

- [Usage](#usage)
  - [Example](#example)
    - [Explanation of the Example](#explanation-of-the-example)

- [VADHandler API](#vadhandler-api)
  - [Methods](#methods)
    - [`create`](#--create)

    - [`startListening`](#--startlistening)

    - [`stopListening`](#--stoplistening)

    - [`dispose`](#--dispose)

  - [Event Streams](#event-streams)
    - [`onSpeechEnd`](#--onspeechend)

    - [`onSpeechStart`](#--onspeechstart)

    - [`onVADMisfire`](#--onvadmisfire)

    - [`onError`](#--onerror)

- [Permissions](#permissions)
  - [iOS](#ios-1)

  - [Android](#android-1)

  - [Web](#web-1)

- [Cleaning Up](#cleaning-up)

- [Tested Platforms](#tested-platforms)

- [License](#license)

## Live Demo
Check out the [VAD Package Example App](https://keyur2maru.github.io/vad/) to see the VAD Package in action on the Web platform.

## Features

- **Cross-Platform Support:**  Works seamlessly on iOS, Android, and Web.

- **Event Streams:**  Listen to events such as speech start, speech end, errors, and misfires.

- **Configurable Parameters:**  Customize VAD behavior with various parameters.

- **Easy Integration:**  Simple setup and usage within Flutter applications.

## Getting Started

### Prerequisites

Before integrating the VAD Package into your Flutter application, ensure that you have the necessary configurations for each target platform.

#### Web
To use VAD on the web, include the following scripts in your `web/index.html` file to load the necessary VAD libraries:

```html
<!-- VAD Dependencies -->
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@ricky0123/vad-web@0.0.19/dist/bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/keyur2maru/vad_dart@latest/dist/vad_web.js"></script>
```

#### iOS
For iOS, you need to configure microphone permissions and other settings in your `Info.plist` file.
1. **Add Microphone Usage Description:** Open `ios/Runner/Info.plist` and add the following entries to request microphone access:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for Voice Activity Detection.</string>
```

2. **Configure Build Settings:** Ensure that your `Podfile` includes the necessary build settings for microphone permissions:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
      ]
    end
  end
end
```

#### Android
For Android, configure the required permissions and build settings in your `AndroidManifest.xml` and `build.gradle` files.
1. **Add Permissions:** Open `android/app/src/main/AndroidManifest.xml` and add the following permissions:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

2. **Configure Build Settings:** Open `android/app/build.gradle` and add the following settings:
```gradle
android {
    compileSdkVersion 34
    ...
}
```


## Installation
Add the VAD Package to your `pubspec.yaml` dependencies:
Note: `audioplayers` is used for audio playback in the example below. You can replace it with any other audio player package of your choice.

```yaml
dependencies:
  flutter:
    sdk: flutter
  vad: ^0.0.3
  permission_handler: ^11.3.1
  audioplayers: ^6.1.0
```
Then, run `flutter pub get` to fetch the packages.
## Usage

### Example

Below is a comprehensive example demonstrating how to integrate and use the VAD Package in a Flutter application supporting iOS, Android, and Web.


```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:vad/vad.dart';
import 'audio_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAD Example',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.blue[400],
          inactiveTrackColor: Colors.grey[800],
          thumbColor: Colors.blue[300],
          overlayColor: Colors.blue.withAlpha(32),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue[300],
          ),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum RecordingType {
  speech,
  misfire,
}

class Recording {
  final List<double>? samples;
  final RecordingType type;
  final DateTime timestamp;

  Recording({
    this.samples,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Recording> recordings = [];
  final audioplayers.AudioPlayer _audioPlayer = audioplayers.AudioPlayer();
  final _vadHandler = VadHandler.create(isDebug: true, modelPath: 'packages/vad/assets/models/silero_vad.onnx');
  bool isListening = false;
  int frameSamples = 1536; // 1 frame = 1536 samples = 96ms
  int minSpeechFrames = 3;
  int preSpeechPadFrames = 10;
  int redemptionFrames = 8;
  bool submitUserSpeechOnPause = false;

  // Audio player state
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  int? _currentlyPlayingIndex;

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _setupAudioPlayerListeners();
    _setupVadHandler();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _currentlyPlayingIndex = null;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == audioplayers.PlayerState.playing;
      });
    });
  }

  void _setupVadHandler() {
    _vadHandler.onSpeechStart.listen((_) {
      debugPrint('Speech detected.');
    });

    _vadHandler.onSpeechEnd.listen((List<double> samples) {
      setState(() {
        recordings.add(Recording(
          samples: samples,
          type: RecordingType.speech,
        ));
      });
      debugPrint('Speech ended, recording added.');
    });

    _vadHandler.onVADMisfire.listen((_) {
      setState(() {
        recordings.add(Recording(type: RecordingType.misfire));
      });
      debugPrint('VAD misfire detected.');
    });

    _vadHandler.onError.listen((String message) {
      debugPrint('Error: $message');
    });
  }

  Future<void> _initializeAudioPlayer() async {
    await _audioPlayer.setAudioContext(
      audioplayers.AudioContext(
        iOS: audioplayers.AudioContextIOS(
          options: const {audioplayers.AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
  }

  Future<void> _playRecording(Recording recording, int index) async {
    if (recording.type == RecordingType.misfire) return;

    try {
      if (_currentlyPlayingIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (_currentlyPlayingIndex != index) {
          String uri = AudioUtils.createWavUrl(recording.samples!);
          await _audioPlayer.play(audioplayers.UrlSource(uri));
          setState(() {
            _currentlyPlayingIndex = index;
            _isPlaying = true;
          });
        } else {
          await _audioPlayer.resume();
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    setState(() {
      _position = position;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _vadHandler.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  Widget _buildRecordingItem(Recording recording, int index) {
    final bool isCurrentlyPlaying = _currentlyPlayingIndex == index;
    final bool isMisfire = recording.type == RecordingType.misfire;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          ListTile(
            leading: isMisfire
                    ? const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.warning_amber_rounded, color: Colors.white),
            )
                    : CircleAvatar(
              backgroundColor: Colors.blue[900],
              child: Icon(
                isCurrentlyPlaying && _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.blue[100],
              ),
            ),
            title: Text(
              isMisfire ? 'Misfire Event' : 'Recording ${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMisfire ? Colors.red[300] : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatTimestamp(recording.timestamp)),
                if (!isMisfire) Text(
                  '${(recording.samples!.length / 16000).toStringAsFixed(1)} seconds',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
            onTap: isMisfire ? null : () => _playRecording(recording, index),
          ),
          if (isCurrentlyPlaying && !isMisfire) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.toDouble(),
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _seekTo(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VAD Example"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                return _buildRecordingItem(recordings[index], index);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      if (isListening) {
                        _vadHandler.stopListening();
                      } else {
                        _vadHandler.startListening(
                          frameSamples: frameSamples,
                          submitUserSpeechOnPause: submitUserSpeechOnPause,
                          preSpeechPadFrames: preSpeechPadFrames,
                          redemptionFrames: redemptionFrames,
                        );
                      }
                      isListening = !isListening;
                    });
                  },
                  icon: Icon(isListening ? Icons.stop : Icons.mic),
                  label: Text(isListening ? "Stop Listening" : "Start Listening"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final status = await Permission.microphone.request();
                    debugPrint("Microphone permission status: $status");
                  },
                  icon: const Icon(Icons.settings_voice),
                  label: const Text("Request Microphone Permission"),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```
#### Explanation of the Example
1. **Initialization:**
- Initializes the `VadHandler` with debugging enabled.

- Sets up listeners for various VAD events (`onSpeechStart`, `onSpeechEnd`, `onError`, `onVADMisfire`).

2. **Permissions:**
- Requests microphone permission when the "Request Microphone Permission" button is pressed.

3. **Listening Controls:**
- Toggles listening on and off with the "Start Listening"/"Stop Listening" button.

- Configures the audio player to mix with other audio sources on iOS.

4. **Playback:**
- Displays a list of recordings.

- Allows playback of recordings by tapping on them.
  **Note:**  Ensure that you have an `audio_utils.dart` file with the `createWavUrl` method implemented to handle audio data conversion as shown in the example app.

## VADHandler API

### Methods

#### - **`create`**
  Creates a new instance of the `VadHandler` with optional debugging enabled with the `isDebug` parameter.

#### - **`startListening`**
  Starts the VAD with configurable parameters.
  Sample Rate: 16kHz
  1 Frame = 1536 samples = 96ms


```dart
void startListening({
  double positiveSpeechThreshold = 0.5,
  double negativeSpeechThreshold = 0.35,
  int preSpeechPadFrames = 1,
  int redemptionFrames = 8,
  int frameSamples = 1536,
  int minSpeechFrames = 3,
  bool submitUserSpeechOnPause = false,
});
```

#### - **`stopListening`**
  Stops the VAD session.


```dart
void stopListening();
```

#### - **`dispose`**
  Disposes the VADHandler and closes all streams.


```dart
void dispose();
```

### Event Streams

#### - **`onSpeechEnd`**
  Triggered when speech ends with optional audio data.


```dart
Stream<List<double>> get onSpeechEnd;
```

#### - **`onSpeechStart`**
  Triggered when speech starts.


```dart
Stream<void> get onSpeechStart;
```

#### - **`onVADMisfire`**
  Triggered when the VAD misfires.


```dart
Stream<void> get onVADMisfire;
```

#### - **`onError`**
  Triggered when an error occurs.


```dart
Stream<String> get onError;
```

## Permissions

Proper handling of microphone permissions is crucial for the VAD Package to function correctly on all platforms.

### iOS

- **Configuration:** Ensure that `NSMicrophoneUsageDescription` is added to your `Info.plist` with a descriptive message explaining why the app requires microphone access.

- **Runtime Permission:** Request microphone permission at runtime using the `permission_handler` package.

### Android

- **Configuration:** Add the `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, and `INTERNET` permissions to your `AndroidManifest.xml`.

- **Runtime Permission:** Request microphone permission at runtime using the `permission_handler` package.

### Web

- **Browser Permissions:**
  Microphone access is managed by the browser. Users will be prompted to grant microphone access when the VAD starts listening.

## Cleaning Up 
To prevent memory leaks and ensure that all resources are properly released, always call the `dispose` method on the `VadHandler` instance when it's no longer needed.

```dart
vadHandler.dispose();
```

## Tested Platforms
The VAD Package has been tested on the following platforms:

- **iOS:**  Tested on iPhone 15 Pro Max running iOS 18.1.
- **Android:**  Tested on Lenovo Tab M8 Running Android 10.
- **Web:**  Tested on Chrome Mac/Windows/Android/iOS, Safari Mac/iOS.

## Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue if you encounter any problems or have suggestions for improvements.

## Acknowledgements
Special thanks to [Ricky0123](https://github.com/ricky0123) for creating the [VAD JavaScript library](https://github.com/ricky0123/vad), [gtbluesky](https://github.com/gtbluesky) for building the [onnxruntime package](https://github.com/gtbluesky/onnxruntime_flutter) and Silero Team for the [VAD model](https://github.com/snakers4/silero-vad) used in the library.


## License
This project is licensed under the [MIT License](https://opensource.org/license/mit) . See the [LICENSE](https://github.com/keyur2maru/vad/blob/master/LICENSE)  file for details.

---

For any issues or contributions, please visit the [GitHub repository](https://github.com/keyur2maru/vad) .