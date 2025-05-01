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

  List<bool> _statisticsList = List.filled(5, false);
  bool getStatistic(int index) => _statisticsList[index];

  void toggleStatistic(int index){
    _statisticsList[index] = !_statisticsList[index];
    notifyListeners();
  }

  List<bool> _sexualityList = List.filled(3, false);
  bool getSexuality(int index) => _sexualityList[index];

  void toggleSexuality(int index){
    _sexualityList[index] = !_sexualityList[index];
    notifyListeners();
  }

  List<bool> _sceneList = List.filled(7, false);
  bool getScene(int index) => _sceneList[index];

  void toggleScene(int index){
    _sceneList[index] = !_sceneList[index];
    notifyListeners();
  }

  List<bool> _preferencesList = List.filled(7, false);
  bool getPreferences(int index) => _preferencesList[index];

  void togglePreferences(int index){
    _preferencesList[index] = !_preferencesList[index];
    notifyListeners();
  }

  bool _isSubscriber = false;

  void setIsSubscriber(bool subscriber){
    _isSubscriber = subscriber;
    notifyListeners();
  }

  bool get isSubscriber => _isSubscriber;

  int _countNotificationMessage = 0;

  int get countNotificationMessage => _countNotificationMessage;

  void AddNotificationMessage(){
    _countNotificationMessage ++;
    notifyListeners();
  }

  void ClearNotification(){
    _countNotificationMessage = 0;
    notifyListeners();
  }

  DateTime? _firstMessageToday;

  void setFirstMessageToday(DateTime date){
    _firstMessageToday = date;
    notifyListeners();
  }

  DateTime? get FirstMessageToday => _firstMessageToday;
}
