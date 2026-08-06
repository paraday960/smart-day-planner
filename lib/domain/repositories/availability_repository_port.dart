import '../../models/work_time_settings.dart';

abstract class AvailabilityRepositoryPort {
  WorkTimeSettings get settings;
  Future<void> update(WorkTimeSettings settings);
}
