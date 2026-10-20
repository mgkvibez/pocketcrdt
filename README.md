# pocketcrdt

**Zero-backend, offline-first CRDT sync for Flutter.** Sync app data across devices with no server, no account, no subscription — built for networks that drop out for hours.

Your Flutter app edits a local map of key-value facts. pocketcrdt versions every write with dotted version vectors and last-writer-wins timestamps, so two devices that sync over *any dumb transport* — a file, Bluetooth, a chat message, your own tiny endpoint — converge to the same state, every time, no conflicts to resolve.

```dart
import 'package:pocketcrdt/pocketcrdt.dart';

final mine = LwwMap('device-a');
final yours = LwwMap('device-b');

mine.put('cart.items', ['rice', 'beans']);
yours.put('cart.items', ['rice']); // edited offline, concurrently

// sync, in either direction, over any channel:
final delta = mine.deltaSince(DottedVersionVector.of(yours.clock));
yours.merge(delta);

// both replicas now agree — deterministic, no server round-trip
```

## Why

Existing offline sync (PowerSync, ElectricSQL) wants a cloud Postgres. Local-first CRDTs (Automerge, Yjs) are JS-first and heavy for a Flutter app. The middle is empty: a tiny pure-Dart CRDT with weak-network sync semantics, zero backend, MIT.

1. *No backend required* — deltas are plain JSON; send them however your app already moves bytes.
2. *Offline-forever* — write for hours or days; convergence happens at the next sync, not before.
3. *Deterministic* — identical edits resolve the same way on every replica (timestamp, then replica id).
4. *Tiny* — no codegen, no native bindings, no transitive deps.

## Status

v0.1 ships the LWW-map CRDT core with dotted version vectors, delta generation, tombstones, and a full property-test suite. Next: SQLite adapters (`sqflite`), a connectivity-aware outbox queue with retry/backoff for 2G/3G, and optional end-to-end encryption. See issues.

## License

MIT.
