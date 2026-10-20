/// pocketcrdt — zero-backend, offline-first CRDT sync for Flutter apps.
///
/// Offline edits are kept as plain (key, value, timestamp) facts with dotted
/// version vectors. Two replicas that sync via any dumb transport (Bluetooth,
/// a file, a Telegram message, your own HTTP endpoint) converge to the same
/// state without conflicts or a server.
library;

export 'src/dotted_version.dart';
export 'src/lww_map.dart';
