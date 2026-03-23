import 'task_attachment_picker.dart';

Future<AttachmentPickResultData> pickTaskAttachmentsImpl() async {
  return const AttachmentPickResultData(
    files: <PickedTaskAttachmentData>[],
    errorMessage:
        'Task attachments are implemented for the admin web app only.',
  );
}
