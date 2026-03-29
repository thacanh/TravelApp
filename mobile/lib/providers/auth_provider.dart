import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _currentUser?.role == 'admin';

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register({
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
      });

      if (response.statusCode == 201) {
        // Auto login after registration
        return await login(email: email, password: password);
      }
      return false;
    } catch (e) {
      _errorMessage = 'Đăng ký thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        await _apiService.saveToken(token);
        
        // Get user info
        await getCurrentUser();
        
        _isAuthenticated = true;
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Đăng nhập thất bại: Email hoặc mật khẩu không đúng';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCurrentUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      if (response.statusCode == 200) {
        _currentUser = User.fromJson(response.data);
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final token = await _apiService.getToken();
    if (token != null) {
      await getCurrentUser();
    }
  }
}
