Use the team: FORGE, AURA, KRONOS, CYPHER. Deliver a production update to the E-Player Flutter application implementing empty group creation with an Add button, long-press selection with Select All and delete/move actions across Home and Library, a scrollable 5-item History, and video-only filtering for the Media Library as shown in the UI reference images.

Working directory: d:\E-player\app
Integrity mode: development

## Reference Material
- UI Reference Image 1 (Home Screen - Groups & Bento Grid): C:/Users/Admin/.gemini/antigravity/brain/02329fad-d9b2-497b-9221-ee4d8cf756ee/.user_uploaded/media_1793791961445_d3e0263c.jpg
- UI Reference Image 2 (Home Screen - History & Category Pills): C:/Users/Admin/.gemini/antigravity/brain/02329fad-d9b2-497b-9221-ee4d8cf756ee/.user_uploaded/media_1793791964373_fbec4386.jpg

## Requirements

### R1. Empty Group Creation with Add Button
When a new group is created, it must initialize completely empty inside. It must include an Add button enabling users to add new folders or files to that group.

### R2. Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
Implement a long-press gesture on groups, folders, and files to trigger item selection. Provide a "Select All" option that selects all selectable items in the current group or folder view. Selected items must support being deleted or moved to another group. This selection behavior must not apply to built-in / default app features.

### R3. Multi-Select and Batch Actions in Library Section
Apply the same long-press multi-selection, Select All option, deletion, and move-to-group capabilities to the Library section.

### R4. Scrollable History with 5-Item Limit
Enable scrolling in the History section so that items can be smoothly browsed. Limit the History list to display a maximum of 5 items.

### R5. Media Library Video-Only Filtering
Filter the Media Library on the Home screen so that it displays only videos and their containing folders from the Library. Remove the music, series, and anime category sections.

### R6. Workspace Scope
All modifications must be applied exclusively to the primary working copy at `d:\E-player\app`.

## Verification Resources
- Flutter static analysis: `dart analyze` in `d:\E-player\app`
- Flutter test suite: `flutter test` in `d:\E-player\app`

## Acceptance Criteria

### Group Creation
- [ ] Newly created groups initialize with zero items (completely empty inside).
- [ ] Newly created groups display an Add button that allows users to add new files or folders.

### Multi-Select & Batch Actions (Home & Library)
- [ ] Long-pressing any custom group, folder, or file enters multi-selection mode and marks the item selected.
- [ ] Tapping "Select All" selects all selectable items in the current container.
- [ ] Selected items can be deleted with changes reflected in state and UI.
- [ ] Selected items can be moved to another designated group.
- [ ] Built-in / default application features do not trigger multi-selection or allow deletion/moving.
- [ ] The Library section supports long-press selection, Select All, deletion, and moving to another group.

### History Section
- [ ] History list can be scrolled smoothly to browse entries.
- [ ] History list contains no more than 5 items at any time.

### Media Library Filtering
- [ ] Home screen Media Library displays only Library videos and video folders.
- [ ] Music, series, and anime categories/cards are completely removed from the Media Library section.

### Code Quality & Verification
- [ ] `dart analyze` passes with zero errors.
- [ ] Automated tests pass via `flutter test` verifying the group creation, selection/delete/move actions, history cap, and media library filtering.
