import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_providers.dart';

class QueuedOperation {
  final String id;
  final String type; // 'insert', 'update', 'delete'
  final String table;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.table,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'table': table,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QueuedOperation.fromMap(Map<dynamic, dynamic> map) {
    return QueuedOperation(
      id: map['id'] as String,
      type: map['type'] as String,
      table: map['table'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

class SyncManager extends StateNotifier<List<QueuedOperation>> {
  final Ref _ref;
  final Box _queueBox = Hive.box('offline_queue_box');
  bool _isSyncing = false;
  Timer? _timer;

  SyncManager(this._ref) : super([]) {
    _loadQueue();
    // Replay queue periodically (every 30 seconds)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => replayQueue());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadQueue() {
    final list = _queueBox.values.map((val) {
      return QueuedOperation.fromMap(Map<dynamic, dynamic>.from(val as Map));
    }).toList();
    // Sort by timestamp to preserve order
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = list;
  }

  Future<void> queueOperation({
    required String type,
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final op = QueuedOperation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      table: table,
      payload: payload,
      timestamp: DateTime.now(),
    );
    await _queueBox.put(op.id, op.toMap());
    state = [...state, op];
    
    // Try to replay in background
    replayQueue();
  }

  Future<void> replayQueue() async {
    if (_isSyncing || state.isEmpty) return;
    _isSyncing = true;

    final supabase = _ref.read(supabaseClientProvider);

    // Process a copy of the queue to prevent concurrent modification
    final queue = List<QueuedOperation>.from(state);

    for (final op in queue) {
      try {
        if (op.type == 'insert') {
          await supabase.from(op.table).insert(op.payload);
        } else if (op.type == 'update') {
          final id = op.payload['id'];
          if (id != null) {
            await supabase.from(op.table).update(op.payload).eq('id', id);
          }
        } else if (op.type == 'delete') {
          final id = op.payload['id'];
          if (id != null) {
            await supabase.from(op.table).delete().eq('id', id);
          }
        }
        
        // Success: remove from queue
        await _queueBox.delete(op.id);
        state = state.where((item) => item.id != op.id).toList();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        // Network/Connection error checks
        if (e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network'))) {
          break; // network error, retry later
        }
        if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed')) {
          break; // network error, retry later
        }
        
        // Logical/validation constraint error: remove from queue to prevent blockages
        await _queueBox.delete(op.id);
        state = state.where((item) => item.id != op.id).toList();
      }
    }

    _isSyncing = false;
  }
}

final syncManagerProvider = StateNotifierProvider<SyncManager, List<QueuedOperation>>((ref) {
  return SyncManager(ref);
});
