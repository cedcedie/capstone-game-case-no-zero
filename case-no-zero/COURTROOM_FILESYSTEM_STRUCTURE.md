# Courtroom Filesystem Structure Guide

## Complete File Structure

```
case-no-zero/
│
├── scenes/
│   └── environments/
│       └── Courtroom/
│           ├── courtroom.tscn                    # Main courtroom scene file
│           ├── frame 1.png                       # (Your existing files)
│           ├── Logbook.png
│           ├── objection_design.png
│           └── (other assets)
│
├── scripts/
│   └── environments/
│       └── courtroom_manager.gd                  # ✅ Main courtroom script (ALREADY CREATED)
│
├── data/
│   └── dialogues/
│       └── courtroom_dialogue.json               # ✅ Dialogue file (ALREADY UPDATED)
│
├── scenes/ui/UI by jer/
│   ├── design/
│   │   └── main_menu.tscn                        # ✅ Updated with courtroom button
│   └── scripts/
│       └── main_menu.gd                           # ✅ Updated with courtroom debug function
│
└── (Documentation files - optional)
    ├── COURTROOM_SETUP_GUIDE.md                  # Setup instructions
    ├── COURTROOM_ANIMATION_INSTRUCTIONS.md        # Animation setup
    ├── COURTROOM_ANIMATION_TRACK_GUIDE.md        # Track-by-track guide
    └── COURTROOM_ANIMATION_PLAYER_VARIABLES.md   # Variables reference
```

---

## Scene Structure (Inside courtroom.tscn)

When you open `scenes/environments/Courtroom/courtroom.tscn` in Godot, it should have this structure:

```
Courtroom (Node2D)
├── script: res://scripts/environments/courtroom_manager.gd  ✅
│
├── TileMapLayer (background tiles)
├── TileMapLayer2
├── TileMapLayer3
├── TileMapLayer4
├── TileMapLayer5
│
├── PlayerM (CharacterBody2D)                    # Player character
│   └── Camera2D                                 # Player camera (or separate)
│
├── AnimationPlayer                               # ✅ Main AnimationPlayer
│   └── Animations to create:
│       ├── camera_focus_judge
│       ├── camera_focus_defendant
│       ├── camera_focus_prosecutor
│       ├── camera_focus_center
│       ├── camera_focus_celine
│       ├── camera_focus_po1_cordero
│       ├── camera_focus_dr_leticia
│       ├── camera_focus_kapitana
│       ├── objection (optional)
│       ├── gavel (optional)
│       └── courtroom_intro (optional - for debug)
│
├── GavelSprite (Node2D or Sprite2D)             # ⚠️ CREATE THIS
│   └── (Your gavel sprite/texture)
│
├── ObjectionSprite (Node2D or Sprite2D)          # ⚠️ CREATE THIS
│   └── (Your objection sprite/texture)
│
├── EvidenceDisplaySprite (Sprite2D)              # ⚠️ CREATE THIS
│   └── AnimationPlayer (optional)                # ⚠️ CREATE THIS (optional)
│       └── Animation: cross_examine (optional)
│
└── EvidenceAnimPlayers (Node)                    # ⚠️ CREATE THIS CONTAINER
    ├── BrokenBodyCamAnim (AnimationPlayer)       # ⚠️ CREATE THIS
    │   └── Animation: cross_examine
    ├── LogbookAnim (AnimationPlayer)            # ⚠️ CREATE THIS
    │   └── Animation: cross_examine
    ├── HandwritingSampleAnim (AnimationPlayer)  # ⚠️ CREATE THIS
    │   └── Animation: cross_examine
    ├── RadioLogAnim (AnimationPlayer)            # ⚠️ CREATE THIS
    │   └── Animation: cross_examine
    ├── AutopsyReportAnim (AnimationPlayer)       # ⚠️ CREATE THIS
    │   └── Animation: cross_examine
    └── LeosNotebookAnim (AnimationPlayer)       # ⚠️ CREATE THIS
        └── Animation: cross_examine
```

---

## What's Already Done ✅

### Files Already Created/Updated:
1. ✅ `scripts/environments/courtroom_manager.gd` - Complete courtroom system
2. ✅ `data/dialogues/courtroom_dialogue.json` - All dialogue with Celine, Kapitana, etc.
3. ✅ `scenes/ui/UI by jer/scripts/main_menu.gd` - Debug button function
4. ✅ `scenes/ui/UI by jer/design/main_menu.tscn` - Debug button UI

### Code Features Already Working:
- ✅ Dialogue system (auto-advance)
- ✅ Evidence presentation
- ✅ Camera movements
- ✅ Gavel/Objection sprites
- ✅ Cross-examination system
- ✅ Character support (Celine, PO1 Cordero, Dr. Leticia, Kapitana)
- ✅ Debug menu integration

---

## What You Need to Create in Godot Editor ⚠️

### Step 1: Open courtroom.tscn
Open: `scenes/environments/Courtroom/courtroom.tscn`

### Step 2: Create Missing Nodes

#### A. GavelSprite
1. Right-click `Courtroom` → Add Child Node
2. Choose `Node2D` or `Sprite2D`
3. Rename to `GavelSprite`
4. Position at center: `(640, 360)`
5. Add your gavel texture/sprite
6. Set `visible = false` in Inspector

#### B. ObjectionSprite
1. Right-click `Courtroom` → Add Child Node
2. Choose `Node2D` or `Sprite2D`
3. Rename to `ObjectionSprite`
4. Position at center: `(640, 360)`
5. Add your objection texture/sprite
6. Set `visible = false` in Inspector

#### C. EvidenceDisplaySprite
1. Right-click `Courtroom` → Add Child Node
2. Choose `Sprite2D`
3. Rename to `EvidenceDisplaySprite`
4. Position at center: `(640, 360)`
5. Set `visible = false` in Inspector
6. (Optional) Add AnimationPlayer child for custom animations

#### D. EvidenceAnimPlayers Container
1. Right-click `Courtroom` → Add Child Node
2. Choose `Node`
3. Rename to `EvidenceAnimPlayers`

#### E. Individual Evidence AnimationPlayers
For each evidence, create an AnimationPlayer:

1. Right-click `EvidenceAnimPlayers` → Add Child Node
2. Choose `AnimationPlayer`
3. Rename to one of:
   - `BrokenBodyCamAnim`
   - `LogbookAnim`
   - `HandwritingSampleAnim`
   - `RadioLogAnim`
   - `AutopsyReportAnim`
   - `LeosNotebookAnim`
4. Create animation called `cross_examine` in each

### Step 3: Create Animations in Main AnimationPlayer

Select the main `AnimationPlayer` node and create these animations:

1. **camera_focus_judge** - Position track to (640, 200)
2. **camera_focus_defendant** - Position track to (640, 500)
3. **camera_focus_prosecutor** - Position track to (400, 400)
4. **camera_focus_center** - Position track to (640, 360)
5. **camera_focus_celine** - Position track to (500, 450)
6. **camera_focus_po1_cordero** - Position track to (780, 450)
7. **camera_focus_dr_leticia** - Position track to (640, 400)
8. **camera_focus_kapitana** - Position track to (400, 500)
9. **courtroom_intro** (optional) - Your intro animation
10. **objection** (optional) - Method track calling `_perform_objection_shake`
11. **gavel** (optional) - Method track calling `_show_gavel`

---

## File Locations Summary

### Scripts (Code):
- `scripts/environments/courtroom_manager.gd` ✅ DONE

### Scenes (Godot):
- `scenes/environments/Courtroom/courtroom.tscn` ⚠️ NEEDS NODES ADDED

### Data (Dialogue):
- `data/dialogues/courtroom_dialogue.json` ✅ DONE

### UI (Main Menu):
- `scenes/ui/UI by jer/scripts/main_menu.gd` ✅ DONE
- `scenes/ui/UI by jer/design/main_menu.tscn` ✅ DONE

### Documentation (Reference):
- `COURTROOM_SETUP_GUIDE.md` - How to set up nodes
- `COURTROOM_ANIMATION_INSTRUCTIONS.md` - How to create animations
- `COURTROOM_ANIMATION_TRACK_GUIDE.md` - Where to add tracks
- `COURTROOM_ANIMATION_PLAYER_VARIABLES.md` - Variable reference
- `COURTROOM_FILESYSTEM_STRUCTURE.md` - This file

---

## Quick Checklist

### In Godot Editor (courtroom.tscn):
- [ ] Create `GavelSprite` node
- [ ] Create `ObjectionSprite` node
- [ ] Create `EvidenceDisplaySprite` node
- [ ] Create `EvidenceAnimPlayers` container
- [ ] Create 6 evidence AnimationPlayers inside container
- [ ] Create `cross_examine` animation in each evidence AnimationPlayer
- [ ] Create camera focus animations in main AnimationPlayer
- [ ] Create `courtroom_intro` animation (optional)

### Testing:
- [ ] Open main menu
- [ ] Click "Debugger" button
- [ ] Click "Jump to Courtroom"
- [ ] Verify courtroom loads
- [ ] Verify intro animation plays (if created)
- [ ] Verify dialogue starts

---

## Important Notes

1. **Script is already attached**: The `courtroom_manager.gd` script is already on the `Courtroom` root node
2. **Nodes are found automatically**: The script finds nodes by name, so names must match exactly
3. **Animations are optional**: You can create them as needed, the system will work without them (using tweens as fallback)
4. **Evidence animations**: Each evidence needs its own AnimationPlayer for cross-examination sequences

---

## Need Help?

- **Setup**: See `COURTROOM_SETUP_GUIDE.md`
- **Animations**: See `COURTROOM_ANIMATION_INSTRUCTIONS.md`
- **Tracks**: See `COURTROOM_ANIMATION_TRACK_GUIDE.md`
- **Variables**: See `COURTROOM_ANIMATION_PLAYER_VARIABLES.md`

