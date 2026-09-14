import 'package:flutter/material.dart';

class AppRadius {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double circular = 999.0;

  static const BorderRadius small = BorderRadius.all(Radius.circular(s));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(m));
  static const BorderRadius large = BorderRadius.all(Radius.circular(l));
  static const BorderRadius round = BorderRadius.all(Radius.circular(circular));
}
