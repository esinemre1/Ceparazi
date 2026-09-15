import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

// GRS80, 3 derece Transverse Mercator (ITRF/TM3 pratik gosterim).
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
  final N = a / math.sqrt(1 - e2 * s * s);
  final T = t * t;
  final C = ep2 * c * c;
  final A = c * (lon - lon0);
  final e4 = e2 * e2, e6 = e4 * e2;
  final M = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat
      - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * lat)
      + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * lat)
      - (35 * e6 / 3072) * math.sin(6 * lat));
  final easting = 500000 + N * (A + (1 - T + C) * math.pow(A, 3) / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * math.pow(A, 5) / 120);
  final northing = M + N * t * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * math.pow(A, 4) / 24 + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * math.pow(A, 6) / 720);
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
  final _eCtrl = TextEditingController();
  final _nCtrl = TextEditingController();
  bool _busy = false;
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
        Text('Azimut: ${az.toStringAsFixed(4)}°'), Text('Doğu farkı: ${de.toStringAsFixed(3)} m'), Text('Kuzey farkı: ${dn.toStringAsFixed(3)} m'),
        const SizedBox(height: 8), Text('Telefon GNSS doğruluğu: ±${_pos?.accuracy.toStringAsFixed(2)} m'),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _pos; final tm = _tm;
    final markers = <Marker>{
      for (final x in _points) Marker(markerId: MarkerId('p${x.no}'), position: LatLng(x.pos.latitude, x.pos.longitude), infoWindow: InfoWindow(title: 'N${x.no}', snippet: 'Y ${x.tm.e.toStringAsFixed(3)}  X ${x.tm.n.toStringAsFixed(3)}'))
    };
    return Scaffold(
      appBar: AppBar(title: const Text('CepArazi'), actions: [
        IconButton(tooltip: 'Harita tipi', onPressed: () => setState(() => _mapType = _mapType == MapType.satellite ? MapType.hybrid : MapType.satellite), icon: const Icon(Icons.layers_outlined)),
        IconButton(tooltip: 'Konum yenile', onPressed: _busy ? null : _locate, icon: const Icon(Icons.my_location)),
      ]),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(38.0, 33.0), zoom: 6),
          mapType: _mapType, myLocationEnabled: p != null, myLocationButtonEnabled: false, compassEnabled: true, zoomControlsEnabled: false,
          markers: markers, onMapCreated: (c) { _map = c; if (p != null) c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 19)); },
        ),
        Positioned(left: 12, right: 12, top: 12, child: Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(12), child: tm == null
          ? Text(_busy ? 'GNSS konumu alınıyor…' : 'Konum bekleniyor')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Icon(Icons.gps_fixed, size: 18), const SizedBox(width: 6), Text('ITRF / TM3  DOM ${tm.dom}°', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('±${p!.accuracy.toStringAsFixed(1)} m')]),
              const SizedBox(height: 5), Text('Y (Doğu): ${tm.e.toStringAsFixed(3)} m'), Text('X (Kuzey): ${tm.n.toStringAsFixed(3)} m'),
              Text('Enlem ${p.latitude.toStringAsFixed(8)}°  Boylam ${p.longitude.toStringAsFixed(8)}°', style: Theme.of(context).textTheme.bodySmall),
            ]))),
        ),
        Positioned(left: 12, right: 12, bottom: 16, child: Card(elevation: 6, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: FilledButton.icon(onPressed: p == null ? null : _savePoint, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Nokta Al'))),
          const SizedBox(width: 8), Expanded(child: FilledButton.tonalIcon(onPressed: tm == null ? null : _showStakeoutInput, icon: const Icon(Icons.navigation_outlined), label: const Text('Aplikasyon'))),
          const SizedBox(width: 4), IconButton(tooltip: 'Noktalar', onPressed: _points.isEmpty ? null : _showPoints, icon: Badge(label: Text('${_points.length}'), child: const Icon(Icons.list_alt))),
        ]))),
      ]),
    );
  }

  void _showStakeoutInput() => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
    padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Hedef Koordinat • DOM ${_tm?.dom}°', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 14),
      TextField(controller: _eCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Y / Doğu (m)', border: OutlineInputBorder())), const SizedBox(height: 10),
      TextField(controller: _nCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'X / Kuzey (m)', border: OutlineInputBorder())), const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () { Navigator.pop(ctx); _stakeout(); }, child: const Text('Aplikasyonu Hesapla'))),
    ]),
  ));

  void _showPoints() => showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
    const ListTile(title: Text('Alınan Noktalar', style: TextStyle(fontWeight: FontWeight.bold))),
    for (final x in _points.reversed) ListTile(leading: CircleAvatar(child: Text('${x.no}')), title: Text('Y ${x.tm.e.toStringAsFixed(3)}   X ${x.tm.n.toStringAsFixed(3)}'), subtitle: Text('DOM ${x.tm.dom}° • ±${x.pos.accuracy.toStringAsFixed(2)} m'), onTap: () { Navigator.pop(ctx); _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(x.pos.latitude, x.pos.longitude), 20)); }),
  ]));
}
