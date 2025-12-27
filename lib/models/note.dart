import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  late String title;
  late String content;
  late DateTime createdAt;
  bool isPinned = false;

  Note({
    this.id = Isar.autoIncrement,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isPinned = false,
  });

  Note copyWith({
    Id? id,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
