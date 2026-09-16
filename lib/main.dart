import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const CepAraziApp());

class CepAraziApp extends StatelessWidget {
  const CepAraziApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CepArazi',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)), useMaterial3: true),
        home: const MapPage(),
      );
}

class TmPoint {
  final double e, n;
  final int dom;
  const TmPoint(this.e, this.n, this.dom);
}

TmPoint toTm3(double latDeg, double lonDeg) {
  final dom = ((lonDeg / 3).round() * 3).clamp(27, 45);
  const a = 6378137.0;
  const invF = 298.257222101;
  final f = 1 / invF;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final lat = latDeg * math.pi / 180;
  final lon = lonDeg * math.pi / 180;
  final lon0 = dom * math.pi / 180;
  final s = math.sin(lat), c = math.cos(lat), t = math.tan(lat);
  final nn = a / math.sqrt(1 - e2 * s * s);
  final tt = t * t;
  final cc = ep2 * c * c;
  final aa = c * (lon - lon0);
  final e4 = e2 * e2, e6 = e4 * e2;
  final m = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat
      - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * lat)
      + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * lat)
      - (35 * e6 / 3072) * math.sin(6 * lat));
  final easting = 500000 + nn * (aa + (1 - tt + cc) * math.pow(aa, 3) / 6 + (5 - 18 * tt + tt * tt + 72 * cc - 58 * ep2) * math.pow(aa, 5) / 120);
  final northing = m + nn * t * (aa * aa / 2 + (5 - tt + 9 * cc + 4 * cc * cc) * math.pow(aa, 4) / 24 + (61 - 58 * tt + tt * tt + 600 * cc - 330 * ep2) * math.pow(aa, 6) / 720);
  return TmPoint(easting.toDouble(), northing.toDouble(), dom);
}

class SavedPoint {
  final int no;
  final DateTime time;
  final Position pos;
  final TmPoint tm;
  SavedPoint(this.no, this.time, this.pos, this.tm);
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? _pos;
  TmPoint? _tm;
  final List<SavedPoint> _points = [];
  final List<LatLng> _line = [];
  final _eCtrl = TextEditingController();
  final _nCtrl = TextEditingController();
  bool _busy = false;
  bool _drawing = false;
  MapType _mapType = MapType.satellite;
  GoogleMapController? _map;

  @override
  void initState() { super.initState(); _locate(); }

  Future<void> _locate() async {
    setState(() => _busy = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('Konum izni gerekli');
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Telefon konum servisini ac');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)));
      final tm = toTm3(pos.latitude, pos.longitude);
      setState(() { _pos = pos; _tm = tm; });
      _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 19));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  void _savePoint() {
    if (_pos == null || _tm == null) return;
    setState(() => _points.add(SavedPoint(_points.length + 1, DateTime.now(), _pos!, _tm!)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('N${_points.length} kaydedildi • ±${_pos!.accuracy.toStringAsFixed(2)} m')));
  }

  void _onMapTap(LatLng p) {
    if (!_drawing) return;
    setState(() => _line.add(p));
  }

  void _undoLinePoint() {
    if (_line.isNotEmpty) setState(() => _line.removeLast());
  }

  void _clearLine() => setState(() => _line.clear());

  Future<void> _exportKml() async {
    if (_line.length < 2) return;
    final coords = _line.map((p) => '${p.longitude.toStringAsFixed(9)},${p.latitude.toStringAsFixed(9)},0').join(' ');
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>CepArazi Cizgi</name><Placemark><name>Cizgi</name><LineString><tessellate>1</tessellate><coordinates>$coords</coordinates></LineString></Placemark></Document></kml>''';
    await _shareTextFile('ceparazi_cizgi.kml', kml, 'application/vnd.google-earth.kml+xml');
  }

  Future<void> _exportDxf() async {
    if (_line.length < 2) return;
    final tm = _line.map((p) => toTm3(p.latitude, p.longitude)).toList();
    final doms = tm.map((p) => p.dom).toSet();
    if (doms.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DXF icin cizgi tek bir ITRF/TM3 DOM icinde olmali.')));
      return;
    }
    final b = StringBuffer();
    b.write('0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n6\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n');
    b.write('0\nLWPOLYLINE\n100\nAcDbEntity\n8\nCEPARAZI\n100\nAcDbPolyline\n90\n${tm.length}\n70\n0\n');
    for (final p in tm) {
      b.write('10\n${p.e.toStringAsFixed(3)}\n20\n${p.n.toStringAsFixed(3)}\n');
    }
    b.write('0\nENDSEC\n0\nEOF\n');
    await _shareTextFile('ceparazi_itrf_tm3_dom${tm.first.dom}.dxf', b.toString(), 'application/dxf');
  }

  Future<void> _shareTextFile(String name, String text, String mime) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: mime)], subject: name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disa aktarma hatasi: $e')));
    }
  }

  void _showMapTools() => showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: Icon(_drawing ? Icons.edit_off : Icons.polyline), title: Text(_drawing ? 'Cizimi Bitir' : 'Cizgi Ciz'), subtitle: const Text('Haritaya dokunarak kirik cizgi olustur'), onTap: () { Navigator.pop(ctx); setState(() => _drawing = !_drawing); }),
      ListTile(leading: const Icon(Icons.undo), title: const Text('Son Koseyi Geri Al'), enabled: _line.isNotEmpty, onTap: () { Navigator.pop(ctx); _undoLinePoint(); }),
      ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Cizgiyi Temizle'), enabled: _line.isNotEmpty, onTap: () { Navigator.pop(ctx); _clearLine(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.public), title: const Text('KML Olarak Disa Aktar'), subtitle: const Text('WGS84 enlem/boylam'), enabled: _line.length >= 2, onTap: () { Navigator.pop(ctx); _exportKml(); }),
      ListTile(leading: const Icon(Icons.architecture), title: const Text('DXF Olarak Disa Aktar'), subtitle: Text(_line.isEmpty ? 'ITRF / TM3 metre koordinati' : 'ITRF / TM3 • DOM ${toTm3(_line.first.latitude, _line.first.longitude).dom}°'), enabled: _line.length >= 2, onTap: () { Navigator.pop(ctx); _exportDxf(); }),
    ]),
  )));

  void _stakeout() {
    if (_tm == null) return;
    final te = double.tryParse(_eCtrl.text.replaceAll(',', '.'));
    final tn = double.tryParse(_nCtrl.text.replaceAll(',', '.'));
    if (te == null || tn == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hedef Y ve X koordinatini gir'))); return; }
    final de = te - _tm!.e, dn = tn - _tm!.n;
    final d = math.sqrt(de * de + dn * dn);
    var az = math.atan2(de, dn) * 180 / math.pi; if (az < 0) az += 360;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Aplikasyon', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
        Text('Mesafe: ${d.toStringAsFixed(3)} m', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Azimut: ${az.toStringAsFixed(4)}°'), Text('Dogu farki: ${de.toStringAsFixed(3)} m'), Text('Kuzey farki: ${dn.toStringAsFixed(3)} m'),
        const SizedBox(height: 8), Text('Telefon GNSS dogrulugu: ±${_pos?.accuracy.toStringAsFixed(2)} m'),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _pos; final tm = _tm;
    final markers = <Marker>{for (final x in _points) Marker(markerId: MarkerId('p${x.no}'), position: LatLng(x.pos.latitude, x.pos.longitude), infoWindow: InfoWindow(title: 'N${x.no}', snippet: 'Y ${x.tm.e.toStringAsFixed(3)}  X ${x.tm.n.toStringAsFixed(3)}'))};
    final polylines = <Polyline>{if (_line.length >= 2) Polyline(polylineId: const PolylineId('drawn_line'), points: _line, width: 5, color: Colors.orange)};
    return Scaffold(
      appBar: AppBar(title: const Text('CepArazi'), actions: [
        IconButton(tooltip: 'Harita araclari', onPressed: _showMapTools, icon: Badge(isLabelVisible: _line.isNotEmpty, label: Text('${_line.length}'), child: Icon(_drawing ? Icons.polyline : Icons.map_outlined))),
        IconButton(tooltip: 'Harita tipi', onPressed: () => setState(() => _mapType = _mapType == MapType.satellite ? MapType.hybrid : MapType.satellite), icon: const Icon(Icons.layers_outlined)),
        IconButton(tooltip: 'Konum yenile', onPressed: _busy ? null : _locate, icon: const Icon(Icons.my_location)),
      ]),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(38.0, 33.0), zoom: 6), mapType: _mapType,
          myLocationEnabled: p != null, myLocationButtonEnabled: false, compassEnabled: true, zoomControlsEnabled: false,
          markers: markers, polylines: polylines, onTap: _onMapTap,
          onMapCreated: (c) { _map = c; if (p != null) c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 19)); },
        ),
        if (_drawing) Positioned(left: 12, right: 12, top: 12, child: Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [const Icon(Icons.polyline), const SizedBox(width: 8), Expanded(child: Text('Cizim modu • Haritaya dokun (${_line.length} kose)')), IconButton(onPressed: _undoLinePoint, icon: const Icon(Icons.undo)), TextButton(onPressed: () => setState(() => _drawing = false), child: const Text('BITIR'))])))),
        if (!_drawing) Positioned(left: 12, right: 12, top: 12, child: Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(12), child: tm == null
          ? Text(_busy ? 'GNSS konumu aliniyor…' : 'Konum bekleniyor')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Icon(Icons.gps_fixed, size: 18), const SizedBox(width: 6), Text('ITRF / TM3  DOM ${tm.dom}°', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('±${p!.accuracy.toStringAsFixed(1)} m')]),
              const SizedBox(height: 5), Text('Y (Dogu): ${tm.e.toStringAsFixed(3)} m'), Text('X (Kuzey): ${tm.n.toStringAsFixed(3)} m'),
              Text('Enlem ${p.latitude.toStringAsFixed(8)}°  Boylam ${p.longitude.toStringAsFixed(8)}°', style: Theme.of(context).textTheme.bodySmall),
            ])))),
        Positioned(left: 12, right: 12, bottom: 16, child: Card(elevation: 6, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: FilledButton.icon(onPressed: p == null ? null : _savePoint, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Nokta Al'))),
          const SizedBox(width: 8), Expanded(child: FilledButton.tonalIcon(onPressed: tm == null ? null : _showStakeoutInput, icon: const Icon(Icons.navigation_outlined), label: const Text('Aplikasyon'))),
          const SizedBox(width: 4), IconButton(tooltip: 'Noktalar', onPressed: _points.isEmpty ? null : _showPoints, icon: Badge(label: Text('${_points.length}'), child: const Icon(Icons.list_alt))),
        ])))),
      ]),
    );
  }

  void _showStakeoutInput() => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
    padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Hedef Koordinat • DOM ${_tm?.dom}°', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 14),
      TextField(controller: _eCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Y / Dogu (m)', border: OutlineInputBorder())), const SizedBox(height: 10),
      TextField(controller: _nCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'X / Kuzey (m)', border: OutlineInputBorder())), const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () { Navigator.pop(ctx); _stakeout(); }, child: const Text('Aplikasyonu Hesapla'))),
    ]),
  ));

  void _showPoints() => showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
    const ListTile(title: Text('Alinan Noktalar', style: TextStyle(fontWeight: FontWeight.bold))),
    for (final x in _points.reversed) ListTile(leading: CircleAvatar(child: Text('${x.no}')), title: Text('Y ${x.tm.e.toStringAsFixed(3)}   X ${x.tm.n.toStringAsFixed(3)}'), subtitle: Text('DOM ${x.tm.dom}° • ±${x.pos.accuracy.toStringAsFixed(2)} m'), onTap: () { Navigator.pop(ctx); _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(x.pos.latitude, x.pos.longitude), 20)); }),
  ]));
}
