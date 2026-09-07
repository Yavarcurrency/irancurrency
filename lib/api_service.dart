import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = (baseUrl ?? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://irancurrency.eu.cc',
        )).replaceAll(RegExp(r'/$'), '');

  final String baseUrl;
  String? adminToken;
  String? partnerToken;

  Future<Map<String, dynamic>> getState({String? token}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/state'),
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Server ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<String> adminLogin(String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('رمز مدیر نادرست است یا سرور در دسترس نیست.');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    adminToken = data['token'] as String;
    return adminToken!;
  }

  Future<String> partnerLogin(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/partner/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('کد همکار صحیح نیست یا سرور در دسترس نیست.');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    partnerToken = data['token'] as String;
    return partnerToken!;
  }

  Future<Map<String, dynamic>> saveState(Map<String, dynamic> state) async {
    final token = adminToken;
    if (token == null) throw Exception('ابتدا وارد پنل مدیریت شوید.');
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/admin/state'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(state),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('ذخیره روی سرور ناموفق بود (${res.statusCode}).');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
