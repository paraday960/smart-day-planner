import '../../models/task.dart';

abstract class TaskRepositoryPort {
  List<Task> get tasks;

  Future<void> add(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
  Future<void> togglePin(String id);
  Future<void> complete(String id, {required int actualMinutes});
  Future<void> reopen(String id);
  Future<void> replaceAll(List<Task> tasks);
}
