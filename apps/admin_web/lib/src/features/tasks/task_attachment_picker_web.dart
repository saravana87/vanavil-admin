// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'task_attachment_picker.dart';

Future<AttachmentPickResultData> pickTaskAttachmentsImpl() async {
  try {
    final input = html.FileUploadInputElement()..multiple = true;
    final completer = Completer<AttachmentPickResultData>();

    input.onChange.listen((_) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) {
          completer.complete(
            const AttachmentPickResultData(files: <PickedTaskAttachmentData>[]),
          );
        }
        return;
      }

      try {
        final pickedFiles = <PickedTaskAttachmentData>[];
        for (final file in files) {
          final bytes = await _readFileBytes(file);
          pickedFiles.add(
            PickedTaskAttachmentData(
              name: file.name,
              bytes: bytes,
              size: file.size,
              contentType: file.type,
            ),
          );
        }

        if (!completer.isCompleted) {
          completer.complete(AttachmentPickResultData(files: pickedFiles));
        }
      } catch (error) {
        if (!completer.isCompleted) {
          completer.complete(
            AttachmentPickResultData(
              files: const <PickedTaskAttachmentData>[],
              errorMessage: 'Unable to read selected files: $error',
            ),
          );
        }
      }
    });

    input.click();
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          const AttachmentPickResultData(files: <PickedTaskAttachmentData>[]),
    );
  } catch (error) {
    return AttachmentPickResultData(
      files: const <PickedTaskAttachmentData>[],
      errorMessage: 'Unable to open the browser file picker: $error',
    );
  }
}

Future<Uint8List> _readFileBytes(html.File file) {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();

  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }
    completer.completeError('Unsupported browser file result type.');
  });

  reader.onError.listen((_) {
    completer.completeError(reader.error ?? 'Unknown file read error.');
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
