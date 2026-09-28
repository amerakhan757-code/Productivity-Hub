import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://productivity-hub-production-22ee.up.railway.app';

  static String? _token;

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static bool get isLoggedIn => _token != null;

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(json: true),
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // PUT
  // ============================================================

  static Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(json: true),
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // PATCH
  // ============================================================

  static Future<dynamic> patch(String endpoint) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  static dynamic _handleResponse(http.Response response) {
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String message = 'Something went wrong.';

    if (data is Map && data['detail'] != null) {
      message = data['detail'].toString();
    }

    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    }

    throw Exception(
      '$message (Status: ${response.statusCode})',
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _handleResponse(response);

    if (data is Map && data['token'] != null) {
      await saveToken(data['token'].toString());
    }

    return Map<String, dynamic>.from(data);
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _handleResponse(response);

    if (data is Map && data['token'] != null) {
      await saveToken(data['token'].toString());
    }

    return Map<String, dynamic>.from(data);
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final data = await get('/auth/me');

    return Map<String, dynamic>.from(data);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    await clearToken();
  }

  // ============================================================
  // CONNECTION TEST
  // ============================================================

  static Future<bool> testConnection() async {
    try {
      final data = await get('/hello');

      return data is Map &&
          data['message'] == 'Hello from Node.js!';
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // GOALS
  // ============================================================

  static Future<List<dynamic>> getGoals() async {
    final data = await get('/goals');

    return List<dynamic>.from(data);
  }

  static Future<dynamic> createGoal({
    required String title,
    required String description,
    required DateTime deadline,
  }) {
    return post('/goals', {
      'title': title,
      'description': description,
      'deadline': _formatDate(deadline),
    });
  }

  static Future<dynamic> updateGoal({
    required String id,
    required String title,
    required String description,
    required DateTime deadline,
  }) {
    return put('/goals/$id', {
      'title': title,
      'description': description,
      'deadline': _formatDate(deadline),
    });
  }

  static Future<dynamic> deleteGoal(String id) {
    return delete('/goals/$id');
  }

  // ============================================================
  // TASKS
  // ============================================================

  static Future<List<dynamic>> getTasks() async {
    final data = await get('/tasks');

    return List<dynamic>.from(data);
  }

  static Future<dynamic> createTask({
    required String title,
    required String goalId,
    required DateTime deadline,
    required String priority,
  }) {
    return post('/tasks', {
      'title': title,
      'goal_id': goalId,
      'deadline': _formatDate(deadline),
      'priority': priority,
    });
  }

  static Future<dynamic> updateTask({
    required String id,
    required String title,
    required String goalId,
    required DateTime deadline,
    required String priority,
    required bool completed,
  }) {
    return put('/tasks/$id', {
      'title': title,
      'goal_id': goalId,
      'deadline': _formatDate(deadline),
      'priority': priority,
      'completed': completed,
    });
  }

  static Future<dynamic> toggleTask(String id) {
    return patch('/tasks/$id/complete');
  }

  static Future<dynamic> deleteTask(String id) {
    return delete('/tasks/$id');
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  static Future<Map<String, dynamic>> getStats() async {
    final data = await get('/stats');

    return Map<String, dynamic>.from(data);
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}