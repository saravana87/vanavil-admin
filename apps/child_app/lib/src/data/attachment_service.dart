import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firestore_records.dart';

// ---------------------------------------------------------------------------
// Upload result from the child-upload endpoint
// ---------------------------------------------------------------------------

class UploadResult {
  const UploadResult({
    required this.bucket,
    required this.region,
    required this.objectKey,
    required this.contentType,
  });

  final String bucket;
  final String region;
  final String objectKey;
  final String contentType;
}

// ---------------------------------------------------------------------------
// Attachment service — download URLs + proof upload
// ---------------------------------------------------------------------------

class AttachmentService {
  static const _apiBaseUrl = String.fromEnvironment('VANAVIL_API_BASE_URL');

  // ── Download signed URL ─────────────────────────────────────────────────

  Future<String> getChildDownloadUrl({
    required String objectKey,
    required String taskId,
    required String assignmentId,
    required String childId,
  }) async {
    _ensureApiConfigured();

    final idToken = await _getIdToken();

    final uri = Uri.parse('$_apiBaseUrl/attachments/child-download-url');
    final response = await http.post(
      uri,
      headers: {
        'authorization': 'Bearer $idToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'objectKey': objectKey,
        'taskId': taskId,
        'assignmentId': assignmentId,
        'childId': childId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _tryParseErrorDetail(response.body);
      throw Exception(
        'Failed to get download URL (${response.statusCode}): $detail',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadUrl = body['downloadUrl'];
    if (downloadUrl is! String || downloadUrl.isEmpty) {
      throw Exception('Backend returned an empty downloadUrl.');
    }
    return downloadUrl;
  }

  // ── Upload child proof ──────────────────────────────────────────────────

  /// Uploads a file as child proof via multipart POST.
  ///
  /// Streams from disk using [filePath] to avoid loading large video files
  /// entirely into memory.
  Future<UploadResult> uploadChildProof({
    required String assignmentId,
    required String childId,
    required String fileName,
    required String contentType,
    required String filePath,
  }) async {
    _ensureApiConfigured();

    final idToken = await _getIdToken();

    final uri = Uri.parse('$_apiBaseUrl/attachments/child-upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] = 'Bearer $idToken'
      ..fields['assignmentId'] = assignmentId
      ..fields['childId'] = childId
      ..fields['fileName'] = fileName
      ..fields['contentType'] = contentType;

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = _tryParseErrorDetail(responseBody);
      throw Exception('Proof upload failed (${streamed.statusCode}): $detail');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return UploadResult(
      bucket: (json['bucket'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      objectKey: (json['objectKey'] as String?) ?? '',
      contentType: (json['contentType'] as String?) ?? contentType,
    );
  }

  // ── Upload child proof from bytes (web-compatible) ──────────────────────

  /// Uploads proof using in-memory bytes. Used on web where file paths are
  /// not available.
  Future<UploadResult> uploadChildProofBytes({
    required String assignmentId,
    required String childId,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    _ensureApiConfigured();

    final idToken = await _getIdToken();

    final uri = Uri.parse('$_apiBaseUrl/attachments/child-upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] = 'Bearer $idToken'
      ..fields['assignmentId'] = assignmentId
      ..fields['childId'] = childId
      ..fields['fileName'] = fileName
      ..fields['contentType'] = contentType;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = _tryParseErrorDetail(responseBody);
      throw Exception('Proof upload failed (${streamed.statusCode}): $detail');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return UploadResult(
      bucket: (json['bucket'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      objectKey: (json['objectKey'] as String?) ?? '',
      contentType: (json['contentType'] as String?) ?? contentType,
    );
  }

  Future<void> submitChildProof({
    required String assignmentId,
    required String taskId,
    required String childId,
    required List<SubmissionFileEntry> files,
    required String note,
  }) async {
    _ensureApiConfigured();

    final idToken = await _getIdToken();
    final uri = Uri.parse('$_apiBaseUrl/child-submissions/submit');
    final response = await http.post(
      uri,
      headers: {
        'authorization': 'Bearer $idToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'assignmentId': assignmentId,
        'taskId': taskId,
        'childId': childId,
        'note': note,
        'attachments': files
            .map(
              (file) => {
                'objectKey': file.objectKey,
                'fileName': file.fileName,
                'contentType': file.contentType,
                'sizeBytes': file.sizeBytes,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _tryParseErrorDetail(response.body);
      throw Exception('Submission failed (${response.statusCode}): $detail');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _ensureApiConfigured() {
    if (_apiBaseUrl.isEmpty) {
      throw Exception(
        'VANAVIL_API_BASE_URL is not set. '
        'Pass it with --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000',
      );
    }
  }

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        'No signed-in user. Firebase auth must be configured and '
        'the child must be signed in before using attachments.',
      );
    }
    return await user.getIdToken() ?? '';
  }

  String _tryParseErrorDetail(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json['detail']?.toString() ??
            json['message']?.toString() ??
            body;
      }
    } catch (_) {
      // Not JSON — fall through
    }
    return body;
  }
}
