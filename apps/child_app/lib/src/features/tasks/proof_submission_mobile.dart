import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Result from stopping a voice recording on mobile.
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

final _audioRecorder = AudioRecorder();

Future<bool> hasRecordingPermission() async {
  return _audioRecorder.hasPermission();
}

Future<void> startRecording() async {
  final dir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filePath = '${dir.path}/voice_note_$timestamp.m4a';

  await _audioRecorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: filePath,
  );
}

Future<RecordingResult?> stopRecording() async {
  final path = await _audioRecorder.stop();
  if (path == null) return null;

  final file = File(path);
  if (!file.existsSync()) return null;

  final bytes = await file.readAsBytes();
  return RecordingResult(
    filePath: path,
    sizeBytes: bytes.length,
    bytes: bytes,
  );
}

void disposeRecorder() {
  _audioRecorder.dispose();
}
