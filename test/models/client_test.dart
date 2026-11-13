import 'package:flutter_test/flutter_test.dart';
import 'package:tp6/models/client.dart';
import 'package:tp6/models/sync_status.dart';

void main() {
  group('Client Model Tests', () {
    test('client without location reports hasLocation as false', () {
      final client = Client(
        id: '1',
        name: 'Test Client',
        createdAt: DateTime.now(),
      );

      expect(client.hasLocation, isFalse);
      expect(client.locationText, equals('Location not captured'));
    });

    test('toLocalMap preserves accuracy and syncStatus', () {
      final client = Client(
        id: '1',
        name: 'Test Client',
        lat: 36.8065,
        lng: 10.1815,
        locationAccuracy: 5.5,
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );

      final map = client.toLocalMap();
      expect(map['location_accuracy_m'], equals(5.5));
      expect(map['sync_status'], equals('pending'));
    });

    test('toSupabaseMap excludes local sync_status', () {
      final client = Client(
        id: '1',
        name: 'Test Client',
        createdAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );

      final map = client.toSupabaseMap();
      expect(map.containsKey('sync_status'), isFalse);
    });

    test('fromSupabaseMap restores business fields and marks synced', () {
      final map = {
        'id': 'abc',
        'name': 'Alice',
        'lat': 36.8,
        'lng': 10.18,
        'location_accuracy_m': 7,
        'created_at': '2026-01-01T10:00:00.000Z',
      };

      final client = Client.fromSupabaseMap(map);

      expect(client.id, equals('abc'));
      expect(client.name, equals('Alice'));
      expect(client.lat, equals(36.8));
      expect(client.lng, equals(10.18));
      expect(client.locationAccuracy, equals(7.0));
      expect(client.syncStatus, equals(SyncStatus.synced));
      expect(client.hasLocation, isTrue);
    });

    test('fromSupabaseMap tolerates missing location fields', () {
      final map = {
        'id': 'abc',
        'name': 'Alice',
        'created_at': '2026-01-01T10:00:00.000Z',
      };

      final client = Client.fromSupabaseMap(map);

      expect(client.hasLocation, isFalse);
      expect(client.syncStatus, equals(SyncStatus.synced));
    });

    test('fromLocalMap falls back to pending for unknown status', () {
      final map = {
        'id': 'x',
        'name': 'Bob',
        'created_at': '2026-01-01T10:00:00.000Z',
        'sync_status': 'unknown_status',
      };

      final client = Client.fromLocalMap(map);

      expect(client.syncStatus, equals(SyncStatus.pending));
    });

    test('toLocalMap / fromLocalMap roundtrip keeps pending status', () {
      final client = Client(
        id: '2',
        name: 'Bob',
        lat: 1.5,
        lng: 2.5,
        locationAccuracy: 3.5,
        createdAt: DateTime(2026, 2, 2),
        syncStatus: SyncStatus.failed,
      );

      final restored = Client.fromLocalMap(client.toLocalMap());

      expect(restored.id, equals(client.id));
      expect(restored.name, equals(client.name));
      expect(restored.lat, equals(client.lat));
      expect(restored.locationAccuracy, equals(client.locationAccuracy));
      expect(restored.syncStatus, equals(SyncStatus.failed));
      expect(restored.createdAt, equals(client.createdAt));
    });
  });
}
