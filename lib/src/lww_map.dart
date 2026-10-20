/// Last-Writer-Wins element map with dotted version vectors.
///
/// Replicas can edit offline forever; on sync, every key resolves to the edit
/// with the highest (timestamp, replicaId) pair. No conflicts, no coordination.
library;

import 'dotted_version.dart';

class _Stamp {
  final DateTime timestamp;
  final String replicaId;
  final Dot dot;
  const _Stamp(this.timestamp, this.replicaId, this.dot);
}

class _Entry extends _Stamp {
  final dynamic value;
  _Entry(this.value, DateTime ts, String rid, Dot dot) : super(ts, rid, dot);
}

class _Tombstone extends _Stamp {
  _Tombstone(DateTime ts, String rid, Dot dot) : super(ts, rid, dot);
}

class LwwMapDelta {
  /// Entries created or changed since the last delta the remote had.
  final Map<String, Map<String, dynamic>> changed;

  /// Keys deleted since the last delta the remote had.
  final List<Map<String, dynamic>> deleted;

  /// The version context these changes ride on.
  final Map<String, int> context;

  LwwMapDelta(this.changed, this.deleted, this.context);

  Map<String, dynamic> toJson() => {
        'changed': changed,
        'deleted': deleted,
        'context': context,
      };
}

class LwwMap {
  final String replicaId;
  final Map<String, _Entry> _entries = {};
  final Map<String, _Tombstone> _tombstones = {};
  final DottedVersionVector _clock = DottedVersionVector();
  int _opCounter = 0;

  LwwMap(this.replicaId);

  void put(String key, dynamic value, {DateTime? at}) {
    _opCounter++;
    _clock.observe(replicaId, _opCounter);
    final stamp = at ?? DateTime.now();
    _entries[key] = _Entry(value, stamp, replicaId, Dot(replicaId, _opCounter));
    _tombstones.remove(key);
  }

  void remove(String key, {DateTime? at}) {
    _opCounter++;
    _clock.observe(replicaId, _opCounter);
    final stamp = at ?? DateTime.now();
    _tombstones[key] = _Tombstone(stamp, replicaId, Dot(replicaId, _opCounter));
    _entries.remove(key);
  }

  dynamic get(String key) => _entries[key]?.value;

  bool contains(String key) => _entries.containsKey(key);

  Iterable<String> get keys => _entries.keys;

  int get length => _entries.length;

  Map<String, int> get clock => _clock.snapshot();

  bool _wins(_Stamp incoming, _Stamp current) {
    if (incoming.timestamp != current.timestamp) {
      return incoming.timestamp.isAfter(current.timestamp);
    }
    return incoming.replicaId.compareTo(current.replicaId) > 0;
  }

  void _applyChange(String key, Map<String, dynamic> raw) {
    final incoming = _Entry(
      raw['value'],
      DateTime.parse(raw['ts'] as String),
      raw['rid'] as String,
      Dot(raw['rid'] as String, raw['ctr'] as int),
    );
    _clock.observe(incoming.replicaId, incoming.dot.counter);
    final current = _entries[key];
    final tomb = _tombstones[key];
    final beatenByTomb = tomb != null && !_wins(incoming, tomb);
    final beatenByEntry = current != null && !_wins(incoming, current);
    if (beatenByTomb || beatenByEntry) return;
    _entries[key] = incoming;
    _tombstones.remove(key);
  }

  void _applyDelete(Map<String, dynamic> raw) {
    final key = raw['key'] as String;
    final tomb = _Tombstone(
      DateTime.parse(raw['ts'] as String),
      raw['rid'] as String,
      Dot(raw['rid'] as String, raw['ctr'] as int),
    );
    _clock.observe(tomb.replicaId, tomb.dot.counter);
    final current = _entries[key];
    if (current == null || _wins(tomb, current)) {
      _entries.remove(key);
      _tombstones[key] = tomb;
    }
  }

  /// Merge a delta from another replica. Idempotent, commutative, associative.
  void merge(LwwMapDelta delta) {
    delta.context.forEach((id, count) => _clock.observe(id, count));
    delta.changed.forEach(_applyChange);
    for (final raw in delta.deleted) {
      _applyDelete(raw);
    }
  }

  /// Build a delta for a peer whose clock is at [known].
  LwwMapDelta deltaSince(DottedVersionVector known) {
    final changed = <String, Map<String, dynamic>>{};
    final deleted = <Map<String, dynamic>>[];
    _entries.forEach((key, entry) {
      if (!known.hasObserved(entry.replicaId, entry.dot.counter)) {
        changed[key] = _encodeEntry(entry);
      }
    });
    _tombstones.forEach((key, tomb) {
      if (!known.hasObserved(tomb.replicaId, tomb.dot.counter)) {
        deleted.add(_encodeTomb(key, tomb));
      }
    });
    return LwwMapDelta(changed, deleted, _clock.snapshot());
  }

  Map<String, dynamic> _encodeEntry(_Entry e) => {
        'value': e.value,
        'ts': e.timestamp.toIso8601String(),
        'rid': e.replicaId,
        'ctr': e.dot.counter,
      };

  Map<String, dynamic> _encodeTomb(String key, _Tombstone t) => {
        'key': key,
        'ts': t.timestamp.toIso8601String(),
        'rid': t.replicaId,
        'ctr': t.dot.counter,
      };
}
