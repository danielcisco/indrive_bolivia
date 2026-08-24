import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indrive_app/core/theme/app_theme.dart';

void main() {
  test('AppTheme.light usa Material 3', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme, isA<ColorScheme>());
  });
}
