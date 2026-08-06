import '../../domain/services/calendar_service_port.dart';
import '../../domain/services/share_file_service_port.dart';
import '../../services/allocation_repository.dart';
import '../../services/category_budget_repository.dart';
import '../../services/debt_repository.dart';
import '../../services/export_service.dart';
import '../../services/finance_repository.dart';
import '../../services/goal_repository.dart';
import '../../services/pdf_report_service.dart';
import '../../services/planned_expense_repository.dart';
import '../../services/real_pdf_report_service.dart';
import '../../services/share_file_service.dart';
import '../../services/smart_notification_scheduler.dart';
import '../../services/task_repository.dart';

class ReportActionsController {
  const ReportActionsController({
    ExportService exportService = const ExportService(),
    PdfReportService pdfReportService = const PdfReportService(),
    RealPdfReportService realPdfReportService = const RealPdfReportService(),
    ShareFileServicePort shareFileService = const ShareFileService(),
  })  : _exportService = exportService,
        _pdfReportService = pdfReportService,
        _realPdfReportService = realPdfReportService,
        _shareFileService = shareFileService;

  final ExportService _exportService;
  final PdfReportService _pdfReportService;
  final RealPdfReportService _realPdfReportService;
  final ShareFileServicePort _shareFileService;

  String tasksCsv(TaskRepository taskRepository) => _exportService.tasksCsv(taskRepository.tasks);

  String financeCsv(FinanceRepository financeRepository) => _exportService.transactionsCsv(financeRepository.transactions);

  String monthlyTextReport({
    required TaskRepository taskRepository,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
  }) {
    return _exportService.monthlyReport(
      tasks: taskRepository.tasks,
      financeRepository: financeRepository,
      goalRepository: goalRepository,
    );
  }

  String printableHtmlReport({
    required TaskRepository taskRepository,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
  }) {
    return _pdfReportService.buildPrintableHtml(
      tasks: taskRepository,
      finance: financeRepository,
      goals: goalRepository,
    );
  }

  Future<void> shareRealPdfReport({
    required TaskRepository taskRepository,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
  }) async {
    final bytes = await _realPdfReportService.buildMonthlyPdf(
      tasks: taskRepository,
      finance: financeRepository,
      goals: goalRepository,
    );
    final file = await _shareFileService.saveBytes(
      fileName: 'gozaresh-mah-shamsi.pdf',
      bytes: bytes,
    );
    await _shareFileService.shareFile(file, text: 'گزارش ماه شمسی دستیار روزانه ایرانی');
  }

  Future<String> calendarPreviewText(CalendarServicePort calendarService) async {
    final events = await calendarService.upcomingEvents(days: 7);
    if (events.isEmpty) return 'رویدادی پیدا نشد یا دسترسی تقویم داده نشده است.';
    return events.map((event) => '• ${event.faSummary}').join('\n');
  }

  Future<int> scheduleSmartAlerts({
    required SmartNotificationScheduler scheduler,
    required DebtRepository debtRepository,
    required PlannedExpenseRepository plannedExpenseRepository,
    required AllocationRepository allocationRepository,
    required CategoryBudgetRepository categoryBudgetRepository,
    required FinanceRepository financeRepository,
  }) {
    return scheduler.scheduleTomorrowMorningAlerts(
      debts: debtRepository,
      plannedExpenses: plannedExpenseRepository,
      allocations: allocationRepository,
      budgets: categoryBudgetRepository,
      finance: financeRepository,
    );
  }
}
