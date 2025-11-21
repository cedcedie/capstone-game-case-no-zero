# Courtroom Setup Guide - Complete Instructions

## Scene Structure Required

Your courtroom scene should have this structure:

```
Courtroom (Node2D) - has courtroom_manager.gd script
├── AnimationPlayer (for camera movements and objection shake)
├── Camera2D (or PlayerM/Camera2D)
├── GavelSprite (Node2D or Sprite2D) - for gavel animation
├── ObjectionSprite (Node2D or Sprite2D) - for objection animation
├── EvidenceDisplaySprite (Sprite2D) - displays evidence from EvidenceInventorySettings
│   └── AnimationPlayer (optional, for cross_examine animation)
└── DialogChooser (or use autoload)
```

## 1. Gavel and Objection Sprites Setup

### GavelSprite:
- **Type**: Node2D or Sprite2D
- **Position**: Center of screen (e.g., `640, 360` for 1280x720)
- **Default**: `visible = false`, `modulate.a = 0.0`
- **Path in scene**: `GavelSprite` (as child of Courtroom root)

### ObjectionSprite:
- **Type**: Node2D or Sprite2D  
- **Position**: Center of screen (e.g., `640, 360`)
- **Default**: `visible = false`, `modulate.a = 0.0`
- **Path in scene**: `ObjectionSprite` (as child of Courtroom root)

## 2. Evidence Display Setup

Create a **Sprite2D** node called `EvidenceDisplaySprite` as child of Courtroom root.

### EvidenceDisplaySprite (Sprite2D)
- **Path**: `EvidenceDisplaySprite`
- **Default**: `visible = false`, `modulate.a = 0.0`
- **Position**: Center of screen (e.g., `640, 360`)
- **Purpose**: Displays evidence textures from EvidenceInventorySettings

### Optional: AnimationPlayer for Evidence
- **Path**: `EvidenceDisplaySprite/AnimationPlayer` (as child) OR `EvidenceDisplayAnim` (sibling)
- **Required Animation**: `cross_examine` (optional, for custom animation effects)
- **Purpose**: Plays animation when evidence is shown during cross-examination

## 3. Evidence Cross-Examine Animation (Optional)

If you want custom animation effects, create `cross_examine` animation in the AnimationPlayer:

**Animation: `cross_examine`**
- **Length**: 2.0 seconds (adjust as needed)
- **Purpose**: Custom animation for evidence during cross-examination
- **Tracks**: Add any tracks you want (position, scale, modulate, rotation, etc.)
- **Note**: If no animation exists, the system will use default fade in/scale up effect

## 4. Main AnimationPlayer Animations

In the main `AnimationPlayer` node, create these animations:

### Camera Animations (same as before):
- `camera_focus_judge` - Position track to (640, 200)
- `camera_focus_defendant` - Position track to (640, 500)
- `camera_focus_prosecutor` - Position track to (400, 400)
- `camera_focus_center` - Position track to (640, 360)

### Objection Animation:
- `objection` - Method track calling `_perform_objection_shake` (optional, shake is handled in code)

## 5. DialogChooser Setup

Either:
- **Option A**: Add DialogChooser as autoload in project settings
- **Option B**: Add DialogChooser scene as child of Courtroom root

The code will automatically find it.

## 6. How It Works

### Gavel Animation:
- Called when: `show_gavel` or `play_gavel` action in dialogue
- Animation: Fades in, scales up to 1.2x, scales back, fades out
- Returns to original position automatically

### Objection Animation:
- Called when: `play_objection_bgm` or `objection_shake` action in dialogue
- Animation: Fades in, scales up to 1.3x, scales back, fades out
- Also triggers screen shake
- Returns to original position automatically

### Evidence Cross-Examination:
- Uses **EvidenceInventorySettings** to get evidence textures and data
- When evidence is presented, player gets choice:
  - "Gamitin ito para sa cross-examination"
  - "Ipresenta bilang ebidensya"
- If cross-examination chosen:
  - Gets evidence texture from EvidenceInventorySettings
  - Displays it on EvidenceDisplaySprite
  - Plays `cross_examine` animation (if exists) or default fade/scale effect
  - Shows gavel after cross-examination

### Dialogue Choices:
- Player can choose to present evidence at key moments
- Player can choose which evidence to present
- Player can choose how to use evidence (cross-examine vs regular)

## 7. Testing Checklist

- [ ] Gavel sprite appears and animates when called
- [ ] Objection sprite appears and animates when called
- [ ] Evidence animations play when cross-examining
- [ ] Dialogue choices appear and work
- [ ] Camera movements work
- [ ] Screen shake works on objections
- [ ] Evidence selection works

## Notes

- All sprites are hidden by default
- All animations return sprites to original position
- Evidence animations are separate per evidence for flexibility
- Dialogue system handles everything automatically
- Choices integrate seamlessly with dialogue flow

