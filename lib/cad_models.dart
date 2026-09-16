import 'package:google_maps_flutter/google_maps_flutter.dart';

enum CadDrawMode { none, polyline, polygon, measure }

extension CadDrawModeLabel on CadDrawMode {
  String get label {
    switch (this) {
      case CadDrawMode.none: return 'Hazir';
      case CadDrawMode.polyline: return 'Cizgi';
      case CadDrawMode.polygon: return 'Poligon';
      case CadDrawMode.measure: return 'Olcum';
    }
  }
}

class CadDrawingState {
  final CadDrawMode mode;
  final List<LatLng> vertices;
  final bool snapEnabled;
  final double snapToleranceMeters;

  const CadDrawingState({
    this.mode = CadDrawMode.none,
    this.vertices = const [],
    this.snapEnabled = true,
    this.snapToleranceMeters = 1.5,
  });

  CadDrawingState copyWith({
    CadDrawMode? mode,
    List<LatLng>? vertices,
    bool? snapEnabled,
    double? snapToleranceMeters,
  }) => CadDrawingState(
    mode: mode ?? this.mode,
    vertices: vertices ?? this.vertices,
    snapEnabled: snapEnabled ?? this.snapEnabled,
    snapToleranceMeters: snapToleranceMeters ?? this.snapToleranceMeters,
  );
}

class CadHistory {
  final List<List<LatLng>> _undo = [];
  final List<List<LatLng>> _redo = [];

  void record(List<LatLng> before) {
    _undo.add(List<LatLng>.from(before));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  List<LatLng>? undo(List<LatLng> current) {
    if (_undo.isEmpty) return null;
    _redo.add(List<LatLng>.from(current));
    return _undo.removeLast();
  }

  List<LatLng>? redo(List<LatLng> current) {
    if (_redo.isEmpty) return null;
    _undo.add(List<LatLng>.from(current));
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
