import 'task_attachment_picker_io.dart'
    if (dart.library.html) 'task_attachment_picker_web.dart';

class PickedTaskAttachmentData {
  const PickedTaskAttachmentData({
    required this.name,
    required this.bytes,
    required this.size,
    required this.contentType,
  });

  final String name;
  final List<int> bytes;
  final int size;
  final String contentType;
}

class AttachmentPickResultData {
  const AttachmentPickResultData({required this.files, this.errorMessage});

  final List<PickedTaskAttachmentData> files;
  final String? errorMessage;
}

Future<AttachmentPickResultData> pickTaskAttachments() {
  return pickTaskAttachmentsImpl();
}
