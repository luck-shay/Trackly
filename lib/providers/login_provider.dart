import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class LoginProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await AuthService().signInWithGoogle();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
