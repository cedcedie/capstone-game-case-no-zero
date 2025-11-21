# Courtroom AnimationPlayer Track Guide - Phoenix Wright Style

## Overview
This guide shows you exactly where to add method tracks in your AnimationPlayer for Phoenix Wright-style gameplay.

## Main AnimationPlayer Structure

### Evidence-Specific AnimationPlayers
Each evidence has its own AnimationPlayer for cross-examination sequences.

**Location**: `EvidenceAnimPlayers/[EvidenceName]Anim/AnimationPlayer`

**Example Paths**:
- `EvidenceAnimPlayers/BrokenBodyCamAnim/AnimationPlayer`
- `EvidenceAnimPlayers/LogbookAnim/AnimationPlayer`
- `EvidenceAnimPlayers/HandwritingSampleAnim/AnimationPlayer`
- `EvidenceAnimPlayers/RadioLogAnim/AnimationPlayer`
- `EvidenceAnimPlayers/AutopsyReportAnim/AnimationPlayer`
- `EvidenceAnimPlayers/LeosNotebookAnim/AnimationPlayer`

## Track-by-Track Guide

### For Each Evidence AnimationPlayer:

#### Animation: `cross_examine`
**Length**: Adjust based on dialogue (e.g., 30-60 seconds)

**Track 1: Camera Focus (Position 2D)**
- **Time**: 0.0s
- **Track Type**: Position (2D)
- **Path**: `Camera2D` (or your camera path)
- **Keyframe**: Move camera to evidence display position
- **Purpose**: Focus camera on evidence

**Track 2: Show Evidence (Method)**
- **Time**: 0.5s
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `_play_evidence_animation`
- **Args**: `["evidence_id"]` (e.g., `["broken_body_cam"]`)
- **Purpose**: Display evidence sprite

**Track 3: Advance Dialogue Lines (Method)**
- **Time**: 2.0s
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `advance_dialogue_lines`
- **Args**: `[3]` (number of lines to auto-advance)
- **Purpose**: Auto-play 3 dialogue lines, pauses AnimationPlayer until done

**Track 4: Objection (Method) - OPTIONAL**
- **Time**: 8.0s (after dialogue)
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `_show_objection`
- **Args**: `[]`
- **Purpose**: Show objection sprite when prosecution objects

**Track 5: Advance More Dialogue (Method)**
- **Time**: 9.0s
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `advance_dialogue_lines`
- **Args**: `[2]` (2 more lines)
- **Purpose**: Continue dialogue after objection

**Track 6: Gavel (Method) - OPTIONAL**
- **Time**: 12.0s
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `_show_gavel`
- **Args**: `[]`
- **Purpose**: Show gavel when judge makes ruling

**Track 7: Hide Evidence (Method)**
- **Time**: 13.0s
- **Track Type**: Method
- **Path**: `.` (root - courtroom_manager)
- **Method**: `_hide_evidence_display`
- **Args**: `[]`
- **Purpose**: Hide evidence sprite

**Track 8: Camera Return (Position 2D)**
- **Time**: 14.0s
- **Track Type**: Position (2D)
- **Path**: `Camera2D`
- **Keyframe**: Return camera to center
- **Purpose**: Return camera to normal view

## Main Courtroom AnimationPlayer

**Location**: Root `AnimationPlayer` node

### Animation: `courtroom_sequence`
**Length**: Full trial length (e.g., 300+ seconds)

**Key Tracks to Add:**

**Track 1: Start Dialogue (Method)**
- **Time**: 0.0s
- **Track Type**: Method
- **Path**: `.` (root)
- **Method**: `advance_dialogue_lines`
- **Args**: `[5]` (opening statements)

**Track 2: Camera Focus Judge (Position 2D)**
- **Time**: 10.0s
- **Track Type**: Position (2D)
- **Path**: `Camera2D`
- **Keyframe**: Focus on judge

**Track 3: Advance Dialogue (Method)**
- **Time**: 11.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `advance_dialogue_lines`
- **Args**: `[3]`

**Track 4: Objection (Method) - When Prosecution Objects**
- **Time**: 25.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `_show_objection`
- **Args**: `[]`

**Track 5: Gavel (Method) - When Judge Rules**
- **Time**: 30.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `_show_gavel`
- **Args**: `[]`

**Track 6: Advance Dialogue (Method)**
- **Time**: 31.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `advance_dialogue_lines`
- **Args**: `[4]`

**Track 7: Camera Focus Celine (Position 2D) - When Celine Testifies**
- **Time**: 50.0s
- **Track Type**: Position (2D)
- **Path**: `Camera2D`
- **Keyframe**: Focus on Celine

**Track 8: Advance Celine Dialogue (Method)**
- **Time**: 51.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `advance_dialogue_lines`
- **Args**: `[5]` (Celine's admission)

**Track 9: Camera Focus Kapitana (Position 2D) - When Kapitana is Exposed**
- **Time**: 70.0s
- **Track Type**: Position (2D)
- **Path**: `Camera2D`
- **Keyframe**: Focus on Kapitana

**Track 10: Objection (Method) - When Kapitana Objects**
- **Time**: 75.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `_show_objection`
- **Args**: `[]`

**Track 11: Advance Dialogue (Method)**
- **Time**: 76.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `advance_dialogue_lines`
- **Args**: `[3]`

**Track 12: Gavel (Method) - Final Ruling**
- **Time**: 90.0s
- **Track Type**: Method
- **Path**: `.`
- **Method**: `_show_gavel`
- **Args**: `[]`

## Where to Add Objection/Gavel

### Objection Tracks:
Add `_show_objection` method tracks:
- **After prosecution speaks** (when they object)
- **After defense presents evidence** (when prosecution objects)
- **When Kapitana denies** (when she objects)
- **During cross-examination** (when witness objects)

### Gavel Tracks:
Add `_show_gavel` method tracks:
- **After judge makes ruling** ("Sustained" or "Overruled")
- **When judge calls for order** ("Tumahimik ka")
- **After evidence is accepted/rejected**
- **At end of phases** (opening statements, closing arguments)

## Timing Guidelines

### Dialogue Timing:
- **Typing Speed**: Normal (default DialogueUI speed ~0.01s per character)
- **Wait After Text**: 0.5 seconds (built into `advance_dialogue_lines`)
- **Auto-Advance**: Automatic after wait

### Animation Timing:
- **Camera Movement**: 0.8 seconds (smooth transition)
- **Objection Display**: 1.0 seconds (fade in/out)
- **Gavel Display**: 1.0 seconds (fade in/out)
- **Evidence Display**: 2-3 seconds (show evidence)

## Example: Broken Body Camera Cross-Examination

```
Time  | Track Type        | Method/Property        | Args/Value
------|-------------------|------------------------|------------
0.0s  | Position 2D       | Camera2D position      | Evidence position
0.5s  | Method            | _play_evidence_animation| ["broken_body_cam"]
2.0s  | Method            | advance_dialogue_lines  | [3]
8.0s  | Method            | _show_objection        | []
9.0s  | Method            | advance_dialogue_lines  | [2]
12.0s | Method            | _show_gavel            | []
13.0s | Method            | _hide_evidence_display  | []
14.0s | Position 2D       | Camera2D position      | Center
```

## Tips

1. **Test incrementally**: Add tracks one at a time and test
2. **Use method tracks**: They pause AnimationPlayer automatically
3. **Adjust timing**: Move tracks earlier/later based on dialogue length
4. **Objection timing**: Usually 0.5-1.0s after dialogue that triggers it
5. **Gavel timing**: Usually 0.5-1.0s after judge speaks

## Function Reference

### `advance_dialogue_lines(line_count: int)`
- Auto-advances dialogue lines
- Pauses AnimationPlayer during dialogue
- Resumes AnimationPlayer after all lines finish
- **Usage**: `advance_dialogue_lines(3)` - advances 3 lines

### `_show_objection()`
- Shows objection sprite with animation
- **Usage**: Call from method track when objection occurs

### `_show_gavel()`
- Shows gavel sprite with animation
- **Usage**: Call from method track when judge makes ruling

### `_play_evidence_animation(evidence_id: String)`
- Displays evidence sprite
- **Usage**: `_play_evidence_animation("broken_body_cam")`

### `_hide_evidence_display()`
- Hides evidence sprite
- **Usage**: Call after evidence presentation ends
