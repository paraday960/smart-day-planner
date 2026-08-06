import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingConversation {
  const PendingConversation({required this.type, required this.slots});

  final String type;
  final Map<String, dynamic> slots;

  Map<String, dynamic> toJson() => {'type': type, 'slots': slots};

  factory PendingConversation.fromJson(Map<String, dynamic> json) {
    return PendingConversation(
      type: json['type'] as String? ?? '',
      slots: Map<String, dynamic>.from(json['slots'] as Map? ?? {}),
    );
  }
}

class ConversationMemoryService {
  static const _pendingKey = 'smart_day_planner.conversation.pending.v1';
  static const _lastEntityKey = 'smart_day_planner.conversation.last_entity.v1';

  PendingConversation? _pending;
  Map<String, dynamic> _lastEntity = {};

  PendingConversation? get pending => _pending;
  bool get hasPending => _pending != null;
  Map<String, dynamic> get lastEntity => Map.unmodifiable(_lastEntity);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPending = prefs.getString(_pendingKey);
    if (rawPending != null && rawPending.isNotEmpty) {
      _pending = PendingConversation.fromJson(jsonDecode(rawPending) as Map<String, dynamic>);
    }

    final rawEntity = prefs.getString(_lastEntityKey);
    if (rawEntity != null && rawEntity.isNotEmpty) {
      _lastEntity = Map<String, dynamic>.from(jsonDecode(rawEntity) as Map);
    }
  }

  Future<void> setPending(String type, Map<String, dynamic> slots) async {
    _pending = PendingConversation(type: type, slots: slots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(_pending!.toJson()));
  }

  Future<void> updatePending(Map<String, dynamic> slots) async {
    final current = _pending;
    if (current == null) return;
    await setPending(current.type, {...current.slots, ...slots});
  }

  Future<void> clearPending() async {
    _pending = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<void> rememberEntity({required String type, required String id, String? title}) async {
    _lastEntity = {'type': type, 'id': id, 'title': title ?? ''};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEntityKey, jsonEncode(_lastEntity));
  }
}
