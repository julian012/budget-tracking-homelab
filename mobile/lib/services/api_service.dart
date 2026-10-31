import 'dart:convert';
import 'package:http/http.dart' as http;

class HealthResult {
  final bool ok;
  final int? statusCode;
  final String? error;

  const HealthResult({required this.ok, this.statusCode, this.error});
}

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<HealthResult> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return const HealthResult(ok: true, statusCode: 200);
      }
      return HealthResult(
        ok: false,
        statusCode: response.statusCode,
        error: 'Status ${response.statusCode}',
      );
    } catch (e) {
      return HealthResult(ok: false, error: e.toString());
    }
  }

  Future<List<dynamic>> getExpenses(String token, {String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final uri = Uri.parse('$baseUrl/api/expenses').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getExpenses failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getStats(String token, {String? startDate, String? endDate, String? type}) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (type != null) params['type'] = type;

    final uri = Uri.parse('$baseUrl/api/stats').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('getStats failed: ${response.statusCode}');
  }

  Future<List<dynamic>> getCategories(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/categories'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getCategories failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createExpense(String token, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/expenses'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createExpense failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> updateExpense(String token, String id, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/expenses/$id'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updateExpense failed: ${response.statusCode} ${response.body}');
  }

  Future<void> deleteExpense(String token, String id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/expenses/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('deleteExpense failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createCategory(String token, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/categories'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createCategory failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> updateCategory(String token, String id, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/categories/$id'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updateCategory failed: ${response.statusCode}');
  }

  Future<void> deleteCategory(String token, String id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/categories/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('deleteCategory failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/users/profile'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('getProfile failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/users/profile'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updateProfile failed: ${response.statusCode} ${response.body}');
  }

  Future<List<dynamic>> getCards(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/cards'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getCards failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createCard(String token, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/cards'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createCard failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> updateCard(String token, String id, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/cards/$id'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updateCard failed: ${response.statusCode}');
  }

  Future<void> deleteCard(String token, String id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/cards/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('deleteCard failed: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getPresets(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/presets'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getPresets failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createPreset(String token, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/presets'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createPreset failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> updatePreset(String token, String id, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/presets/$id'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updatePreset failed: ${response.statusCode} ${response.body}');
  }

  Future<void> deletePreset(String token, String id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/presets/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('deletePreset failed: ${response.statusCode}');
    }
  }

  // --- People / Shared expenses ---

  Future<List<dynamic>> getPeople(String token, {bool includeArchived = false}) async {
    final uri = Uri.parse('$baseUrl/api/people').replace(
      queryParameters: includeArchived ? {'include_archived': 'true'} : null,
    );
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getPeople failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createPerson(String token, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/people'), headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createPerson failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> updatePerson(String token, String id, Map<String, dynamic> body) async {
    final response = await http
        .put(Uri.parse('$baseUrl/api/people/$id'), headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('updatePerson failed: ${response.statusCode} ${response.body}');
  }

  Future<void> deletePerson(String token, String id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/api/people/$id'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('deletePerson failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> archivePerson(String token, String id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/people/$id/archive'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('archivePerson failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> unarchivePerson(String token, String id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/people/$id/unarchive'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('unarchivePerson failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getSharedSummary(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/shared/summary'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('getSharedSummary failed: ${response.statusCode}');
  }

  Future<List<dynamic>> getPersonShares(String token, String personId, {String status = 'all'}) async {
    final uri = Uri.parse('$baseUrl/api/people/$personId/shares').replace(
      queryParameters: status == 'all' ? null : {'status': status},
    );
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getPersonShares failed: ${response.statusCode}');
  }

  Future<List<dynamic>> getPersonPayments(String token, String personId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/people/$personId/payments'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('getPersonPayments failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createPersonPayment(String token, String personId, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/people/$personId/payments'), headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('createPersonPayment failed: ${response.statusCode} ${response.body}');
  }

  Future<void> deletePersonPayment(String token, String id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/api/payments/$id'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('deletePersonPayment failed: ${response.statusCode} ${response.body}');
    }
  }
}
