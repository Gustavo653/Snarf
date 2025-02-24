import 'package:flutter/material.dart';

class ConfigProvider with ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setLightTheme() {
    _isDarkMode = false;
    notifyListeners();
  }

  void setDarkTheme() {
    _isDarkMode = true;
    notifyListeners();
  }

  bool _hideImages = true;

  bool get hideImages => _hideImages;

  void toggleHideImages() {
    _hideImages = !_hideImages;
    notifyListeners();
  }
}
