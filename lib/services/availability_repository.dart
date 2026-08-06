import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/availability_repository_port.dart';
import '../models/work_time_settings.dart';
import '../utils/persian_format.dart';

export '../models/work_time_settings.dart';

class AvailabilityRepository extends ChangeNotifier implements AvailabilityRepositoryPort {
  static const _storageKey = 'smart_day_planner.availability.v1';

  WorkTimeSettings _settings = WorkTimeSettings.defaultSettings;
  bool _loaded = false;

  @override
  WorkTimeSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      _settings = WorkTimeSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> update(WorkTimeSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  String todaySummary() {
    final now = DateTime.now();
    if (_settings.isOffDay(now)) return 'امروز در تنظیماتت روز غیرکاری است.';
    return 'پنجره کاری امروز: ساعت ${PersianFormat.digits(_settings.startHour)} تا ${PersianFormat.digits(_settings.endHour)}، زمان مفید تقریبی ${PersianFormat.minutes(_settings.availableMinutesFor(now))}.';
  }
}
