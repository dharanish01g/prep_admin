/// Whether version [a] is newer than [b], comparing dotted numbers
/// ("1.10.0" > "1.9.2"; missing parts count as 0). Build numbers after "+"
/// are ignored.
bool isNewerVersion(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.split('+').first.trim().split('.')) int.tryParse(p) ?? 0,
  ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}
