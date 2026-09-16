import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cad_geometry.dart';
import 'cad_models.dart';

class CadOverlayData {
  final Set<Polyline> polylines;
  final Set<Polygon> polygons;
  final Set<Marker> markers;
  final double lengthMeters;
  final double perimeterMeters;
  final double areaSquareMeters;

  const CadOverlayData({
    required this.polylines,
    required this.polygons,
    required this.markers,
    this.lengthMeters = 0,
    this.perimeterMeters = 0,
    this.areaSquareMeters = 0,
  });

  double get decares => areaSquareMeters / 1000;
  double get hectares => areaSquareMeters / 10000;
}

CadOverlayData buildCadOverlay(CadDrawingState state) {
  final v = state.vertices;
  final lines = <Polyline>{};
  final polygons = <Polygon>{};
  final markers = <Marker>{};

  for (var i = 0; i < v.length; i++) {
    markers.add(Marker(
      markerId: MarkerId('cad_vertex_$i'),
      position: v[i],
      anchor: const Offset(0.5, 0.5),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: 'P${i + 1}',
        snippet: 'Y ${latLngToTm3(v[i]).easting.toStringAsFixed(3)}  X ${latLngToTm3(v[i]).northing.toStringAsFixed(3)}',
      ),
    ));
  }

  if (v.length >= 2) {
    lines.add(Polyline(
      polylineId: const PolylineId('cad_work_line'),
      points: v,
      width: 5,
      color: state.mode == CadDrawMode.measure ? Colors.red : Colors.orange,
      geodesic: false,
    ));
  }

  var area = 0.0;
  var perimeter = 0.0;
  if (state.mode == CadDrawMode.polygon && v.length >= 3) {
    area = polygonArea(v);
    perimeter = polygonPerimeter(v);
    polygons.add(Polygon(
      polygonId: const PolygonId('cad_work_polygon'),
      points: v,
      strokeWidth: 4,
      strokeColor: Colors.orange,
      fillColor: Colors.orange.withValues(alpha: 0.20),
      geodesic: false,
    ));
  }

  return CadOverlayData(
    polylines: lines,
    polygons: polygons,
    markers: markers,
    lengthMeters: polylineLength(v),
    perimeterMeters: perimeter,
    areaSquareMeters: area,
  );
}

class CadMeasurementCard extends StatelessWidget {
  final CadDrawingState state;
  final CadOverlayData data;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onFinish;

  const CadMeasurementCard({
    super.key,
    required this.state,
    required this.data,
    this.onUndo,
    this.onRedo,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final polygon = state.mode == CadDrawMode.polygon;
    final lastAz = state.vertices.length >= 2
        ? azimuthDegrees(state.vertices[state.vertices.length - 2], state.vertices.last)
        : null;
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.architecture, size: 19),
            const SizedBox(width: 7),
            Expanded(child: Text('${state.mode.label} • ${state.vertices.length} kose', style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Geri al', onPressed: onUndo, icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'Yinele', onPressed: onRedo, icon: const Icon(Icons.redo)),
            TextButton(onPressed: onFinish, child: const Text('BITIR')),
          ]),
          if (polygon) ...[
            Text('Alan: ${data.areaSquareMeters.toStringAsFixed(2)} m²   •   ${data.decares.toStringAsFixed(4)} da'),
            Text('Hektar: ${data.hectares.toStringAsFixed(5)} ha   •   Cevre: ${data.perimeterMeters.toStringAsFixed(2)} m'),
          ] else
            Text('Toplam uzunluk: ${data.lengthMeters.toStringAsFixed(2)} m'),
          if (lastAz != null) Text('Son kenar azimut: ${lastAz.toStringAsFixed(4)}°'),
          if (state.snapEnabled) Text('SNAP: ${state.snapToleranceMeters.toStringAsFixed(1)} m', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
