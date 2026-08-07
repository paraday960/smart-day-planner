import 'package:flutter/material.dart';
import '../../domain/services/voice_response_port.dart';
import '../../services/autonomous_agent_service.dart';
import '../../services/voice_response_service.dart';
import '../../services/task_repository.dart';
import '../../services/finance_repository.dart';
import '../../services/debt_repository.dart';
import '../../services/planned_expense_repository.dart';
import '../../services/allocation_repository.dart';
import '../../services/conversation_memory_service.dart';

/// هماهنگ‌کننده دستیار - تمام منطق دستیار و صدا را از HomeScreen جدا می‌کند
class AssistantCoordinator {
  AssistantCoordinator({
    required this.voiceResponseService,
    required this.autonomousAgent,
  });

  final VoiceResponsePort voiceResponseService;
  final AutonomousAgentService autonomousAgent;

  /// اجرای فرمان صوتی به صورت خودکار هیبرید
  Future<String> handleVoice({
    required String spokenText,
    required TaskRepository taskRepo,
    required FinanceRepository financeRepo,
    required DebtRepository debtRepo,
    required PlannedExpenseRepository plannedRepo,
    required AllocationRepository allocationRepo,
    required ConversationMemoryService memory,
  }) async {
    if (spokenText.trim().isEmpty) return 'چیزی تشخیص داده نشد.';
    final result = await autonomousAgent.handleAutonomously(
      rawText: spokenText,
      taskRepository: taskRepo,
      financeRepository: financeRepo,
      debtRepository: debtRepo,
      plannedExpenseRepository: plannedRepo,
      allocationRepository: allocationRepo,
      conversationMemory: memory,
    );
    final answer = result.message;
    await voiceResponseService.speak(answer);
    return answer;
  }

  /// اجرای فرمان متنی دستیار
  Future<String> handleText({
    required String prompt,
    required Future<String> Function() fallbackGenerate,
  }) async {
    if (prompt.trim().isEmpty) return 'پیامی ننوشتی.';
    // اگر فرمان اجرایی است، autonomous اول امتحان می‌شود (در HomeScreen چک می‌شود)
    return fallbackGenerate();
  }
}
