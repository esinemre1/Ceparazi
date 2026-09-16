import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CadTmPoint {
  final double easting;
  final double northing;
  final int dom;
  const CadTmPoint(this.easting, this.northing, this.dom);
}

CadTmPoint latLngToTm3(LatLng point, {int? forcedDom}) {
  final dom = forcedDom ?? ((point.longitude / 3).round() * 3).clamp(27, 45);
  const a = 6378137.0;
  const invF = 298.257222101;
  final f = 1 / invF;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final lat = point.latitude * math.pi / 180;
  final lon = point.longitude * math.pi / 180;
  final lon0 = dom * math.pi / 180;
  final s = math.sin(lat), c = math.cos(lat), t = math.tan(lat);
  final n = a / math.sqrt(1 - e2 * s * s);
  final tt = t * t;
  final cc = ep2 * c * c;
  final aa = c * (lon - lon0);
  final e4 = e2 * e2, e6 = e4 * e2;
  final m = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat
      - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * lat)
      + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * lat)
      - (35 * e6 / 3072) * math.sin(6 * lat));
  final e = 500000 + n * (aa + (1 - tt + cc) * math.pow(aa, 3) / 6 + (5 - 18 * tt + tt * tt + 72 * cc - 58 * ep2) * math.pow(aa, 5) / 120);
  final north = m + n * t * (aa * aa / 2 + (5 - tt + 9 * cc + 4 * cc * cc) * math.pow(aa, 4) / 24 + (61 - 58 * tt + tt * tt + 600 * cc - 330 * ep2) * math.pow(aa, 6) / 720);
  return CadTmPoint(e.toDouble(), north.toDouble(), dom);
}

double segmentLength(LatLng a, LatLng b, {int? dom}) {
  final p1 = latLngToTm3(a, forcedDom: dom);
  final p2 = latLngToTm3(b, forcedDom: dom ?? p1.dom);
  return math.sqrt(math.pow(p2.easting - p1.easting, 2) + math.pow(p2.northing - p1.northing, 2));
}

double polylineLength(List<LatLng> points) {
  if (points.length < 2) return 0;
  final dom = latLngToTm3(points.first).dom;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += segmentLength(points[i - 1], points[i], dom: dom);
  }
  return total;
}

double polygonPerimeter(List<LatLng> points) {
  if (points.length < 3) return 0;
  return polylineLength(points) + segmentLength(points.last, points.first, dom: latLngToTm3(points.first).dom);
}

double polygonArea(List<LatLng> points) {
  if (points.length < 3) return 0;
  final dom = latLngToTm3(points.first).dom;
  final tm = points.map((p) => latLngToTm3(p, forcedDom: dom)).toList();
  var sum = 0.0;
  for (var i = 0; i < tm.length; i++) {
    final a = tm[i];
    final b = tm[(i + 1) % tm.length];
    sum += a.easting * b.northing - b.easting * a.northing;
  }
  return sum.abs() / 2;
}

double azimuthDegrees(LatLng from, LatLng to) {
  final dom = latLngToTm3(from).dom;
  final a = latLngToTm3(from, forcedDom: dom);
  final b = latLngToTm3(to, forcedDom: dom);
  var az = math.atan2(b.easting - a.easting, b.northing - a.northing) * 180 / math.pi;
  if (az < 0) az += 360;
  return az;
}

LatLng? nearestSnapPoint(LatLng tap, Iterable<LatLng> candidates, {double toleranceMeters = 1.5}) {
  LatLng? best;
  var bestDistance = double.infinity;
  for (final candidate in candidates) {
    final d = segmentLength(tap, candidate);
    if (d <= toleranceMeters && d < bestDistance) {
      bestDistance = d;
      best = candidate;
    }
  }
  return best;
}
