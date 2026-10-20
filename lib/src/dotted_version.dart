/// Dotted version vectors: who saw which operations, without vector-clock math
/// leaking into user code.
library;

/// A map of replica id -> highest operation counter that replica has *observed*.
/// Dots (single op ids) are (replicaId, counter) pairs.
class DottedVersionVector {
  final Map<String, int> _counters = {};

  DottedVersionVector();
  DottedVersionVector.of(Map<String, int> counters) {
    _counters.addAll(counters);
  }

  Map<String, int> snapshot() => Map.unmodifiable(_counters);

  int counterOf(String replicaId) => _counters[replicaId] ?? 0;

  /// Observe an op: never goes backwards.
  void observe(String replicaId, int counter) {
    final current = _counters[replicaId] ?? 0;
    if (counter > current) _counters[replicaId] = counter;
  }

  /// Pointwise max with another clock.
  void merge(DottedVersionVector other) {
    other._counters.forEach((id, count) => observe(id, count));
  }

  bool hasObserved(String replicaId, int counter) => counter <= counterOf(replicaId);
}

/// A single causal stamp: "op #counter by replicaId".
class Dot {
  final String replicaId;
  final int counter;
  const Dot(this.replicaId, this.counter);
}
