# FluxNotes Blueprint

## Overview

FluxNotes is a sophisticated, local-first note-taking application designed for performance and flexibility. It features a block-based editor similar to Notion, allowing users to structure their thoughts with various content types. The app is built with a local-first architecture, ensuring that data is always available offline and syncs seamlessly when a connection is available.

---

## Implemented Features & Design

This section documents the project, including all style, design, and features implemented from the initial version to the current version.

### **V1: Project Initialization & Foundational Setup**

*   **Project Structure:** Standard Flutter project layout with feature-based directories.
*   **Dependencies:** `isar`, `flutter_riverpod`, `google_fonts`, `uuid`, `intl`, `path_provider`, etc.
*   **Core App Setup (`main.dart`):** Initialized Riverpod and configured basic `MaterialApp` themes.

### **V2: Data Layer & Persistence**

*   **Isar Schemas (`lib/data/models/note_model.dart`):** Defined `Note` and `ContentBlock` schemas for the database.
*   **Repository (`lib/data/repositories/note_repository.dart`):** Created `NoteRepository` to abstract all data operations (CRUD).
*   **Dependency Injection (Riverpod):** Set up providers for the Isar instance and the `NoteRepository`.

### **V3: The "Local-First" Dashboard (`HomeScreen`)**

*   **UI (`lib/features/home/home_screen.dart`):** Built a real-time, stream-based `MasonryGridView` of notes with a FAB for creation.

### **V4: Block Editor Foundation**

*   **State Management (`lib/features/editor/providers/editor_provider.dart`):** Created `NoteEditorNotifier` to manage the state of the note being edited.
*   **UI (`lib/features/editor/editor_screen.dart`):** Built the basic editor with a `ListView`, a title field, and text fields for each block, including an auto-saving debouncer.

### **V5: Editor Flow & Visual Polish**

*   **`BlockWidget` (`lib/features/editor/widgets/block_widget.dart`):** Created a dedicated widget to handle interaction logic for a single block, encapsulating the `FocusNode`, `TextEditingController`, and `RawKeyboardListener`.
*   **Interaction Logic (Keyboard):**
    *   **On "Enter":** A new block is created, and focus is programmatically moved to the new `TextField`.
    *   **On "Backspace" (in an empty block):** The block is deleted, and focus is moved to the end of the previous block.
*   **Visual Design & UX:**
    *   **Drag Handle:** A `Icons.drag_indicator` icon appears with a fade animation to the left of a `BlockWidget` only when its `TextField` is focused. This provides a clean visual cue for interactivity.
    *   **Focus Management:** The `EditorScreen` now actively tracks which block has focus (`_focusedBlockId`) and rebuilds the UI to show/hide the handle, ensuring the UI is always in sync with the user's interaction point.
    *   **Layout:** Spacing and padding have been adjusted for a more balanced and visually appealing layout.
    *   **UX Refinements:** The `ListView` automatically scrolls to keep the active block visible.

### **V6: "God Mode" Quick Capture**

*   **Instant Note Creation (`HomeScreen`):** The `FloatingActionButton` has been replaced with an `OpenContainer` from the `animations` package. This provides a fluid, visually appealing transition that expands the FAB directly into the `EditorScreen`.
*   **Seamless Flow:** Tapping the FAB now instantly creates a new note in the database and navigates the user to the editor for that new note.
*   **Auto-Focus Title:** When creating a new note via the FAB, the `EditorScreen` now automatically focuses the title field, allowing the user to begin typing immediately without any extra taps.
*   **"Ghost Note" Prevention:** A crucial UX improvement was added to the `EditorScreen`. If a user backs out of a brand-new note (one opened via the FAB) without adding any content (the title is empty and the initial block is unmodified), the note is automatically deleted from the database. This prevents the user's note list from becoming cluttered with empty, unused "ghost notes".

---

## Current Task

This section outlines the plan for the current requested change. Please provide the next goal.
