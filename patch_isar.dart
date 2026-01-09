import 'dart:io';

void main() async {
  final file = File('lib/data/models/note_model.g.dart');
  if (!file.existsSync()) {
    print('File not found: ${file.path}');
    return;
  }

  String content = await file.readAsString();
  final regex = RegExp(r'id: (-?\d{16,}),');

  // Check if we have matches
  if (!regex.hasMatch(content)) {
    print('No large integer literals found.');
    return;
  }

  // Replace
  final newContent = content.replaceAllMapped(regex, (match) {
    print('Patching ID: ${match.group(1)}');
    return 'id: int.parse("${match.group(1)}"),'; // Wrap in int.parse
  });

  await file.writeAsString(newContent);
  print('Successfully patched lib/data/models/note_model.g.dart');
}
