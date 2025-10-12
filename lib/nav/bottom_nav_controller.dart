import 'package:flutter/foundation.dart';

class BottomNavController extends ChangeNotifier {
  int _index = 1; // 0: connect, 1: live, 2: history

  int get index => _index;

  void setIndex(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }
}
