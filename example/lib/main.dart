import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '' if (dart.library.html) 'package:vad/vad.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAD Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> recordings = [];
  late final VADHandler _vadHandler;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isListening = false;
  int preSpeechPadFrames = 10;
  int redemptionFrames = 8;
  bool submitUserSpeechOnPause = false;

  @override
  void initState() {
    super.initState();
    _vadHandler = VADHandler();

    // Listen for events
    _vadHandler.onSpeechStart.listen((_) {
      debugPrint('Speech detected.');
    });

    _vadHandler.onSpeechEnd.listen((String audioData) {
      setState(() {
        recordings.add(audioData);
      });
      debugPrint('Speech ended, recording added.');
    });

    _vadHandler.onVADMisfire.listen((_) {
      debugPrint('VAD misfire detected.');
    });

    _vadHandler.onError.listen((String message) {
      debugPrint('Error: $message');
    });
  }

  Future<void> _playRecording(String base64Wav) async {
    try {
      String uri = 'data:audio/wav;base64,$base64Wav';
      await _audioPlayer.play(UrlSource(uri));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _vadHandler.dispose();
    super.dispose();
  }

  Widget _buildRecordingItem(String audio, int index) {
    return ListTile(
      leading: const Icon(Icons.mic),
      title: Text('Recording ${index + 1}'),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () => _playRecording(audio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VAD Example")),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  return _buildRecordingItem(recordings[index], index);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        if (isListening) {
                          stopListening();
                        } else {
                          _vadHandler.startListening(submitUserSpeechOnPause: submitUserSpeechOnPause, preSpeechPadFrames: preSpeechPadFrames, redemptionFrames: redemptionFrames);
                        }
                        isListening = !isListening;
                      });
                    },
                    child: Text(isListening ? "Stop Listening" : "Start Listening"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final status = await Permission.microphone.request();
                      debugPrint("Microphone permission status: $status");
                      logMessage("Microphone permission status: $status");
                    },
                    child: const Text("Request Microphone Permission"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
