import 'dart:convert';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'cad_models.dart';

class CepAraziProject {
  final String name;
  final DateTime updatedAt;
  final CadDrawMode mode;
  final List<LatLng> vertices;
  final int? dom;
  final bool snapEnabled;
  final double snapTolerance;

  const CepAraziProject({required this.name, required this.updatedAt, required this.mode, required this.vertices, this.dom, required this.snapEnabled, required this.snapTolerance});

  Map<String, dynamic> toJson() => {
    'version': 1,
    'name': name,
    'updatedAt': updatedAt.toIso8601String(),
    'mode': mode.name,
    'dom': dom,
    'snapEnabled': snapEnabled,
    'snapTolerance': snapTolerance,
    'vertices': vertices.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
  };

  factory CepAraziProject.fromJson(Map<String, dynamic> j) {
    final modeName = j['mode']?.toString() ?? 'none';
    final mode = CadDrawMode.values.firstWhere((e) => e.name == modeName, orElse: () => CadDrawMode.none);
    final raw = (j['vertices'] as List?) ?? const [];
    return CepAraziProject(
      name: j['name']?.toString() ?? 'Proje',
      updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      mode: mode,
      dom: j['dom'] as int?,
      snapEnabled: j['snapEnabled'] as bool? ?? true,
      snapTolerance: (j['snapTolerance'] as num?)?.toDouble() ?? 1.5,
      vertices: raw.whereType<Map>().map((p) => LatLng((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble())).toList(),
    );
  }
}

class ProjectStore {
  Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/CepArazi/projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeName(String value) {
    final s = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-ğüşöçıİĞÜŞÖÇ ]'), '_').replaceAll(RegExp(r'\s+'), '_');
    return s.isEmpty ? 'proje' : s;
  }

  Future<File> save(CepAraziProject project) async {
    final dir = await _dir();
    final file = File('${dir.path}/${_safeName(project.name)}.caproj');
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(project.toJson()), flush: true);
  }

  Future<List<File>> list() async {
    final dir = await _dir();
    final files = await dir.list().where((e) => e is File && e.path.toLowerCase().endsWith('.caproj')).cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<CepAraziProject> open(File file) async {
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return CepAraziProject.fromJson(data);
  }

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
  }
}
