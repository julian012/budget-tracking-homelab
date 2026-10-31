import 'package:flutter/foundation.dart';

class ProfileController extends ChangeNotifier {
  String avatar = '';
  String displayName = '';

  void update(Map<String, dynamic> profile) {
    avatar = profile['avatar']?.toString() ?? '';
    displayName = profile['display_name']?.toString() ?? '';
    notifyListeners();
  }
}
