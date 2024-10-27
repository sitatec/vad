// vad_handler_non_web.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'vad_handler_base.dart';

class VadHandlerNonWeb implements VadHandlerBase {
  HeadlessInAppWebView? _headlessWebView;
  final _onSpeechEndController = StreamController<List<double>>.broadcast();
  final _onSpeechStartController = StreamController<void>.broadcast();
  final _onVADMisfireController = StreamController<void>.broadcast();
  final _onErrorController = StreamController<String>.broadcast();
  bool _isInitialized = false;

  @override
  Stream<List<double>> get onSpeechEnd => _onSpeechEndController.stream;

  @override
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;

  @override
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;

  @override
  Stream<String> get onError => _onErrorController.stream;

  bool isDebug = false;

  VadHandlerNonWeb({required bool isDebug}) {
    _initialize(isDebug);
  }

  Future<void> _initialize([bool isDebug = false]) async {
    if (_isInitialized) return;
    if (isDebug) {
      PlatformInAppWebViewController.debugLoggingSettings.enabled = true;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
      }
    } else {
      PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    }
    isDebug = isDebug;

    final completer = Completer<void>();

    _headlessWebView = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: '',
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('https://example.com'),
      ),
      onLoadStart: (controller, url) {
        if (isDebug) debugPrint('VadHandlerNonWeb: VAD Webview loading: $url');
      },
      onLoadStop: (controller, url) async {
        if (isDebug) debugPrint('VadHandlerNonWeb: VAD Webview loaded');
      },
      onPermissionRequest: (controller, request) async {
        if (isDebug) debugPrint('VadHandlerNonWeb: VAD Permission Request: $request');
        return PermissionResponse(resources: request.resources,
            action: PermissionResponseAction.GRANT);
      },
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        isInspectable: kDebugMode,
        allowsInlineMediaPlayback: true,
        allowBackgroundAudioPlaying: true,
      ),
      onMicrophoneCaptureStateChanged: (controller, state, _) {
        if (state == MediaCaptureState.ACTIVE) {
          if (isDebug) debugPrint('VadHandlerNonWeb: Microphone is no longer recording, starting recording again');
          _headlessWebView?.webViewController?.setMicrophoneCaptureState(state: MediaCaptureState.ACTIVE);
        }
        return Future.value();
      },
      onWebViewCreated: (controller) async {
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://keyur2maru.github.io/vad_dart/dist/vad_non_web')));
        controller.addJavaScriptHandler(
          handlerName: 'onVadInitialized',
          callback: (args) {
            if (isDebug) debugPrint('VadHandlerNonWeb: VAD Initialized');
              _isInitialized = true;
            completer.complete();
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'handleEvent',
          callback: (args) {
            if (args.length >= 2) {
              final eventType = args[0] as String;
              final payload = args[1] as String;
              _handleEvent(eventType, payload);
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'logMessage',
          callback: (args) {
            if (args.isNotEmpty) {
              debugPrint('VadHandlerNonWeb: VAD Log: ${args.first}');
            }
          },
        );
      },
      onReceivedError: (controller, request, error) {
        debugPrint('VadHandlerNonWeb: VAD Error: ${error.description}');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('VadHandlerNonWeb: VAD Console: ${consoleMessage.message}');
      },
    );

    await _headlessWebView?.run();

    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('VadHandlerNonWeb: VAD initialization timed out');
        },
      );
      if (isDebug) debugPrint('VadHandlerNonWeb: VAD initialized successfully');
    } catch (e) {
      _onErrorController.add(e.toString());
      debugPrint('VadHandlerNonWeb: VAD initialization failed: $e');
    }
  }

  void _handleEvent(String eventType, String payload) {
    try {
      Map<String, dynamic> eventData =
      payload.isNotEmpty ? json.decode(payload) : {};

      switch (eventType) {
        case 'onError':
          if (eventData.containsKey('error')) {
            if (isDebug) debugPrint('VadHandlerNonWeb: _handleEvent: VAD Error: ${eventData['error']}');
            _onErrorController.add(eventData['error'].toString());
          } else {
            _onErrorController.add(payload);
          }
          break;
        case 'onSpeechEnd':
          if (eventData.containsKey('audioData')) {
            final List<double> audioData = (eventData['audioData'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
            _onSpeechEndController.add(audioData);
            if (isDebug) debugPrint('VadHandlerNonWeb: _handleEvent: VAD Speech End: first 5 samples: ${audioData.sublist(0, 5)}');
          } else {
            debugPrint('VadHandlerNonWeb: _handleEvent: Invalid VAD Data received: $eventData');
          }
          break;
        case 'onSpeechStart':
          if (isDebug) debugPrint('VadHandlerNonWeb: _handleEvent: VAD Speech Start');
          _onSpeechStartController.add(null);
          break;
        case 'onVADMisfire':
          if (isDebug) debugPrint('VadHandlerNonWeb: _handleEvent: VAD Misfire');
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
  void startListening({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false
  }) async {
    if (!_isInitialized) {
      if (isDebug) debugPrint('VadHandlerNonWeb: startListening: VAD not initialized, initializing now');
      await _initialize();
    }

    await _headlessWebView?.webViewController?.evaluateJavascript(
      source: '''
        startListeningImpl(
          $positiveSpeechThreshold,
          $negativeSpeechThreshold,
          $preSpeechPadFrames,
          $redemptionFrames,
          $frameSamples,
          $minSpeechFrames,
          $submitUserSpeechOnPause
        )
      ''',
    );
    debugPrint('VadHandlerNonWeb: startListening: VAD started');
  }

  @override
  void stopListening() async {
    if (!_isInitialized) {
      if (isDebug) debugPrint('VadHandlerNonWeb: stopListening: VAD not initialized');
      _onErrorController.add('VAD not initialized');
      return;
    }

    await _headlessWebView?.webViewController?.evaluateJavascript(
      source: 'stopListening()',
    );
    if (isDebug) debugPrint('VadHandlerNonWeb: stopListening: VAD stopped');
  }

  @override
  void dispose() {
    if (isDebug) debugPrint('VadHandlerNonWeb: Disposing VAD');
    stopListening();
    _isInitialized = false;
    _headlessWebView?.dispose();
    _onSpeechEndController.close();
    _onSpeechStartController.close();
    _onVADMisfireController.close();
    _onErrorController.close();
  }
}

VadHandlerBase createVadHandler({required isDebug}) => VadHandlerNonWeb(isDebug: isDebug);