import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'cad_import_export.dart';

class CadFileImportService {
  Future<CadImportResult?> pickAndRead({required int dxfDom}) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['kml', 'dxf'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final item = picked.files.single;
    final path = item.path;
    if (path == null) throw Exception('Dosya yolu okunamadi.');
    final ext = (item.extension ?? path.split('.').last).toLowerCase();
    final text = await File(path).readAsString();
    if (ext == 'kml') return importKmlText(text);
    if (ext == 'dxf') return importDxfText(text, dxfDom);
    throw Exception('Yalnizca KML ve DXF destekleniyor.');
  }
}
