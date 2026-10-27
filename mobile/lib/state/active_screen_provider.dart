import 'package:flutter/foundation.dart';

/// Which of the 3 tabs (Training=0/Kraft=1/Übungen=2) is shown. NOT
/// persisted — always resets to Training on app restart, matching the
/// original `activeScreen` store.
class ActiveScreenProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void set(int i) {
    if (_index == i) return;
    _index = i;
    notifyListeners();
  }
}
