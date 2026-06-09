import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiApiException implements Exception {
  AiApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class AiApiClient {
  AiApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredEndpoint = String.fromEnvironment(
    'NUTRIFIT_AI_ENDPOINT',
  );
  static const _projectId = String.fromEnvironment(
    'NUTRIFIT_FIREBASE_PROJECT_ID',
    defaultValue: 'nutrifit-database',
  );
  static const _region = String.fromEnvironment(
    'NUTRIFIT_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  final http.Client _client;

  Future<String> callExternalAPI(String prompt) async {
    if (prompt.trim().isEmpty) throw AiApiException('Κενό ερώτημα.');

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': prompt.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _apiErrorFromResponse(response);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final text = decoded['answer'] ?? decoded['text'] ?? decoded['response'];

      if (text == null || text.toString().trim().isEmpty) {
        throw AiApiException('Κενή απάντηση.');
      }
      return text.toString().trim();
    } on TimeoutException {
      throw AiApiException(
        'Η εξωτερική υπηρεσία AI άργησε να απαντήσει. Δοκίμασε ξανά.',
        code: 'timeout',
      );
    } on AiApiException {
      rethrow;
    } catch (e) {
      throw AiApiException(
        'Δεν ήταν δυνατή η σύνδεση με την υπηρεσία AI.',
        code: 'connection_error',
      );
    }
  }

  static String get _endpoint {
    if (_configuredEndpoint.trim().isNotEmpty) {
      return _configuredEndpoint.trim();
    }

    return 'http://${_localFunctionsHost()}:5001/'
        '$_projectId/$_region/askNutriFitAi';
  }

  static String _localFunctionsHost() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  AiApiException _apiErrorFromResponse(http.Response response) {
    String? error;
    String? code;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        error = decoded['error']?.toString();
        code = decoded['errorCode']?.toString();
      }
    } catch (_) {
      // Use the generic fallback below when the response is not JSON.
    }

    return AiApiException(
      error ?? 'Η υπηρεσία AI επέστρεψε σφάλμα (${response.statusCode}).',
      code: code,
      statusCode: response.statusCode,
    );
  }
}
