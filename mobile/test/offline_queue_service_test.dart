import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/services/offline_queue_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts empty and without data loaded', () async {
    final service = OfflineQueueService();
    await service.init();
    expect(service.pending, isEmpty);
    expect(service.hasEverLoadedData, isFalse);
  });

  test('addPending appends and persists across instances', () async {
    final service = OfflineQueueService();
    await service.init();
    await service.addPending(amount: 35000, expenseDate: '2026-08-25', description: 'Agua');

    expect(service.pending.length, 1);
    expect(service.pending.first['amount'], 35000);
    expect(service.pending.first['description'], 'Agua');
    expect(service.pending.first['local_id'], isNotEmpty);

    final reloaded = OfflineQueueService();
    await reloaded.init();
    expect(reloaded.pending.length, 1);
    expect(reloaded.pending.first['description'], 'Agua');
  });

  test('addPending defaults description to empty string when omitted', () async {
    final service = OfflineQueueService();
    await service.init();
    await service.addPending(amount: 1000, expenseDate: '2026-08-25');
    expect(service.pending.first['description'], '');
  });

  test('removePending removes only the matching local_id', () async {
    final service = OfflineQueueService();
    await service.init();
    await service.addPending(amount: 1000, expenseDate: '2026-08-25', description: 'A');
    await service.addPending(amount: 2000, expenseDate: '2026-08-25', description: 'B');
    final idToRemove = service.pending.first['local_id'] as String;

    await service.removePending(idToRemove);

    expect(service.pending.length, 1);
    expect(service.pending.first['description'], 'B');
  });

  test('markDataLoaded persists and is idempotent', () async {
    final service = OfflineQueueService();
    await service.init();
    expect(service.hasEverLoadedData, isFalse);

    await service.markDataLoaded();
    expect(service.hasEverLoadedData, isTrue);

    final reloaded = OfflineQueueService();
    await reloaded.init();
    expect(reloaded.hasEverLoadedData, isTrue);
  });
}
