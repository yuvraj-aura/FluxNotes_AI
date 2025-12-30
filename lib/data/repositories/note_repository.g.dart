// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$noteRepositoryHash() => r'e65e124acc768276807f679f55aa89f546847d05';

/// See also [noteRepository].
@ProviderFor(noteRepository)
final noteRepositoryProvider = AutoDisposeProvider<NoteRepository>.internal(
  noteRepository,
  name: r'noteRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$noteRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NoteRepositoryRef = AutoDisposeProviderRef<NoteRepository>;
String _$notesStreamHash() => r'bcef2bc514d3f7830708edb515c7f8e8f3f81638';

/// See also [notesStream].
@ProviderFor(notesStream)
final notesStreamProvider = AutoDisposeStreamProvider<List<Note>>.internal(
  notesStream,
  name: r'notesStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$notesStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NotesStreamRef = AutoDisposeStreamProviderRef<List<Note>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
