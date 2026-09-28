import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Node.js backend
  static const String baseUrl = 'http://127.0.0.1:8001';

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
      },
    );

    return _handleResponse(response);
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> patch(String endpoint) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
      },
    );

    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
      },
    );

    return _handleResponse(response);
  }

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

    throw Exception(
      '$message (Status: ${response.statusCode})',
    );
  }

  // -------------------------
  // CONNECTION TEST
  // -------------------------

  static Future<bool> testConnection() async {
    try {
      final data = await get('/hello');

      return data is Map &&
          data['message'] == 'Hello from Node.js!';
    } catch (_) {
      return false;
    }
  }

  // -------------------------
  // GOALS
  // -------------------------

  static Future<List<dynamic>> getGoals() async {
    final data = await get('/goals');

    return List<dynamic>.from(data);
  }

  static Future<dynamic> createGoal({
    required String title,
    required String description,
    required DateTime deadline,
  }) {
    return post(
      '/goals',
      {
        'title': title,
        'description': description,
        'deadline': _formatDate(deadline),
      },
    );
  }

  static Future<dynamic> updateGoal({
    required String id,
    required String title,
    required String description,
    required DateTime deadline,
  }) {
    return put(
      '/goals/$id',
      {
        'title': title,
        'description': description,
        'deadline': _formatDate(deadline),
      },
    );
  }

  static Future<dynamic> deleteGoal(String id) {
    return delete('/goals/$id');
  }

  // -------------------------
  // TASKS
  // -------------------------

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
    return post(
      '/tasks',
      {
        'title': title,
        'goal_id': goalId,
        'deadline': _formatDate(deadline),
        'priority': priority,
      },
    );
  }

  static Future<dynamic> updateTask({
    required String id,
    required String title,
    required String goalId,
    required DateTime deadline,
    required String priority,
    required bool completed,
  }) {
    return put(
      '/tasks/$id',
      {
        'title': title,
        'goal_id': goalId,
        'deadline': _formatDate(deadline),
        'priority': priority,
        'completed': completed,
      },
    );
  }

  static Future<dynamic> toggleTask(String id) {
    return patch('/tasks/$id/complete');
  }

  static Future<dynamic> deleteTask(String id) {
    return delete('/tasks/$id');
  }

  // -------------------------
  // STATISTICS
  // -------------------------

  static Future<Map<String, dynamic>> getStats() async {
    final data = await get('/stats');

    return Map<String, dynamic>.from(data);
  }

  // -------------------------
  // DATE FORMAT
  // -------------------------

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}