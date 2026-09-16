import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CadLayer {
  final String id;
  final String name;
  final List<LatLng> vertices;
  final bool polygon;
  final bool visible;
  final String source;

  const CadLayer({required this.id,required this.name,required this.vertices,required this.polygon,this.visible=true,this.source='CAD'});
  CadLayer copyWith({String? name,List<LatLng>? vertices,bool? polygon,bool? visible,String? source})=>CadLayer(id:id,name:name??this.name,vertices:vertices??this.vertices,polygon:polygon??this.polygon,visible:visible??this.visible,source:source??this.source);
}

class LayerManager extends ChangeNotifier {
  final List<CadLayer> _layers=[];
  List<CadLayer> get layers=>List.unmodifiable(_layers);
  Iterable<CadLayer> get visibleLayers=>_layers.where((e)=>e.visible);

  CadLayer add({required String name,required Iterable<LatLng> vertices,required bool polygon,String source='CAD'}){
    final layer=CadLayer(id:'layer_${DateTime.now().microsecondsSinceEpoch}',name:name,vertices:List<LatLng>.from(vertices),polygon:polygon,source:source);
    _layers.add(layer);notifyListeners();return layer;
  }
  void toggle(String id){final i=_layers.indexWhere((e)=>e.id==id);if(i<0)return;_layers[i]=_layers[i].copyWith(visible:!_layers[i].visible);notifyListeners();}
  void rename(String id,String name){final i=_layers.indexWhere((e)=>e.id==id);if(i<0||name.trim().isEmpty)return;_layers[i]=_layers[i].copyWith(name:name.trim());notifyListeners();}
  void remove(String id){_layers.removeWhere((e)=>e.id==id);notifyListeners();}
  void clear(){_layers.clear();notifyListeners();}
  Iterable<LatLng> snapPoints()=>visibleLayers.expand((e)=>e.vertices);

  Set<Polyline> polylines(){return {for(final l in visibleLayers.where((e)=>!e.polygon)) if(l.vertices.length>=2) Polyline(polylineId:PolylineId(l.id),points:l.vertices,width:4)};}
  Set<Polygon> polygons(){return {for(final l in visibleLayers.where((e)=>e.polygon)) if(l.vertices.length>=3) Polygon(polygonId:PolygonId(l.id),points:l.vertices,strokeWidth:3,fillColor:const Color(0x221565C0),strokeColor:const Color(0xFF1565C0))};}
}
