const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// `2026-10-31` -> `31 Okt 2026`. Returns the input if it cannot be parsed.
String formatDate(String iso, {bool withYear = true}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final base = '${d.day} ${_months[d.month - 1]}';
  return withYear ? '$base ${d.year}' : base;
}

/// `2026-10-26`, `2026-11-01` -> `26 Okt – 1 Nov 2026`.
String formatRange(String startIso, String endIso) {
  final s = DateTime.tryParse(startIso);
  final e = DateTime.tryParse(endIso);
  if (s == null || e == null) return '$startIso – $endIso';
  return '${formatDate(startIso, withYear: false)} – ${formatDate(endIso)}';
}

/// `31 Okt 2026, 14:05` in the device's local time.
String formatDateTime(DateTime utcOrLocal) {
  final d = utcOrLocal.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hh:$mm';
}
