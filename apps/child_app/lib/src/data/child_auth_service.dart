import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:vanavil_core/vanavil_core.dart';

class ChildAuthService {
  static const _apiBaseUrl = String.fromEnvironment('VANAVIL_API_BASE_URL');

  Future<List<ChildProfile>> loadActiveChildren() async {
    if (_apiBaseUrl.isEmpty) {
      throw Exception(
        'VANAVIL_API_BASE_URL is not set. '
        'Pass it with --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000',
      );
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/child-auth/active-children'),
      headers: const {'accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Unable to load child profiles (${response.statusCode}): '
        '${_tryParseErrorDetail(response.body)}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Backend returned an invalid child profile response.');
    }

    final childrenJson = body['children'];
    if (childrenJson is! List) {
      throw Exception('Backend did not return a child profile list.');
    }

    return childrenJson
        .whereType<Map<String, dynamic>>()
        .map(_childProfileFromJson)
        .toList();
  }

  Future<void> signInWithPin({
    required String childId,
    required String pin,
  }) async {
    if (_apiBaseUrl.isEmpty) {
      throw Exception(
        'VANAVIL_API_BASE_URL is not set. '
        'Pass it with --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000',
      );
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/child-auth/verify-pin'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'childId': childId, 'pin': pin}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'PIN verification failed (${response.statusCode}): '
        '${_tryParseErrorDetail(response.body)}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('Backend returned an empty custom token.');
    }

    try {
      await FirebaseAuth.instance.signInWithCustomToken(token);
    } on FirebaseAuthException catch (error) {
      throw Exception(error.message ?? 'Firebase sign-in failed.');
    }
  }

  ChildProfile _childProfileFromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw Exception('Backend returned a child profile without an id.');
    }

    final name = (json['name'] as String?)?.trim();
    final avatar = (json['avatar'] as String?)?.trim();
    final totalPoints = json['totalPoints'];

    return ChildProfile(
      id: id,
      name: (name == null || name.isEmpty) ? 'Child' : name,
      avatar: (avatar == null || avatar.isEmpty)
          ? 'C'
          : avatar.substring(0, 1).toUpperCase(),
      totalPoints: totalPoints is num ? totalPoints.toInt() : 0,
      isActive: true,
    );
  }

  String _tryParseErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            body;
      }
    } catch (_) {
      // Fall through for non-JSON responses.
    }
    return body;
  }
}
