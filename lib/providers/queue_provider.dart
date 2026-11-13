import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';
import '../storage/local_queue_storage.dart';

class QueueProvider extends ChangeNotifier {
  final QueueRepository _repository;
  final GeolocationService _geolocationService;
  final LocalQueueStorage _storage;
  final SyncService _syncService;

  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  StreamSubscription<Client>? _insertSubscription;

  QueueProvider(
    this._repository,
    this._geolocationService,
    this._storage,
    this._syncService,
  );

  List<Client> get clients => List.unmodifiable(_clients);
  QueueState get state => _state;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  int get pageSize => _pageSize;

  Future<void> fetchInitialQueue() async {
    _state = QueueState.loading;
    _page = 0;
    _hasMore = true;
    notifyListeners();
    try {
      final data = await _repository.fetchPage(offset: 0, limit: _pageSize);
      _clients.clear();
      _clients.addAll(data);
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      if (data.length < _pageSize) _hasMore = false;
    } catch (e) {
      debugPrint('fetchInitialQueue failed: $e');
      _errorMessage = 'Failed to load queue';
      _state = QueueState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      _page++;
      final newClients = await _repository.fetchPage(
        offset: _page * _pageSize,
        limit: _pageSize,
      );
      final existingIds = _clients.map((c) => c.id).toSet();
      final uniqueNewClients =
          newClients.where((c) => !existingIds.contains(c.id));
      _clients.addAll(uniqueNewClients);
      if (newClients.length < _pageSize) _hasMore = false;
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void handleRealtimeInsert(Client client) {
    final exists = _clients.any((c) => c.id == client.id);
    if (!exists) {
      _clients.insert(0, client);
      if (_state == QueueState.empty) _state = QueueState.loaded;
      notifyListeners();
    }
  }

  /// Registers the client locally first, then attempts to synchronize.
  /// Geolocation is optional: registration never fails because of GPS.
  Future<Client> registerClient(String name) async {
    Position? position;
    try {
      position = await _geolocationService.getCurrentPosition();
    } catch (_) {
      // GPS is optional and must never block a registration.
    }
    final client = Client(
      id: const Uuid().v4(),
      name: name,
      lat: position?.latitude,
      lng: position?.longitude,
      locationAccuracy: position?.accuracy,
      createdAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await _storage.saveClient(client.toLocalMap());

    _clients.insert(0, client);
    if (_state == QueueState.empty ||
        _state == QueueState.initial ||
        _state == QueueState.error) {
      _state = QueueState.loaded;
    }
    notifyListeners();

    await _syncService.synchronize();
    return client;
  }

  /// Retries pending/failed local registrations then refreshes the
  /// authoritative queue from Supabase.
  Future<void> syncPending() async {
    await _syncService.synchronize();
    await fetchInitialQueue();
  }

  void subscribeToRealtime() {
    _insertSubscription ??= _repository.insertEvents().listen(
          handleRealtimeInsert,
        );
  }

  @override
  void dispose() {
    _insertSubscription?.cancel();
    super.dispose();
  }
}
