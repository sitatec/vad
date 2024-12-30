## 0.0.5
* Add support for Silero VAD v5 model.
* Expose `onRealSpeechStart` callback to notify when the number of speech positive frames exceeds the minimum speech frames (i.e. not a misfire event).

## 0.0.4

* Fixed a bug where default `modelPath` was not picked up, resulting in silent failure if `modelPath` was not provided.
* Export `VadIterator` class for manual control over the VAD process for non-streaming use cases. Only available on iOS/Android.
* Added comments for all public methods and classes.

## 0.0.3

* Switch to `onnxruntime` package for inference on a separate isolate on iOS and Android to avoid using a full browser in the background, overall reducing the app size and improving performance.
* Example app will show audio track slider with controls while speech segment is being played and it will reflect a misfire event on the UI if occurred.

## 0.0.2

* Fix broken LICENSE hyperlink in README.md and add topics to pubspec.yaml

## 0.0.1

* Initial release
