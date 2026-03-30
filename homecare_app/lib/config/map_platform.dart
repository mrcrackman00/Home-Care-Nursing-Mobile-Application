import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppMapPlatform {
  const AppMapPlatform._();

  static bool get supportsGoogleMaps =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
