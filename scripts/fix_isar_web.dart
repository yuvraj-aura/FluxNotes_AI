// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File('lib/data/models/note_model.g.dart');
  if (!file.existsSync()) {
    print('File not found: ${file.path}');
    return;
  }

  String content = await file.readAsString();

  // 1. Replace large integer ID literals with int.parse()
  final idRegex = RegExp(r'id: (-?\d{16,}),');
  // We don't check hasMatch here strictly because the file might already be patched for IDs,
  // but we still need to run the const-removal logic below.
  content = content.replaceAllMapped(idRegex, (match) {
    final idStr = match.group(1);
    print('Patching ID: $idStr');
    return 'id: int.parse("$idStr"),';
  });

  // 2. Change 'const NoteSchema = CollectionSchema' to 'final NoteSchema = CollectionSchema'
  if (content.contains('const NoteSchema = CollectionSchema')) {
    content = content.replaceFirst('const NoteSchema = CollectionSchema',
        'final NoteSchema = CollectionSchema');
    print('Changed NoteSchema from const to final');
  } else if (content.contains('final NoteSchema = CollectionSchema')) {
    print('NoteSchema is already final.');
  }

  // 3. Change 'const ContentBlockSchema = Schema' (and others) to 'final ...'
  // Regex to match "const [Name] = Schema("
  final schemaRegex = RegExp(r'const (\w+) = Schema\(');
  if (schemaRegex.hasMatch(content)) {
    content = content.replaceAllMapped(schemaRegex, (match) {
      print('Changed ${match.group(1)} from const to final');
      return 'final ${match.group(1)} = Schema(';
    });
  }

  // 4. Remove 'const' from nested IndexSchema/PropertySchema constructors users
  // Replace "const IndexSchema" -> "IndexSchema"
  content = content.replaceAll('const IndexSchema', 'IndexSchema');
  // Replace "const PropertySchema" -> "PropertySchema"
  content = content.replaceAll('const PropertySchema', 'PropertySchema');
  // Replace "const Schema" -> "Schema" (generic safety)
  content = content.replaceAll('const Schema', 'Schema');

  await file.writeAsString(content);
  print(
      'Successfully patched lib/data/models/note_model.g.dart for Web compatibility.');
}
