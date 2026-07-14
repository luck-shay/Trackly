import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum OnboardingStep {
  welcome,
  whyTrackly,
  appPreview,
  chooseUsername,
  chooseAppearance,
  permissions,
  ready
}

class OnboardingProvider extends ChangeNotifier {
  final PageController pageController;
  final AuthService _authService = AuthService();
  
  OnboardingStep _currentStep;
  OnboardingStep get currentStep => _currentStep;

  // Username validation state
  String _username = '';
  String get username => _username;

  bool _isCheckingUsername = false;
  bool get isCheckingUsername => _isCheckingUsername;

  bool? _isUsernameAvailable;
  bool? get isUsernameAvailable => _isUsernameAvailable;
  
  List<String> _usernameSuggestions = [];
  List<String> get usernameSuggestions => _usernameSuggestions;

  Timer? _debounceTimer;

  OnboardingProvider({required OnboardingStep startStep})
      : _currentStep = startStep,
        pageController = PageController(initialPage: startStep.index);

  @override
  void dispose() {
    pageController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void nextStep() {
    if (_currentStep.index < OnboardingStep.values.length - 1) {
      _currentStep = OnboardingStep.values[_currentStep.index + 1];
      _animateToCurrentStep();
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep.index > 0) {
      _currentStep = OnboardingStep.values[_currentStep.index - 1];
      _animateToCurrentStep();
      notifyListeners();
    }
  }

  void goToStep(OnboardingStep step) {
    _currentStep = step;
    _animateToCurrentStep();
    notifyListeners();
  }

  void _animateToCurrentStep() {
    pageController.animateToPage(
      _currentStep.index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );
  }

  void setUsername(String value) {
    final cleaned = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (_username == cleaned) return;
    
    _username = cleaned;
    _isUsernameAvailable = null;
    _usernameSuggestions = [];
    notifyListeners();

    if (_username.length < 3) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(_username);
    });
  }
  
  void selectSuggestion(String suggestion) {
    _username = suggestion;
    _isUsernameAvailable = true;
    _usernameSuggestions = [];
    notifyListeners();
  }

  Future<void> _checkUsernameAvailability(String usernameToCheck) async {
    _isCheckingUsername = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: usernameToCheck)
          .get();

      // If it's empty, or the only match is the current user themselves
      _isUsernameAvailable = snapshot.docs.isEmpty || 
        (snapshot.docs.length == 1 && user != null && snapshot.docs.first.id == user.uid);
      
      if (_isUsernameAvailable == false && user != null) {
        _generateSuggestions(usernameToCheck, user.uid);
      }
    } catch (e) {
      debugPrint('Error checking username: $e');
      _isUsernameAvailable = null;
    } finally {
      _isCheckingUsername = false;
      notifyListeners();
    }
  }
  
  void _generateSuggestions(String base, String uid) {
    final shortUid = uid.length >= 4 ? uid.substring(uid.length - 4) : '1234';
    _usernameSuggestions = [
      '${base}_$shortUid',
      '${base}app',
      'the$base',
    ];
  }

  Future<void> saveUsernameAndContinue() async {
    if (_username.length < 3 || _isUsernameAvailable != true) {
      return; // Can't proceed
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'username': _username});
      nextStep();
    } catch (e) {
      debugPrint('Error saving username: $e');
    }
  }

  Future<void> completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _authService.completeOnboarding(user.uid);
    }
  }
}
