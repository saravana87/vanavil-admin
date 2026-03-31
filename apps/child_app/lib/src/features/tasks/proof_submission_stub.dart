import 'dart:typed_data';

/// Web stub — voice recording is not supported on web.
/// These functions are never called on web (guarded by kIsWeb checks).

class RecordingResult {
  const RecordingResult({
    required this.filePath,
    required this.sizeBytes,
    this.bytes,
  });

  final String filePath;
  final int sizeBytes;
  final Uint8List? bytes;
}

Future<bool> hasRecordingPermission() async => false;

Future<void> startRecording() async {
  throw UnsupportedError('Voice recording is not supported on web.');
}

Future<RecordingResult?> stopRecording() async => null;

void disposeRecorder() {}
