import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLng tm3ToLatLng(double easting, double northing, int dom) {
  if (dom < 27 || dom > 45 || dom % 3 != 0) {
    throw ArgumentError('DOM 27, 30, 33, 36, 39, 42 veya 45 olmali.');
  }
  const a = 6378137.0;
  const invF = 298.257222101;
  final f = 1 / invF;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
  final x = easting - 500000.0;
  final m = northing;
  final mu = m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));
  final j1 = 3 * e1 / 2 - 27 * math.pow(e1, 3) / 32;
  final j2 = 21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32;
  final j3 = 151 * math.pow(e1, 3) / 96;
  final j4 = 1097 * math.pow(e1, 4) / 512;
  final fp = mu + j1 * math.sin(2 * mu) + j2 * math.sin(4 * mu) + j3 * math.sin(6 * mu) + j4 * math.sin(8 * mu);
  final s = math.sin(fp), c = math.cos(fp), t = math.tan(fp);
  final c1 = ep2 * c * c;
  final t1 = t * t;
  final n1 = a / math.sqrt(1 - e2 * s * s);
  final r1 = a * (1 - e2) / math.pow(1 - e2 * s * s, 1.5);
  final d = x / n1;
  final lat = fp - (n1 * t / r1) * (d * d / 2 - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) * math.pow(d, 4) / 24 + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ep2 - 3 * c1 * c1) * math.pow(d, 6) / 720);
  final lon0 = dom * math.pi / 180;
  final lon = lon0 + (d - (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) * math.pow(d, 5) / 120) / c;
  return LatLng(lat * 180 / math.pi, lon * 180 / math.pi);
}

List<LatLng> parseTm3CoordinateText(String text, int dom) {
  final result = <LatLng>[];
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'[;,\s]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) continue;
    var start = 0;
    if (double.tryParse(parts[0].replaceAll(',', '.')) == null && parts.length >= 3) start = 1;
    final e = double.tryParse(parts[start].replaceAll(',', '.'));
    final n = start + 1 < parts.length ? double.tryParse(parts[start + 1].replaceAll(',', '.')) : null;
    if (e != null && n != null) result.add(tm3ToLatLng(e, n, dom));
  }
  return result;
}
