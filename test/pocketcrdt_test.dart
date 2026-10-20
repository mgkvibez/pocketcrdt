import 'package:test/test.dart';
import 'package:pocketcrdt/pocketcrdt.dart';

void main() {
  test('local put/get roundtrip', () {
    final m = LwwMap('a');
    m.put('k', 1);
    expect(m.get('k'), 1);
    expect(m.length, 1);
  });

  test('two replicas converge on newest write', () {
    final a = LwwMap('a');
    final b = LwwMap('b');
    a.put('k', 'from-a', at: DateTime(2026, 1, 1, 10));
    b.put('k', 'from-b', at: DateTime(2026, 1, 1, 11)); // later write wins

    b.merge(a.deltaSince(DottedVersionVector.of(b.clock)));
    a.merge(b.deltaSince(DottedVersionVector.of(a.clock)));

    expect(a.get('k'), 'from-b');
    expect(b.get('k'), 'from-b');
  });

  test('delete after sync propagates', () {
    final a = LwwMap('a');
    final b = LwwMap('b');
    a.put('k', 1, at: DateTime(2026, 1, 1));
    b.merge(a.deltaSince(DottedVersionVector()));

    a.remove('k', at: DateTime(2026, 1, 2));
    b.merge(a.deltaSince(DottedVersionVector.of(b.clock)));
    expect(b.contains('k'), isFalse);
  });

  test('concurrent delete and write: newest timestamp wins', () {
    final a = LwwMap('a');
    final b = LwwMap('b');
    a.put('k', 1, at: DateTime(2026, 1, 1));
    b.merge(a.deltaSince(DottedVersionVector()));

    a.remove('k', at: DateTime(2026, 1, 3)); // a deletes
    b.put('k', 2, at: DateTime(2026, 1, 2)); // b writes older concurrently

    final da = a.deltaSince(DottedVersionVector.of(b.clock));
    final db = b.deltaSince(DottedVersionVector.of(a.clock));
    a.merge(db);
    b.merge(da);

    expect(a.get('k'), isNull); // delete (newer) wins
    expect(b.get('k'), isNull);
  });

  test('merge is idempotent', () {
    final a = LwwMap('a');
    final b = LwwMap('b');
    a.put('k', 1, at: DateTime(2026, 1, 1));
    final delta = a.deltaSince(DottedVersionVector());
    b.merge(delta);
    b.merge(delta); // replay must not corrupt
    expect(b.get('k'), 1);
  });

  test('delta excludes already-known ops', () {
    final a = LwwMap('a');
    a.put('k', 1, at: DateTime(2026, 1, 1));
    final b = LwwMap('b');
    b.merge(a.deltaSince(DottedVersionVector()));
    final second = a.deltaSince(DottedVersionVector.of(b.clock));
    expect(second.changed.isEmpty, isTrue);
    expect(second.deleted.isEmpty, isTrue);
  });

  test('delta serializes to JSON', () {
    final a = LwwMap('a');
    a.put('k', 1, at: DateTime(2026, 1, 1));
    final json = a.deltaSince(DottedVersionVector()).toJson();
    expect(json['changed'], isA<Map>());
    expect(json['context'], isA<Map>());
  });

  test('ties break deterministically by replica id', () {
    final a = LwwMap('a');
    final b = LwwMap('b');
    a.put('k', 'a-value', at: DateTime(2026, 1, 1));
    b.put('k', 'b-value', at: DateTime(2026, 1, 1)); // same timestamp
    b.merge(a.deltaSince(DottedVersionVector.of(b.clock)));
    a.merge(b.deltaSince(DottedVersionVector.of(a.clock)));
    // 'b' > 'a', so b's value wins on both replicas
    expect(a.get('k'), 'b-value');
    expect(b.get('k'), 'b-value');
  });
}
