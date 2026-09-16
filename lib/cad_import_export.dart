import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cad_geometry.dart';
import 'tm3_inverse.dart';

class CadImportResult {
  final List<LatLng> vertices;
  final bool closed;
  final String format;
  const CadImportResult(this.vertices, {required this.closed, required this.format});
}

CadImportResult importKmlText(String text) {
  final matches = RegExp(r'<coordinates[^>]*>([\s\S]*?)</coordinates>', caseSensitive: false).allMatches(text);
  final points = <LatLng>[];
  for (final m in matches) {
    final body = m.group(1) ?? '';
    for (final token in body.trim().split(RegExp(r'\s+'))) {
      final p = token.split(',');
      if (p.length < 2) continue;
      final lon = double.tryParse(p[0]);
      final lat = double.tryParse(p[1]);
      if (lat != null && lon != null) points.add(LatLng(lat, lon));
    }
    if (points.isNotEmpty) break;
  }
  if (points.length > 1 && points.first.latitude == points.last.latitude && points.first.longitude == points.last.longitude) points.removeLast();
  return CadImportResult(points, closed: RegExp(r'<Polygon\b', caseSensitive: false).hasMatch(text), format: 'KML');
}

CadImportResult importDxfText(String text, int dom) {
  final rows = text.replaceAll('\r', '').split('\n');
  final points = <LatLng>[];
  var inPolyline = false;
  var closed = false;
  double? x;
  for (var i = 0; i + 1 < rows.length; i += 2) {
    final code = rows[i].trim();
    final value = rows[i + 1].trim();
    if (code == '0' && value.toUpperCase() == 'LWPOLYLINE') { inPolyline = true; x = null; continue; }
    if (inPolyline && code == '0') break;
    if (!inPolyline) continue;
    if (code == '70') {
      final flags = int.tryParse(value) ?? 0;
      closed = (flags & 1) == 1;
    } else if (code == '10') {
      x = double.tryParse(value);
    } else if (code == '20' && x != null) {
      final y = double.tryParse(value);
      if (y != null) points.add(tm3ToLatLng(x, y, dom));
      x = null;
    }
  }
  return CadImportResult(points, closed: closed, format: 'DXF');
}

String exportKml(List<LatLng> vertices, {bool closed = false, String name = 'CepArazi'}) {
  if (vertices.isEmpty) return '';
  final pts = [...vertices];
  if (closed && pts.length >= 3) pts.add(pts.first);
  final coords = pts.map((p) => '${p.longitude.toStringAsFixed(9)},${p.latitude.toStringAsFixed(9)},0').join(' ');
  final geometry = closed
      ? '<Polygon><outerBoundaryIs><LinearRing><coordinates>$coords</coordinates></LinearRing></outerBoundaryIs></Polygon>'
      : '<LineString><tessellate>1</tessellate><coordinates>$coords</coordinates></LineString>';
  return '<?xml version="1.0" encoding="UTF-8"?>\n<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>$name</name><Placemark><name>$name</name>$geometry</Placemark></Document></kml>';
}

String exportDxf(List<LatLng> vertices, {bool closed = false, int? forcedDom}) {
  if (vertices.isEmpty) return '';
  final dom = forcedDom ?? latLngToTm3(vertices.first).dom;
  final tm = vertices.map((p) => latLngToTm3(p, forcedDom: dom)).toList();
  final b = StringBuffer('0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n6\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n');
  b.write('0\nLWPOLYLINE\n100\nAcDbEntity\n8\nCEPARAZI\n100\nAcDbPolyline\n90\n${tm.length}\n70\n${closed ? 1 : 0}\n');
  for (final p in tm) { b.write('10\n${p.easting.toStringAsFixed(3)}\n20\n${p.northing.toStringAsFixed(3)}\n'); }
  b.write('0\nENDSEC\n0\nEOF\n');
  return b.toString();
}
