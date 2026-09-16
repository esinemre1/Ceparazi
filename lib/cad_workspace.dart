import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cad_controller.dart';
import 'file_import_service.dart';
import 'layer_manager.dart';

class CadWorkspace extends ChangeNotifier {
  final CadController cad;
  final LayerManager layers;
  final CadFileImportService files;

  CadWorkspace({required this.cad, LayerManager? layers, CadFileImportService? files})
      : layers = layers ?? LayerManager(), files = files ?? CadFileImportService() {
    this.layers.addListener(_syncSnap);
  }

  void _syncSnap() {
    cad.setExternalSnapPoints(layers.snapPoints());
    notifyListeners();
  }

  Future<CadLayer?> importFile({required int dxfDom}) async {
    final result = await files.pickAndRead(dxfDom: dxfDom);
    if (result == null || result.vertices.isEmpty) return null;
    final layer = layers.add(
      name: '${result.format} ${layers.layers.length + 1}',
      vertices: result.vertices,
      polygon: result.closed,
      source: result.format,
    );
    return layer;
  }

  void commitCurrent({String? name}) {
    final v = cad.state.vertices;
    if (v.length < 2) return;
    final polygon = cad.state.mode.name == 'polygon';
    layers.add(name: name ?? 'Cizim ${layers.layers.length + 1}', vertices: v, polygon: polygon);
    cad.clearVertices();
  }

  LatLng? centerOf(CadLayer layer) {
    if (layer.vertices.isEmpty) return null;
    var lat = 0.0, lon = 0.0;
    for (final p in layer.vertices) { lat += p.latitude; lon += p.longitude; }
    return LatLng(lat / layer.vertices.length, lon / layer.vertices.length);
  }

  @override
  void dispose() {
    layers.removeListener(_syncSnap);
    layers.dispose();
    super.dispose();
  }
}

class LayerSheet extends StatelessWidget {
  final LayerManager manager;
  final ValueChanged<CadLayer>? onZoom;
  const LayerSheet({super.key, required this.manager, this.onZoom});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: manager,
    builder: (_, __) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(10, 0, 10, 20), children: [
      ListTile(title: const Text('Katmanlar', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${manager.layers.length}')),
      if (manager.layers.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Henuz katman yok'))),
      for (final layer in manager.layers) ListTile(
        leading: IconButton(icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off), onPressed: () => manager.toggle(layer.id)),
        title: Text(layer.name),
        subtitle: Text('${layer.source} • ${layer.vertices.length} kose • ${layer.polygon ? 'Poligon' : 'Cizgi'}'),
        onTap: onZoom == null ? null : () => onZoom!(layer),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => manager.remove(layer.id)),
      ),
    ])),
  );
}
