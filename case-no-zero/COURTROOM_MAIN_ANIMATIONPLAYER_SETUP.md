# Main AnimationPlayer Setup - What to Add

## Overview
In the main `AnimationPlayer` node (the one at the root of the courtroom scene), you need to create these animations.

## Required Animations

### 1. Camera Focus Animations (Position 2D Tracks)

Create these 8 animations to move the camera to different characters:

#### `camera_focus_judge`
- **Length**: 0.8 seconds
- **Track Types**: 
  - **Position (2D)** track
  - **Zoom** track (for zooming in)
- **Track Path**: `PlayerM/Camera2D` (or `Camera2D` if separate)
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(640, 200)` (judge position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in on judge)
- **Interpolation**: Cubic (for both tracks)

#### `camera_focus_defendant`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(640, 500)` (defendant/Erwin position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

#### `camera_focus_prosecutor`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(400, 400)` (prosecutor/Fiscal position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

#### `camera_focus_center`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: `(712, 312)` (center position)
- **Zoom Keyframes**:
  - At 0.0s: Current zoom (or `(2.5, 2.5)` if zoomed in)
  - At 0.8s: `(2.0, 2.0)` (default zoom - zoom out)
- **Interpolation**: Cubic

#### `camera_focus_celine`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(500, 450)` (Celine position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

#### `camera_focus_po1_cordero`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(780, 450)` (PO1 Cordero position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

#### `camera_focus_dr_leticia`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(640, 400)` (Dr. Leticia position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

#### `camera_focus_kapitana`
- **Length**: 0.8 seconds
- **Track Types**: Position (2D) + Zoom
- **Track Path**: `PlayerM/Camera2D`
- **Position Keyframes**:
  - At 0.0s: Current camera position (or `(712, 312)` center)
  - At 0.8s: `(400, 500)` (Kapitana position)
- **Zoom Keyframes**:
  - At 0.0s: `(2.0, 2.0)` (default zoom)
  - At 0.8s: `(2.5, 2.5)` (zoomed in)
- **Interpolation**: Cubic

---

### 2. Optional Method Track Animations

**⚠️ IMPORTANT: These go in the MAIN AnimationPlayer (root), NOT in evidence AnimationPlayers!**

#### `objection` (Optional)
- **Location**: Main AnimationPlayer (root `AnimationPlayer` node)
- **Length**: 0.3 seconds
- **Track Type**: Method
- **Track Path**: `.` (root - where courtroom_manager script is attached)
- **Keyframe at 0.0s**:
  - Method: `_show_objection` (or `_perform_objection_shake` for screen shake only)
  - Args: (empty)
- **Purpose**: Shows objection sprite when prosecution/defense objects
- **When to use**: Called from dialogue actions like `"action": "play_objection_bgm"` or `"action": "objection_shake"`

#### `gavel` (Optional)
- **Location**: Main AnimationPlayer (root `AnimationPlayer` node)
- **Length**: 1.0 seconds
- **Track Type**: Method
- **Track Path**: `.` (root - where courtroom_manager script is attached)
- **Keyframe at 0.0s**:
  - Method: `_show_gavel`
  - Args: (empty)
- **Purpose**: Shows gavel sprite when judge makes ruling
- **When to use**: Called from dialogue actions like `"action": "show_gavel"`

#### `courtroom_intro` (Optional - for debug)
- **Length**: Your choice (e.g., 5-10 seconds)
- **Tracks**: Whatever you want for intro sequence
- **Purpose**: Plays automatically when jumping from debug menu

---

## Step-by-Step: Creating a Camera Animation

### Example: Creating `camera_focus_judge`

1. **Select the AnimationPlayer node** in the scene tree

2. **Click "Animation" → "New"** (or click the "+" button)

3. **Name it**: `camera_focus_judge`

4. **Set length**: `0.8` seconds

5. **Add Position Track**:
   - Click "Add Track" → "Position (2D)"
   - In the track path, select your Camera2D node
	 - If camera is separate: `Camera2D`
	 - If camera is on player: `PlayerM/Camera2D`

6. **Add Position Keyframes**:
   - At time `0.0`: Click keyframe icon (diamond)
	 - Set position to current camera position (or `(712, 312)` center)
   - At time `0.8`: Click keyframe icon
	 - Set position to target character position (e.g., `(640, 200)` for judge)

7. **Add Zoom Track**:
   - Click "Add Track" → "Zoom" (or "Property" → select `zoom` property)
   - Track path: `PlayerM/Camera2D`
   - Add Zoom Keyframes:
	 - At time `0.0`: `(2.0, 2.0)` (default zoom)
	 - At time `0.8`: `(2.5, 2.5)` (zoomed in on character)

8. **Set Interpolation**:
   - Right-click both tracks → "Interpolation" → "Cubic"
   - This makes the movement and zoom smooth

9. **Repeat for all 8 camera animations** with their respective target positions and zoom

---

## Quick Reference Table

| Animation Name | Target Position | Purpose |
|---------------|-----------------|---------|
| `camera_focus_judge` | (640, 200) | Focus on judge |
| `camera_focus_defendant` | (640, 500) | Focus on Erwin |
| `camera_focus_prosecutor` | (400, 400) | Focus on Fiscal |
| `camera_focus_center` | (712, 312) | Return to center |
| `camera_focus_celine` | (500, 450) | Focus on Celine |
| `camera_focus_po1_cordero` | (780, 450) | Focus on PO1 Cordero |
| `camera_focus_dr_leticia` | (640, 400) | Focus on Dr. Leticia |
| `camera_focus_kapitana` | (400, 500) | Focus on Kapitana |

---

## Important Notes

1. **Camera Path**: Make sure the track path points to your actual Camera2D node
   - Check if camera is on `PlayerM` or separate
   - Adjust the path accordingly

2. **Position Values**: These are example positions. Adjust based on where your characters actually are in the scene

3. **Interpolation**: Use Cubic for smooth camera movement

4. **Method Tracks**: For `objection` and `gavel`, use Method tracks, not Position tracks

5. **Optional Animations**: `objection`, `gavel`, and `courtroom_intro` are optional - the code will work without them (using tweens as fallback)

---

## Testing

After creating animations:
1. Select AnimationPlayer
2. Choose an animation from dropdown
3. Click play to test
4. Camera should move smoothly to target position

---

## Evidence AnimationPlayers Setup

**⚠️ NOTE: Gavel and Objection animations do NOT go here!** They go in the MAIN AnimationPlayer (see section 2 above).

Each evidence has its own AnimationPlayer for cross-examination sequences. These are located in the `EvidenceAnimPlayers` container node.

### Location
- **Container**: `EvidenceAnimPlayers` (Node)
- **Individual Animations**: Inside `EvidenceAnimPlayers/[EvidenceName]Anim/AnimationPlayer`

### Required Evidence AnimationPlayers

1. **BrokenBodyCamAnim** (AnimationPlayer)
2. **LogbookAnim** (AnimationPlayer)
3. **HandwritingSampleAnim** (AnimationPlayer)
4. **RadioLogAnim** (AnimationPlayer)
5. **AutopsyReportAnim** (AnimationPlayer)
6. **LeosNotebookAnim** (AnimationPlayer)

### Required Animation: `cross_examine`

Each evidence AnimationPlayer needs one animation called `cross_examine`.

#### `cross_examine` Animation Setup

**For each evidence AnimationPlayer:**

1. **Select the AnimationPlayer** (e.g., `BrokenBodyCamAnim`)

2. **Create Animation**:
   - Click "Animation" → "New"
   - Name it: `cross_examine`
   - Set length: `2.0` seconds (or adjust as needed)

3. **Add Tracks** (optional, for visual effects):

   **Option A: Simple (No tracks needed)**
   - Just create the empty animation - the code will handle evidence display
   - The animation just needs to exist for the code to play it

   **Option B: Add Visual Effect Tracks** (recommended for polish):
   
   **Track 1: Scale (2D)** - For zoom/pulse effect
   - Track Path: `.` (the EvidenceDisplaySprite itself)
   - Keyframes:
	 - At 0.0s: `(0.1, 0.1)` (start small)
	 - At 0.3s: `(1.1, 1.1)` (slight zoom in)
	 - At 1.0s: `(1.0, 1.0)` (normal size)
	 - At 2.0s: `(1.0, 1.0)` (hold)
   - Interpolation: Cubic
   
   **Track 2: Modulate Alpha** - For fade in
   - Track Path: `.` (EvidenceDisplaySprite)
   - Keyframes:
	 - At 0.0s: `0.0` (invisible)
	 - At 0.5s: `1.0` (fully visible)
	 - At 1.5s: `1.0` (hold visible)
	 - At 2.0s: `0.0` (fade out)
   - Interpolation: Linear

   **Track 3: Position (2D)** - For shake effect (optional)
   - Track Path: `.` (EvidenceDisplaySprite)
   - Keyframes:
	 - At 0.5s: `(0, 0)` (center)
	 - At 0.6s: `(-5, -5)` (shake)
	 - At 0.7s: `(5, 5)` (shake)
	 - At 0.8s: `(0, 0)` (return to center)
   - Interpolation: Linear

### Important Notes

- **The animation name MUST be `cross_examine`** - the code looks for this exact name
- **Track paths should point to `EvidenceDisplaySprite`** - not the AnimationPlayer itself
- **The animation is played automatically** when evidence is presented during cross-examination
- **You can keep it simple** - just an empty animation works, or add visual effects for polish

### Example: Broken Body Camera `cross_examine`

```
Animation: cross_examine
Length: 2.0 seconds

Track 1: Scale (2D) on EvidenceDisplaySprite
- 0.0s: (0.1, 0.1) - Start small
- 0.5s: (1.0, 1.0) - Grow to normal
- 1.5s: (1.0, 1.0) - Hold
- 2.0s: (0.1, 0.1) - Shrink out

Track 2: Modulate Alpha on EvidenceDisplaySprite
- 0.0s: 0.0 - Invisible
- 0.3s: 1.0 - Fade in
- 1.7s: 1.0 - Hold visible
- 2.0s: 0.0 - Fade out
```

### Quick Setup Checklist

For each of the 6 evidence AnimationPlayers:
- [ ] Create animation named `cross_examine`
- [ ] Set length to 2.0 seconds (or your preferred duration)
- [ ] (Optional) Add Scale track for zoom effect
- [ ] (Optional) Add Modulate Alpha track for fade
- [ ] (Optional) Add Position track for shake effect

**Note**: The tracks are optional - the code will display evidence even with an empty animation. Add tracks only if you want custom visual effects.

---

## What You DON'T Need to Add

- ❌ Complex sequences (use method tracks to call functions)
- ❌ Dialogue animations (handled by code automatically)

Just create the 8 camera focus animations and 6 evidence `cross_examine` animations and you're good to go!
