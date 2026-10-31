import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/services/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to light mode', () async {
    final controller = ThemeController();
    await controller.init();
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.isDark, isFalse);
  });

  test('setDark persists and notifies', () async {
    final controller = ThemeController();
    await controller.init();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setDark(true);
    expect(controller.isDark, isTrue);
    expect(controller.themeMode, ThemeMode.dark);
    expect(notified, greaterThan(0));
  });

  test('init restores persisted dark preference', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final controller = ThemeController();
    await controller.init();
    expect(controller.isDark, isTrue);
  });

  test('setDark(false) switches back to light', () async {
    final controller = ThemeController();
    await controller.init();
    await controller.setDark(true);
    await controller.setDark(false);
    expect(controller.isDark, isFalse);
  });
}