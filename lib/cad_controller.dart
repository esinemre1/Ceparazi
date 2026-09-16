import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cad_geometry.dart';
import 'cad_models.dart';

class CadController extends ChangeNotifier {
  CadDrawingState _state = const CadDrawingState();
  final CadHistory _history = CadHistory();
  final List<LatLng> _externalSnapPoints = [];

  CadDrawingState get state => _state;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void setMode(CadDrawMode mode, {bool clearVertices = true}) {
    if (clearVertices && _state.vertices.isNotEmpty) {
      _history.record(_state.vertices);
      _state = _state.copyWith(mode: mode, vertices: const []);
    } else {
      _state = _state.copyWith(mode: mode);
    }
    notifyListeners();
  }

  void finish() {
    _state = _state.copyWith(mode: CadDrawMode.none);
    notifyListeners();
  }

  void setSnapEnabled(bool value) {
    _state = _state.copyWith(snapEnabled: value);
    notifyListeners();
  }

  void setSnapTolerance(double meters) {
    _state = _state.copyWith(snapToleranceMeters: meters.clamp(0.10, 25.0));
    notifyListeners();
  }

  void setExternalSnapPoints(Iterable<LatLng> points) {
    _externalSnapPoints
      ..clear()
      ..addAll(points);
  }

  LatLng resolveSnap(LatLng tap) {
    if (!_state.snapEnabled) return tap;
    final candidates = <LatLng>[..._state.vertices, ..._externalSnapPoints];
    return nearestSnapPoint(tap, candidates, toleranceMeters: _state.snapToleranceMeters) ?? tap;
  }

  void addVertex(LatLng tap) {
    if (_state.mode == CadDrawMode.none) return;
    final p = resolveSnap(tap);
    _history.record(_state.vertices);
    _state = _state.copyWith(vertices: [..._state.vertices, p]);
    notifyListeners();
  }

  void addExactVertex(LatLng point) {
    if (_state.mode == CadDrawMode.none) return;
    _history.record(_state.vertices);
    _state = _state.copyWith(vertices: [..._state.vertices, point]);
    notifyListeners();
  }

  void replaceVertices(Iterable<LatLng> points) {
    _history.record(_state.vertices);
    _state = _state.copyWith(vertices: List<LatLng>.from(points));
    notifyListeners();
  }

  void removeLast() {
    if (_state.vertices.isEmpty) return;
    _history.record(_state.vertices);
    final next = List<LatLng>.from(_state.vertices)..removeLast();
    _state = _state.copyWith(vertices: next);
    notifyListeners();
  }

  void clearVertices() {
    if (_state.vertices.isEmpty) return;
    _history.record(_state.vertices);
    _state = _state.copyWith(vertices: const []);
    notifyListeners();
  }

  void undo() {
    final previous = _history.undo(_state.vertices);
    if (previous == null) return;
    _state = _state.copyWith(vertices: previous);
    notifyListeners();
  }

  void redo() {
    final next = _history.redo(_state.vertices);
    if (next == null) return;
    _state = _state.copyWith(vertices: next);
    notifyListeners();
  }
}
