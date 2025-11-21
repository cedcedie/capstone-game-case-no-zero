# Courtroom AnimationPlayer Variables Reference

## Required AnimationPlayer Variables

### Main Courtroom AnimationPlayer
**Location**: Root `AnimationPlayer` node in courtroom scene

**Variable Name**: `anim_player`
**Type**: `AnimationPlayer`
**Path**: `../AnimationPlayer` (from courtroom_manager script)

---

## Evidence AnimationPlayers

Each evidence has its own AnimationPlayer for cross-examination sequences.

### Broken Body Camera
**Variable Name**: `evidence_anim_players["broken_body_cam"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/BrokenBodyCamAnim`
**Required Animation**: `cross_examine`

### Logbook
**Variable Name**: `evidence_anim_players["logbook"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/LogbookAnim`
**Required Animation**: `cross_examine`

### Handwriting Sample
**Variable Name**: `evidence_anim_players["handwriting_sample"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/HandwritingSampleAnim`
**Required Animation**: `cross_examine`

### Radio Log
**Variable Name**: `evidence_anim_players["radio_log"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/RadioLogAnim`
**Required Animation**: `cross_examine`

### Autopsy Report
**Variable Name**: `evidence_anim_players["autopsy_report"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/AutopsyReportAnim`
**Required Animation**: `cross_examine`

### Leo's Notebook
**Variable Name**: `evidence_anim_players["leos_notebook"]`
**Type**: `AnimationPlayer`
**Path**: `EvidenceAnimPlayers/LeosNotebookAnim`
**Required Animation**: `cross_examine`

---

## Evidence Display AnimationPlayer

**Variable Name**: `evidence_display_anim_player`
**Type**: `AnimationPlayer`
**Path**: `EvidenceDisplaySprite/AnimationPlayer` OR `EvidenceDisplayAnim`
**Required Animation**: `cross_examine` (optional - for custom evidence animation)

---

## All AnimationPlayer Variables Summary

```gdscript
# Main AnimationPlayer
@onready var anim_player: AnimationPlayer = get_node_or_null("../AnimationPlayer")

# Evidence AnimationPlayers Dictionary
var evidence_anim_players: Dictionary = {}  # Populated automatically

# Evidence Display AnimationPlayer
var evidence_display_anim_player: AnimationPlayer = null  # Found automatically
```

---

## Required Animations for Each AnimationPlayer

### Main AnimationPlayer (`anim_player`)
- `camera_focus_judge`
- `camera_focus_defendant`
- `camera_focus_prosecutor`
- `camera_focus_center`
- `camera_focus_celine`
- `camera_focus_po1_cordero`
- `camera_focus_dr_leticia`
- `camera_focus_kapitana`
- `objection` (optional - method track)
- `gavel` (optional - method track)
- `courtroom_sequence` (main sequence - optional)

### Each Evidence AnimationPlayer
- `cross_examine` (required)

### Evidence Display AnimationPlayer
- `cross_examine` (optional - for custom animation)

---

## Method Track Functions Available

All these can be called from AnimationPlayer method tracks:

### Dialogue Functions
- `advance_dialogue_lines(line_count: int)` - Auto-advance dialogue lines
- `show_line(speaker: String, text: String)` - Show single dialogue line

### Evidence Functions
- `_play_evidence_animation(evidence_id: String)` - Show evidence sprite
- `_hide_evidence_display()` - Hide evidence sprite

### Visual Effects
- `_show_objection()` - Show objection sprite
- `_show_gavel()` - Show gavel sprite
- `_perform_objection_shake()` - Screen shake effect

### Camera Functions (via actions in dialogue)
- `_camera_focus(target: String)` - Focus camera on character
  - Targets: "judge", "defendant", "prosecutor", "center", "celine", "po1_cordero", "dr_leticia", "kapitana"

---

## Scene Node Structure

```
Courtroom (Node2D) - has courtroom_manager.gd
├── AnimationPlayer (main)
│   └── Animations: camera_focus_*, objection, gavel, courtroom_sequence
├── EvidenceDisplaySprite (Sprite2D)
│   └── AnimationPlayer (optional)
│       └── Animation: cross_examine
└── EvidenceAnimPlayers (Node)
	├── BrokenBodyCamAnim (AnimationPlayer)
	│   └── Animation: cross_examine
	├── LogbookAnim (AnimationPlayer)
	│   └── Animation: cross_examine
	├── HandwritingSampleAnim (AnimationPlayer)
	│   └── Animation: cross_examine
	├── RadioLogAnim (AnimationPlayer)
	│   └── Animation: cross_examine
	├── AutopsyReportAnim (AnimationPlayer)
	│   └── Animation: cross_examine
	└── LeosNotebookAnim (AnimationPlayer)
		└── Animation: cross_examine
```

---

## Quick Reference

**Main AnimationPlayer**: `anim_player` - Root AnimationPlayer node
**Evidence AnimationPlayers**: `evidence_anim_players[evidence_id]` - Dictionary lookup
**Evidence Display**: `evidence_display_anim_player` - Optional AnimationPlayer for evidence sprite

**All variables are found automatically** - you just need to create the nodes in the scene!
