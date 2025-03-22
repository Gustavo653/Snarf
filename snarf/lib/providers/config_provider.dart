import 'package:flutter/material.dart';

class ConfigProvider with ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  Color get primaryColor => _isDarkMode ? darkPrimaryColor : lightPrimaryColor;

  Color get darkPrimaryColor => const Color(0xFF0b0951);

  Color get lightPrimaryColor => const Color(0xFFFFEBFA);

  Color get secondaryColor =>
      _isDarkMode ? darkSecondaryColor : lightSecondaryColor;

  Color get darkSecondaryColor => const Color(0xFF4c2a85);
  Color get lightSecondaryColor => const Color(0xFF6260F3);

  Color get textColor => _isDarkMode ? darkTextColor : lightTextColor;

  Color get darkTextColor => Colors.white;

  Color get lightTextColor => Colors.black;

  Color get customGreen => const Color(0xFF008000);

  Color get customOrange => const Color(0xFFFFA500);

  Color get customWhite => const Color(0xFFFFFFFF);

  Color get customBlue => const Color(0xFF0000FF);

  Color get customRed => const Color(0xFFFF0000);

  Color get iconColor => isDarkMode ? Colors.white : Colors.black;

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

  bool _hideImages = false;

  bool get hideImages => _hideImages;

  void toggleHideImages() {
    _hideImages = !_hideImages;
    notifyListeners();
  }

  bool _hideVideoCall = false;

  bool get hideVideoCall => _hideVideoCall;

  void toggleVideoCall() {
    _hideVideoCall = !_hideVideoCall;
    notifyListeners();
  }

  bool _isSubscriber = false;

  void setIsSubscriber(bool subscriber){
    _isSubscriber = subscriber;
    notifyListeners();
  }

  bool get isSubscriber => _isSubscriber;

  DateTime? _firstMessageToday;

  void setFirstMessageToday(DateTime date){
    _firstMessageToday = date;
    notifyListeners();
  }

  DateTime? get FirstMessageToday => _firstMessageToday;
}
