import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class AiApiException implements Exception {
  AiApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiApiClient {
  AiApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint =
      'http://127.0.0.1:5001/nutrifit-project-2026/us-central1/askNutriFitAi';
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
        throw AiApiException('Σφάλμα API: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final text = decoded['answer'] ?? decoded['text'] ?? decoded['response'];

      if (text == null || text.toString().trim().isEmpty) {
        throw AiApiException('Κενή απάντηση.');
      }
      return text.toString().trim();
    } on TimeoutException {
      throw AiApiException('Timeout');
    } catch (e) {
      throw AiApiException('Connection Error: $e');
    }
  }
}
