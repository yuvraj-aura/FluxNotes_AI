import 'package:isar/isar.dart';

part 'note_model.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  @Index(type: IndexType.value, caseSensitive: false)
  late String title;

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  @Index()
  List<String> tags = [];

  List<ContentBlock> blocks = [];

  bool isPinned = false;

  String? summary;
}

@embedded
class ContentBlock {
  late String id;

  @Enumerated(EnumType.name)
  late BlockType type;

  late String content;

  bool? isChecked;

  String? metadata;

  ContentBlock({
    this.id = '',
    this.type = BlockType.paragraph,
    this.content = '',
    this.isChecked = false,
    this.metadata,
  });
}

enum BlockType {
  paragraph,
  heading1,
  heading2,
  todo,
  bullet,
  image,
  video,
}
