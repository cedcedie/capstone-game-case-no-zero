# Courtroom AnimationPlayer Setup Instructions

## Overview
The courtroom manager handles all dialogue automatically. You need to create these animations manually in the AnimationPlayer node in the courtroom scene.

## Required Animations

### 1. Camera Focus Animations

Create these animations to move the camera to different positions:

#### Animation: `camera_focus_judge`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D` (or path to your camera node)
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(640, 200)` (judge position)
- **Interpolation**: Cubic (smooth)

#### Animation: `camera_focus_defendant`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(640, 500)` (defendant position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_prosecutor`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(400, 400)` (prosecutor position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_center`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(640, 360)` (center position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_celine`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(500, 450)` (Celine position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_po1_cordero`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(780, 450)` (PO1 Cordero position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_dr_leticia`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(640, 400)` (Dr. Leticia position)
- **Interpolation**: Cubic

#### Animation: `camera_focus_kapitana`
- **Length**: 0.8 seconds
- **Track Type**: Position (2D)
- **Track Path**: `Camera2D`
- **Keyframes**:
  - At 0.0s: Current camera position
  - At 0.8s: Position `(400, 500)` (Kapitana position)
- **Interpolation**: Cubic

### 2. Objection Animation

#### Animation: `objection`
- **Length**: 0.3 seconds
- **Track Type**: Method
- **Track Path**: `.` (root node - the courtroom manager)
- **Keyframes**:
  - At 0.0s: Call method `_perform_objection_shake` with no arguments
- **Purpose**: Triggers screen shake effect when objection occurs

## Step-by-Step Instructions

### For Camera Animations:

1. **Open the courtroom scene** (`scenes/environments/Courtroom/courtroom.tscn`)

2. **Select the AnimationPlayer node**

3. **Create a new animation**:
   - Click "Animation" → "New"
   - Name it `camera_focus_judge`
   - Set length to `0.8`

4. **Add Position Track**:
   - Click "Add Track" → "Position (2D)"
   - Set track path to your Camera2D node (e.g., `Camera2D` or `PlayerM/Camera2D`)

5. **Add Keyframes**:
   - At time `0.0`: Click keyframe icon, set to current camera position
   - At time `0.8`: Click keyframe icon, set to target position `(640, 200)`

6. **Set Interpolation**:
   - Right-click the track → "Interpolation" → "Cubic"

7. **Repeat for other camera animations**:
   - `camera_focus_defendant` → Position `(640, 500)`
   - `camera_focus_prosecutor` → Position `(400, 400)`
   - `camera_focus_center` → Position `(640, 360)`

### For Objection Animation:

1. **Create new animation**:
   - Name: `objection`
   - Length: `0.3`

2. **Add Method Track**:
   - Click "Add Track" → "Method"
   - Set track path to `.` (the root node where courtroom_manager is attached)

3. **Add Keyframe**:
   - At time `0.0`: Click keyframe icon
   - In the keyframe properties, set:
	 - Method: `_perform_objection_shake`
	 - Args: (leave empty)

## Important Notes

- **Camera Node Path**: Make sure the camera path in animations matches your actual camera node path in the scene
- **Position Values**: Adjust the position values `(640, 200)`, etc. based on where your characters actually are in the scene
- **Animation Names**: The animation names MUST match exactly:
  - `camera_focus_judge`
  - `camera_focus_defendant`
  - `camera_focus_prosecutor`
  - `camera_focus_center`
  - `objection`

## Testing

After creating the animations:
1. Run the scene
2. The dialogue will play automatically
3. Camera should move when dialogue actions trigger
4. Objection shake should occur when objections happen

## Alternative: If Camera is on Player

If your camera is attached to the PlayerM node, you'll need to:
1. Either move the camera to a separate node, OR
2. Adjust the camera positions in the code to account for player position, OR
3. Use a RemoteTransform2D or other method to control camera independently
