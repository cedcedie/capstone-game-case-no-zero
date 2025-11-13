extends CanvasLayer

signal minimap_ready

@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $SubViewportContainer/SubViewport/MinimapCamera
@onready var minimap_tilemap: TileMap = $SubViewportContainer/SubViewport/MinimapTileMap
@onready var minimap_root: Node2D = $SubViewportContainer/SubViewport/MinimapRoot
@onready var player_marker: Sprite2D = $SubViewportContainer/SubViewport/PlayerMarker

# Runtime UI elements for circular masked minimap
var masked_rect: TextureRect = null
var border_rect: ColorRect = null
var north_label: Label = null
var east_label: Label = null
var south_label: Label = null
var west_label: Label = null

# Waypoint marker for task navigation
var waypoint_marker: Sprite2D = null
var waypoint_edge_indicator: Sprite2D = null  # Edge indicator when waypoint is off-screen
var waypoint_active: bool = false
var waypoint_position: Vector2 = Vector2.ZERO
var waypoint_target_scene: String = ""

var player: Node2D = null
var tilemap_layers: Array = []
var scene_minimap_cache: Dictionary = {}
var pending_scene_path: String = ""
var _build_retry_attempts: int = 0
const _MAX_BUILD_ATTEMPTS: int = 10
const _RETRY_DELAY_SEC: float = 0.1
const EXTERIOR_PATHS := [
	"res://scenes/environments/exterior/apartment_morgue.tscn",
	"res://scenes/environments/exterior/baranggay_court.tscn",
	"res://scenes/environments/exterior/camp.tscn",
	"res://scenes/environments/exterior/hotel_hospital.tscn",
	"res://scenes/environments/exterior/police_station.tscn",
	"res://scenes/environments/exterior/terminal_market.tscn",
]

# Minimap zoom: lower values show more area (higher POV than player)
const MINIMAP_ZOOM: float = 0.2
const PLAYER_MARKER_SCALE: float = 7


func _ready() -> void:
	await get_tree().process_frame  # wait one frame so children exist
	viewport_container = $SubViewportContainer
	viewport = $SubViewportContainer/SubViewport
	minimap_camera = $SubViewportContainer/SubViewport/MinimapCamera
	minimap_tilemap = $SubViewportContainer/SubViewport/MinimapTileMap

	if viewport == null or minimap_camera == null or minimap_tilemap == null or minimap_root == null:
		push_error("⚠️ Minimap: Could not find one or more child nodes! Check node paths.")
		return

	# Check if current scene is exterior - if not, disable minimap completely
	var tree := get_tree()
	var root := tree.current_scene if tree != null else null
	if not _is_exterior_scene(root):
		print("[Minimap] Current scene is not exterior - disabling minimap")
		visible = false
		_clear_minimap()
		# Still connect to scene changes to re-check when scene changes
		if tree != null:
			if tree.has_signal("current_scene_changed"):
				tree.connect("current_scene_changed", Callable(self, "_on_current_scene_changed"))
			elif tree.has_signal("scene_changed"):
				tree.connect("scene_changed", Callable(self, "_on_current_scene_changed"))
		return

	print("🗺️ Minimap ready (autoload expected) - exterior scene detected.")

	# Build circular masked view from the SubViewport's texture (GTA-style round minimap)
	_setup_circular_masked_view()
	_setup_compass_letters()

	if viewport.size == Vector2i.ZERO:
		viewport.size = Vector2i(256, 256)

	# Ensure the SubViewport renders every frame and the camera is active
	if viewport.has_method("set_update_mode"):
		# Safety: older API guard; not expected in 4.4
		viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera.has_method("make_current"):
		minimap_camera.make_current()
	elif "enabled" in minimap_camera:
		minimap_camera.enabled = true

	minimap_camera.zoom = Vector2(MINIMAP_ZOOM, MINIMAP_ZOOM)
	# Hide player indicator on the minimap
	if player_marker != null:
		player_marker.visible = false
	visible = true

	# DO NOT prebake - causes crashes. Only build when actually needed.

	# Fallbacks: try to auto-bind player and tilemap layers if not set externally
	if player == null:
		var found_players := tree.get_nodes_in_group("player")
		if not found_players.is_empty():
			var candidate: Node = found_players[0]
			if candidate is Node2D:
				set_player(candidate)
		else:
			# Try common node names
			if root != null:
				var maybe_player := root.find_child("Player", true, false)
				if maybe_player != null and maybe_player is Node2D:
					set_player(maybe_player)
				else:
					# Broader heuristic: first Node2D whose name contains "player"
					for n in root.get_children():
						if n is Node2D and String(n.name).to_lower().contains("player"):
							set_player(n)
							break

	if tilemap_layers.is_empty():
		if root != null:
			var collected: Array = []
			# Deep search for TileMapLayer nodes
			for node in root.find_children("*", "TileMapLayer", true, false):
				collected.append(node)
			if not collected.is_empty():
				set_tilemap_layers(collected)

	# If we have data now, initialize immediately
	if not tilemap_layers.is_empty():
		_copy_tilemap_layers()
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos

	# React to scene changes so minimap updates when entering new scenes
	if tree != null:
		if tree.has_signal("current_scene_changed"):
			tree.connect("current_scene_changed", Callable(self, "_on_current_scene_changed"))
		elif tree.has_signal("scene_changed"):
			tree.connect("scene_changed", Callable(self, "_on_current_scene_changed"))

	# Connect to TaskManager for waypoint updates
	var task_manager := get_node_or_null("/root/TaskManager")
	if task_manager != null:
		if not task_manager.is_connected("waypoint_set", Callable(self, "_on_waypoint_set")):
			task_manager.connect("waypoint_set", Callable(self, "_on_waypoint_set"))
		if not task_manager.is_connected("waypoint_cleared", Callable(self, "_on_waypoint_cleared")):
			task_manager.connect("waypoint_cleared", Callable(self, "_on_waypoint_cleared"))
		# Check if there's already an active waypoint
		if task_manager.has_waypoint():
			_on_waypoint_set(task_manager.get_current_task_scene_target(), task_manager.get_current_waypoint_position())

	# Create waypoint marker
	_create_waypoint_marker()
	
	# Re-check waypoint if one exists
	if task_manager != null and task_manager.has_waypoint():
		var target_scene: String = task_manager.get_current_task_scene_target()
		var target_pos: Vector2 = task_manager.get_current_waypoint_position()
		_on_waypoint_set(target_scene, target_pos)

	# Align the circular minimap to the placed SubViewportContainer/border
	_align_minimap_to_container()
	# Ensure consistent style on first build
	_apply_consistent_style()


func _on_current_scene_changed(_new_scene: Node) -> void:
	# Clear immediately so old map is not shown during transitions
	_clear_minimap()
	
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	
	# Check if new scene is exterior - if not, disable minimap
	if not _is_exterior_scene(root):
		print("[Minimap] New scene is not exterior - disabling minimap")
		visible = false
		_clear_minimap()
		# Hide waypoint marker when not in exterior scene
		if waypoint_marker != null:
			waypoint_marker.visible = false
		return
	
	print("[Minimap] current_scene_changed: exterior scene detected, building minimap")

	# Ensure waypoint marker exists before proceeding
	if waypoint_marker == null:
		_create_waypoint_marker()

	# Re-apply viewport/camera settings to avoid stale state across scenes
	if viewport != null:
		if viewport.has_method("set_update_mode"):
			viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera != null:
		if minimap_camera.has_method("make_current"):
			minimap_camera.make_current()
		elif "enabled" in minimap_camera:
			minimap_camera.enabled = true
	visible = true
	# Re-apply consistent styling to avoid mismatches across flows
	_apply_consistent_style()
	# Keep the masked view centered after scene changes
	_center_minimap_on_screen()

	# Try to scan and build immediately for instant visual update
	# First, try to use cache for the newly current scene
	if root != null:
		var key := _find_cached_scene_key(root)
		if key != "" and scene_minimap_cache.has(key):
			print("[Minimap] Using cached minimap for:", key)
			_use_cached_minimap(key)
			_resolve_player()
			if player != null:
				minimap_camera.global_position = player.global_position
		else:
			print("[Minimap] No cache for:", key, " -> scanning")
			_scan_and_build()
	else:
		_scan_and_build()

	# Also rebuild next frame to capture any late-instanced nodes
	if get_tree() != null:
		await get_tree().process_frame
	_scan_and_build()
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")
	
	# Re-check waypoint visibility after scene change - ensure it persists
	await get_tree().process_frame  # Wait a frame for scene to fully load
	var task_manager := get_node_or_null("/root/TaskManager")
	if task_manager != null and task_manager.has_waypoint():
		print("📍 Minimap: Re-checking waypoint after scene change to ", root.name if root else "unknown")
		# Re-trigger waypoint display with current waypoint data
		# This will recalculate the waypoint position based on the new scene
		var target_scene: String = task_manager.get_current_task_scene_target()
		var target_pos: Vector2 = task_manager.get_current_waypoint_position()
		_on_waypoint_set(target_scene, target_pos)
	else:
		# If no waypoint is active, ensure marker is hidden
		if waypoint_marker != null:
			waypoint_marker.visible = false
			waypoint_active = false


func _on_transition_start() -> void:
	# Public hook: called by scene_transition.gd before changing scenes
	_clear_minimap()


func _on_transition_complete(_target_scene_path: String = "") -> void:
	# Called after scene change has been kicked off; wait for new scene to be current and ready
	pending_scene_path = String(_target_scene_path)
	print("[Minimap] transition_complete: target_path=", pending_scene_path)
	if get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame
	# Prefer cache for the known target if available
	var tree2 := get_tree()
	if tree2 == null:
		return
	# Ensure consistent look immediately after transition
	_apply_consistent_style()
	var root2 := tree2.current_scene
	if root2 != null:
		var key2 := _find_cached_scene_key(root2)
		if key2 != "" and scene_minimap_cache.has(key2):
			print("[Minimap] Using cached minimap after transition for:", key2)
			_use_cached_minimap(key2)
			_resolve_player()
			if player != null:
				minimap_camera.global_position = player.global_position
				if player_marker != null:
					player_marker.global_position = player.global_position
					player_marker.visible = false
			emit_signal("minimap_ready")
			return
	print("[Minimap] No cache after transition -> scanning/building")
	_scan_and_build()
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")

	# Kick off retry loop if nothing built
	if minimap_root.get_child_count() == 0:
		_build_retry_attempts = 0
		_retry_build_loop()


func _scan_and_build() -> void:
	# Re-scan for player and layers, then rebuild minimap
	player = null
	var tree := get_tree()
	if tree == null:
		_clear_minimap()
		return
	var root := tree.current_scene

	# If no scene yet, clear and bail
	if root == null:
		_clear_minimap()
		return
	
	# Check if current scene is an exterior scene - only build minimap for exterior scenes
	var scene_path := ""
	if "scene_file_path" in root:
		scene_path = String(root.scene_file_path)
	if not scene_path.is_empty():
		var normalized := _normalize_exterior_path(scene_path)
		if normalized.is_empty():
			# Not an exterior scene - clear minimap and return
			print("[Minimap] Scene is not an exterior scene, clearing minimap:", scene_path)
			_clear_minimap()
			visible = false
			return
	else:
		# No scene path - try to match by name
		var scene_name := String(root.name)
		var is_exterior := false
		for p in EXTERIOR_PATHS:
			if String(p).get_file().get_basename() == scene_name:
				is_exterior = true
				break
		if not is_exterior:
			print("[Minimap] Scene name not in exterior paths, clearing minimap:", scene_name)
			_clear_minimap()
			visible = false
			return
	
	if root != null:
		# Make sure minimap is visible for exterior scenes
		visible = true
		# If we have a cached minimap for this scene, use it immediately
		var key := _find_cached_scene_key(root)
		if key != "" and scene_minimap_cache.has(key):
			print("[Minimap] scan: using cached minimap for:", key)
			_use_cached_minimap(key)
			# Still try to acquire player for camera centering
			var found_cached_player := tree.get_nodes_in_group("player")
			if not found_cached_player.is_empty() and found_cached_player[0] is Node2D:
				player = found_cached_player[0]
			if player != null:
				minimap_camera.global_position = player.global_position
			return

		var found_players := tree.get_nodes_in_group("player")
		if not found_players.is_empty() and found_players[0] is Node2D:
			player = found_players[0]
		else:
			var maybe_player := root.find_child("Player", true, false)
			if maybe_player != null and maybe_player is Node2D:
				player = maybe_player
			else:
				# Common alternate name in this project
				var maybe_player_m := root.find_child("PlayerM", true, false)
				if maybe_player_m != null and maybe_player_m is Node2D:
					player = maybe_player_m
				else:
					for n in root.get_children():
						if n is Node2D and String(n.name).to_lower().contains("player"):
							player = n
							break

	tilemap_layers.clear()
	if root != null:
		for node in root.find_children("*", "TileMapLayer", true, false):
			if node != null and node is TileMapLayer:
				tilemap_layers.append(node)

	if not tilemap_layers.is_empty():
		_copy_tilemap_layers()
		# Cache the built minimap for this scene for instant reuse later
		var save_key := _get_scene_cache_key(root)
		_cache_current_minimap(save_key)
		print("[Minimap] built and cached minimap for:", save_key)
		# If no player, center camera on map bounds
		if player == null:
			var bounds := _compute_map_bounds()
			if bounds.has_area():
				var center := bounds.get_center()
				minimap_camera.global_position = _clamp_camera_to_bounds(center)
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos
	
	# Re-check waypoint after building minimap
	var task_manager_check := get_node_or_null("/root/TaskManager")
	if task_manager_check != null and task_manager_check.has_waypoint():
		var target_scene_check: String = task_manager_check.get_current_task_scene_target()
		var target_pos_check: Vector2 = task_manager_check.get_current_waypoint_position()
		_on_waypoint_set(target_scene_check, target_pos_check)
	
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")


func _retry_build_loop() -> void:
	if _build_retry_attempts >= _MAX_BUILD_ATTEMPTS:
		print("[Minimap] retry stopped: max attempts reached")
		return
	_build_retry_attempts += 1
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(_RETRY_DELAY_SEC).timeout.connect(func():
		if not is_instance_valid(self):
			return
		# If already built (children exist), stop
		if minimap_root.get_child_count() > 0:
			print("[Minimap] retry success on attempt", _build_retry_attempts)
			emit_signal("minimap_ready")
			return
		print("[Minimap] retry attempt", _build_retry_attempts)
		_scan_and_build()
		if minimap_root.get_child_count() == 0:
			_retry_build_loop()
	)


func _compute_map_bounds() -> Rect2:
	var has_any := false
	var min_pos := Vector2(1e9, 1e9)
	var max_pos := Vector2(-1e9, -1e9)
	for src_layer in tilemap_layers:
		if src_layer == null:
			continue
		var used_cells := []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		for cell in used_cells:
			if cell is Vector2i:
				var local: Vector2 = src_layer.map_to_local(cell)
				var world: Vector2 = src_layer.to_global(local)
				min_pos.x = min(min_pos.x, world.x)
				min_pos.y = min(min_pos.y, world.y)
				max_pos.x = max(max_pos.x, world.x)
				max_pos.y = max(max_pos.y, world.y)
				has_any = true
	if not has_any:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)


func _cache_current_minimap(scene_path: String) -> void:
	if scene_path.is_empty():
		print("[Minimap] cache skipped: empty scene_path")
		return
	# Create a temporary root and duplicate current minimap layers under it
	var temp_root := Node2D.new()
	for c in minimap_root.get_children():
		var dup := c.duplicate()
		if dup != null:
			temp_root.add_child(dup)
			dup.owner = temp_root
	var packed := PackedScene.new()
	var ok := packed.pack(temp_root)
	if ok == OK:
		scene_minimap_cache[scene_path] = packed
		print("[Minimap] cache stored for:", scene_path)
	else:
		print("[Minimap] cache pack FAILED for:", scene_path)
	# Cleanup temp container (its children will be freed with it)
	temp_root.queue_free()
	# Clear pending target once cached
	pending_scene_path = ""


func _use_cached_minimap(scene_path: String) -> void:
	if not scene_minimap_cache.has(scene_path):
		print("[Minimap] use_cache skipped: no entry for:", scene_path)
		return
	_clear_minimap()
	var inst := (scene_minimap_cache[scene_path] as PackedScene).instantiate()
	if inst == null:
		print("[Minimap] use_cache FAILED: instantiate returned null for:", scene_path)
		return
	# Move children from the instantiated container into minimap_root
	for c in inst.get_children():
		inst.remove_child(c)
		minimap_root.add_child(c)
	inst.queue_free()
	# Using cache consumed pending path
	pending_scene_path = ""

	# Ensure viewport/camera and visibility
	if viewport != null:
		if viewport.has_method("set_update_mode"):
			viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera != null:
		if minimap_camera.has_method("make_current"):
			minimap_camera.make_current()
		elif "enabled" in minimap_camera:
			minimap_camera.enabled = true
	visible = true

	# Position camera: follow player if available, else center on bounds (from cached layers)
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos
		if player_marker != null:
			player_marker.global_position = player.global_position
			player_marker.visible = false
	else:
		var bounds := _compute_cached_minimap_bounds()
		if bounds.has_area():
			var center := bounds.get_center()
			minimap_camera.global_position = _clamp_camera_to_bounds(center)
		else:
			print("[Minimap] use_cache: empty bounds after instancing for:", scene_path)
	
	# Re-check waypoint after using cached minimap
	var task_manager := get_node_or_null("/root/TaskManager")
	if task_manager != null and task_manager.has_waypoint():
		var target_scene: String = task_manager.get_current_task_scene_target()
		var target_pos: Vector2 = task_manager.get_current_waypoint_position()
		_on_waypoint_set(target_scene, target_pos)
	
	# Signal readiness
	emit_signal("minimap_ready")


func _resolve_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	player = null
	var found_players := tree.get_nodes_in_group("player")
	if not found_players.is_empty() and found_players[0] is Node2D:
		player = found_players[0]
		return
	if root != null:
		var maybe_player := root.find_child("Player", true, false)
		if maybe_player != null and maybe_player is Node2D:
			player = maybe_player
			return
		var maybe_player_m := root.find_child("PlayerM", true, false)
		if maybe_player_m != null and maybe_player_m is Node2D:
			player = maybe_player_m
			return
		for n in root.get_children():
			if n is Node2D and String(n.name).to_lower().contains("player"):
				player = n
				return


func _compute_cached_minimap_bounds() -> Rect2:
	# Compute bounds from the duplicated TileMapLayers under minimap_root
	var has_any := false
	var min_pos := Vector2(1e9, 1e9)
	var max_pos := Vector2(-1e9, -1e9)
	for child in minimap_root.get_children():
		if child is TileMapLayer:
			var used := []
			if child.has_method("get_used_cells"):
				used = child.get_used_cells()
			for cell in used:
				if cell is Vector2i:
					var local: Vector2 = child.map_to_local(cell)
					var world: Vector2 = child.to_global(local)
					min_pos.x = min(min_pos.x, world.x)
					min_pos.y = min(min_pos.y, world.y)
					max_pos.x = max(max_pos.x, world.x)
					max_pos.y = max(max_pos.y, world.y)
					has_any = true
	if not has_any:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)


func _get_scene_cache_key(root_scene: Node) -> String:
	# Prefer the scene's file path when available (most stable).
	# If not available (e.g., change_scene_to_packed), use the pending transition target.
	# Finally, fall back to the scene's name.
	var path := ""
	if root_scene != null and "scene_file_path" in root_scene:
		path = String(root_scene.scene_file_path)
	if not path.is_empty():
		return path
	if pending_scene_path != null and not String(pending_scene_path).is_empty():
		return String(pending_scene_path)
	return String(root_scene.name)


func _find_cached_scene_key(root_scene: Node) -> String:
	# Try multiple identifiers to find an existing cache entry
	if root_scene == null:
		return ""
	var file_path := ""
	if "scene_file_path" in root_scene:
		file_path = String(root_scene.scene_file_path)
	if not file_path.is_empty():
		var canon := _normalize_exterior_path(file_path)
		if scene_minimap_cache.has(file_path):
			return file_path
		if canon != "" and scene_minimap_cache.has(canon):
			return canon
	if pending_scene_path != null and not String(pending_scene_path).is_empty():
		var pend := String(pending_scene_path)
		var pcanon := _normalize_exterior_path(pend)
		if scene_minimap_cache.has(pend):
			return pend
		if pcanon != "" and scene_minimap_cache.has(pcanon):
			return pcanon
	# Match by scene file basename against known exterior paths
	var base := String(root_scene.name)
	for p in EXTERIOR_PATHS:
		var fname := String(p).get_file().get_basename()
		if fname == base:
			if scene_minimap_cache.has(p):
				return p
	return ""


func _normalize_exterior_path(path: String) -> String:
	# Map any incoming path to its canonical EXTERIOR_PATHS entry by basename
	if path.is_empty():
		return ""
	var basename := String(path).get_file().get_basename()
	for p in EXTERIOR_PATHS:
		if String(p).get_file().get_basename() == basename:
			return p
	return ""

func _is_exterior_scene(root_scene: Node) -> bool:
	# Check if the current scene is one of the exterior scenes
	if root_scene == null:
		return false
	var scene_path := ""
	if "scene_file_path" in root_scene:
		scene_path = String(root_scene.scene_file_path)
	if not scene_path.is_empty():
		var normalized := _normalize_exterior_path(scene_path)
		return not normalized.is_empty()
	# Try matching by name
	var scene_name := String(root_scene.name)
	for p in EXTERIOR_PATHS:
		if String(p).get_file().get_basename() == scene_name:
			return true
	return false


# ----------------------
# Offline Prebake Helpers
# ----------------------
# DISABLED: Prebaking causes crashes - only build minimaps on-demand when entering exterior scenes
# func _prebake_minimaps_deferred() -> void:
# 	# Deferred version that runs after a delay to avoid blocking startup
# 	await get_tree().create_timer(1.0).timeout  # Wait 1 second after startup
# 	_prebake_minimaps()

# func _prebake_minimaps() -> void:
# 	for p in EXTERIOR_PATHS:
# 		if not scene_minimap_cache.has(p):
# 			_prebuild_minimap_for_scene_path(p)


func _prebuild_minimap_for_scene_path(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var res := ResourceLoader.load(scene_path)
	if res == null or not (res is PackedScene):
		return
	var inst := (res as PackedScene).instantiate()
	if inst == null:
		return
	# Collect TileMapLayer nodes
	var layers: Array = []
	for node in inst.find_children("*", "TileMapLayer", true, false):
		layers.append(node)
	# Build a lightweight minimap subtree
	var temp_root := Node2D.new()
	for src_layer in layers:
		if src_layer == null:
			continue
		var dst_layer := TileMapLayer.new()
		dst_layer.tile_set = src_layer.tile_set
		dst_layer.z_index = src_layer.z_index
		dst_layer.global_transform = src_layer.global_transform
		temp_root.add_child(dst_layer)
		dst_layer.owner = temp_root
		var used_cells := []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		for cell in used_cells:
			if cell is Vector2i:
				var source_id = src_layer.get_cell_source_id(cell)
				var atlas_coords = src_layer.get_cell_atlas_coords(cell)
				dst_layer.set_cell(cell, source_id, atlas_coords)
	var packed := PackedScene.new()
	if packed.pack(temp_root) == OK:
		scene_minimap_cache[scene_path] = packed
	inst.free()
	temp_root.queue_free()

func is_ready() -> bool:
	return minimap_root != null and minimap_root.get_child_count() > 0


func _clear_minimap() -> void:
	# Remove any previously duplicated layers and clear the single TileMap
	for c in minimap_root.get_children():
		minimap_root.remove_child(c)
		c.queue_free()
	if minimap_tilemap != null:
		minimap_tilemap.clear()


func set_player(p: Node2D) -> void:
	if p == null:
		push_warning("Minimap.set_player called with null")
		return
	player = p
	print("🎯 Minimap: tracking player:", player)


func set_tilemap_layers(layers: Array) -> void:
	if layers == null or layers.is_empty():
		push_warning("Minimap.set_tilemap_layers called with empty array")
		return

	tilemap_layers.clear()
	for l in layers:
		if l != null and l is TileMapLayer:
			tilemap_layers.append(l)

	if tilemap_layers.is_empty():
		push_warning("Minimap: no valid TileMapLayer nodes found in provided list")
		return

	_copy_tilemap_layers()


func _copy_tilemap_layers() -> void:
	if tilemap_layers.is_empty():
		return

	# Clear any previous duplicates under minimap_root
	for c in minimap_root.get_children():
		minimap_root.remove_child(c)
		c.queue_free()

	var total_cells := 0

	for src_layer in tilemap_layers:
		if src_layer == null:
			continue

		# Duplicate a lightweight layer for the minimap so we can keep per-layer TileSets
		var dst_layer := TileMapLayer.new()
		dst_layer.tile_set = src_layer.tile_set
		dst_layer.z_index = src_layer.z_index
		minimap_root.add_child(dst_layer)

		# Align transforms to match the world
		dst_layer.global_transform = src_layer.global_transform

		var used_cells: Array = []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		else:
			continue

		for cell in used_cells:
			if cell is Vector2i:
				var source_id = src_layer.get_cell_source_id(cell)
				var atlas_coords = src_layer.get_cell_atlas_coords(cell)
				dst_layer.set_cell(cell, source_id, atlas_coords)
				total_cells += 1

	print("✅ Minimap: copied", tilemap_layers.size(), "layers, total cells:", total_cells)

	# After copying, ensure masked view uses the latest viewport texture
	if masked_rect != null and viewport != null:
		masked_rect.texture = viewport.get_texture()


func _clamp_camera_to_bounds(target_pos: Vector2) -> Vector2:
	if minimap_camera == null or viewport == null:
		return target_pos
	
	# Get map bounds from cached layers or source layers
	var bounds := _compute_cached_minimap_bounds()
	if not bounds.has_area():
		bounds = _compute_map_bounds()
	
	if not bounds.has_area():
		# No bounds available, return target position unchanged
		return target_pos
	
	# Calculate viewport size in world coordinates
	var viewport_size := Vector2(viewport.size)
	var world_viewport_size := viewport_size / minimap_camera.zoom
	
	# Calculate the camera limits (bounds minus half viewport on each side)
	var half_viewport := world_viewport_size / 2.0
	var min_x := bounds.position.x + half_viewport.x
	var max_x := bounds.position.x + bounds.size.x - half_viewport.x
	var min_y := bounds.position.y + half_viewport.y
	var max_y := bounds.position.y + bounds.size.y - half_viewport.y
	
	# Clamp position
	var clamped_x: float = clamp(target_pos.x, min_x, max_x)
	var clamped_y: float = clamp(target_pos.y, min_y, max_y)
	
	return Vector2(clamped_x, clamped_y)


func _process(_delta: float) -> void:
	# Only process if minimap is visible (exterior scene)
	if not visible:
		return
	# Ensure the raw SubViewportContainer stays hidden (we render via masked TextureRect)
	if viewport_container != null and viewport_container.visible:
		viewport_container.visible = false
	if player != null and minimap_camera != null:
		var target_pos := player.global_position
		# Clamp camera position to map bounds to avoid showing blank space
		var clamped_pos := _clamp_camera_to_bounds(target_pos)
		minimap_camera.global_position = clamped_pos
		if player_marker != null:
			player_marker.global_position = player.global_position
			player_marker.visible = false

	# Update waypoint marker position if active
	if waypoint_active:
		# Ensure waypoint marker exists
		if waypoint_marker == null:
			_create_waypoint_marker()
		
		if waypoint_marker != null:
			# Ensure waypoint marker is in the viewport
			if waypoint_marker.get_parent() != viewport:
				if waypoint_marker.get_parent() != null:
					waypoint_marker.get_parent().remove_child(waypoint_marker)
				if viewport != null:
					viewport.add_child(waypoint_marker)
					print("📍 Minimap: Waypoint marker re-parented to viewport in _process")
			
			# Update waypoint position based on current scene (in case scene changed)
			# Get base position from TaskManager and recalculate for current scene
			var task_manager := get_node_or_null("/root/TaskManager")
			if task_manager != null and task_manager.has_waypoint():
				var base_pos: Vector2 = task_manager.get_current_waypoint_position()
				var updated_pos: Vector2 = _get_waypoint_position_for_current_scene(waypoint_target_scene, base_pos)
				if updated_pos.distance_to(waypoint_position) > 10.0:  # Only update if significantly different
					waypoint_position = updated_pos
					print("📍 Minimap: Updated waypoint position to ", waypoint_position, " for current scene")
			
			# Always use the waypoint position (target location) regardless of current scene
			waypoint_marker.global_position = waypoint_position
			# Make it pulse for visibility (very subtle animation, small size)
			var pulse := sin(Engine.get_process_frames() * 0.2) * 0.1 + 1.0
			waypoint_marker.scale = Vector2(pulse, pulse) * 1.0  # Very small size with subtle pulse
			# Ensure it stays visible when in exterior scenes
			waypoint_marker.visible = true
			waypoint_marker.z_index = 1000  # Above everything
			waypoint_marker.modulate = Color(1, 0.2, 0.2, 1)  # Bright red
			
			# Check if waypoint is in camera view and update edge indicator
			if minimap_camera != null:
				var camera_pos := minimap_camera.global_position
				var viewport_size := Vector2(viewport.size) if viewport != null else Vector2(256, 256)
				var world_viewport_size := viewport_size / minimap_camera.zoom
				var half_viewport := world_viewport_size * 0.5
				var distance := waypoint_position.distance_to(camera_pos)
				
				# Check if waypoint is within camera view bounds
				var waypoint_offset := waypoint_position - camera_pos
				var in_view_x: bool = abs(waypoint_offset.x) <= half_viewport.x
				var in_view_y: bool = abs(waypoint_offset.y) <= half_viewport.y
				var in_view: bool = in_view_x and in_view_y
				
				if not in_view:
					# Waypoint is off-screen - hide the marker and show edge indicator
					waypoint_marker.visible = false
					_update_waypoint_edge_indicator(camera_pos, waypoint_position, viewport_size)
				else:
					# Waypoint is in view - show marker and hide edge indicator
					waypoint_marker.visible = true
					waypoint_marker.modulate = Color(1, 0.2, 0.2, 1)  # Bright red
					if waypoint_edge_indicator != null:
						waypoint_edge_indicator.visible = false
			
			# Debug: Print waypoint status every 60 frames
			if Engine.get_process_frames() % 60 == 0:
				var has_texture := waypoint_marker.texture != null
				var is_in_tree := waypoint_marker.is_inside_tree()
				var marker_scale := waypoint_marker.scale
				print("📍 Minimap DEBUG: waypoint_active=", waypoint_active, ", visible=", waypoint_marker.visible, ", position=", waypoint_marker.global_position, ", scale=", marker_scale, ", has_texture=", has_texture, ", in_tree=", is_in_tree, ", z_index=", waypoint_marker.z_index, ", modulate=", waypoint_marker.modulate)
	elif waypoint_marker != null and not waypoint_active:
		# Hide waypoint marker when not active
		waypoint_marker.visible = false
		if waypoint_edge_indicator != null:
			waypoint_edge_indicator.visible = false

	# Keep masked rect texture and position in sync with SubViewportContainer
	if masked_rect != null and viewport != null:
		masked_rect.texture = viewport.get_texture()
		_align_minimap_to_container()


# Ensures the minimap looks identical across direct loads and story-flow transitions
func _apply_consistent_style() -> void:
	# Hide the original SubViewportContainer UI; we show the circular masked version
	if viewport_container != null:
		viewport_container.visible = false

	# Make sure masked view exists
	if masked_rect == null:
		_setup_circular_masked_view()
		_setup_compass_letters()

	# Keep the viewport rendering every frame
	if viewport != null:
		if viewport.has_method("set_update_mode"):
			viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Camera settings
	if minimap_camera != null:
		if minimap_camera.has_method("make_current"):
			minimap_camera.make_current()
		elif "enabled" in minimap_camera:
			minimap_camera.enabled = true
		minimap_camera.zoom = Vector2(MINIMAP_ZOOM, MINIMAP_ZOOM)

	# Player marker scale (hidden)
	if player_marker != null:
		player_marker.scale = Vector2(PLAYER_MARKER_SCALE, PLAYER_MARKER_SCALE)
		player_marker.visible = false

	# Ensure masked texture is the current viewport texture
	if masked_rect != null and viewport != null:
		masked_rect.texture = viewport.get_texture()

	# Align UI
	_align_minimap_to_container()
	_update_compass_positions()


# 🆕 Implemented Update Method
func update_minimap() -> void:
	"""
	Call this method to refresh the minimap manually.
	It re-copies all the tilemap layers and ensures the minimap camera follows the latest data.
	"""
	if tilemap_layers.is_empty():
		push_warning("⚠️ Minimap.update_minimap() called but no tilemap layers are set.")
		return

	print("🔄 Minimap: updating...")
	_copy_tilemap_layers()

	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos

	print("✅ Minimap: update complete.")

func _center_minimap_on_screen() -> void:
	if masked_rect == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# Place at top-right corner
	var diameter := masked_rect.size.x
	var margin := 24.0
	masked_rect.position = Vector2(viewport_size.x - diameter - margin, margin)
	if border_rect != null:
		border_rect.position = masked_rect.position
	_update_compass_positions()

func _setup_circular_masked_view() -> void:
	# Hide the raw SubViewportContainer rendering; we will display via TextureRect
	if viewport_container != null:
		viewport_container.visible = false
	# Create a TextureRect that displays the SubViewport's texture
	masked_rect = TextureRect.new()
	masked_rect.name = "MinimapCircle"
	masked_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	masked_rect.stretch_mode = TextureRect.STRETCH_SCALE
	masked_rect.size = Vector2(180, 180)
	masked_rect.texture = viewport.get_texture() if viewport != null else null
	masked_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(masked_rect)
	# Add a subtle border behind using a ColorRect with shader for ring
	border_rect = ColorRect.new()
	border_rect.color = Color(0, 0, 0, 0)
	border_rect.size = masked_rect.size
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border_rect)
	border_rect.move_to_front()
	masked_rect.move_to_front()
	# Circular mask shader for the TextureRect
	var shader_code := """
	shader_type canvas_item;
	uniform float feather = 2.0; // pixels
	
	void fragment() {
		vec2 uv = UV; // 0..1 within rect
		vec2 c = uv * 2.0 - vec2(1.0);
		float r = length(c);
		float edge = 1.0 - smoothstep(1.0 - (feather / float(textureSize(TEXTURE, 0).x))*2.0, 1.0, r);
		vec4 col = texture(TEXTURE, uv);
		COL = vec4(col.rgb, col.a * edge);
	}
	"""
	var shader := Shader.new()
	shader.code = shader_code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	masked_rect.material = mat
	# Optional ring border shader
	var border_shader_code := """
	shader_type canvas_item;
	uniform vec4 ring_color : source_color = vec4(0.0,0.0,0.0,0.6);
	uniform float thickness = 3.0; // pixels
	
	void fragment() {
		vec2 uv = UV;
		vec2 c = uv * 2.0 - vec2(1.0);
		float r = length(c);
		float t = thickness / float(textureSize(SCREEN_TEXTURE, 0).x) * 2.0; // approx
		float ring = smoothstep(1.0, 1.0 - t, r) - smoothstep(1.0 - t, 1.0 - 2.0*t, r);
		COL = ring_color * ring;
	}
	"""
	var bshader := Shader.new()
	bshader.code = border_shader_code
	var bmat := ShaderMaterial.new()
	bmat.shader = bshader
	border_rect.material = bmat
	# Initial placement
	_center_minimap_on_screen()

func _setup_compass_letters() -> void:
	if masked_rect == null:
		return
	# Create four labels if they don't exist
	if north_label == null:
		north_label = Label.new()
		north_label.text = "N"
		north_label.add_theme_color_override("font_color", Color(0,0,0))
		north_label.add_theme_color_override("font_outline_color", Color(0,0,0))
		north_label.add_theme_constant_override("outline_size", 3)
		add_child(north_label)
	if east_label == null:
		east_label = Label.new()
		east_label.text = "E"
		east_label.add_theme_color_override("font_color", Color(0,0,0))
		east_label.add_theme_color_override("font_outline_color", Color(0,0,0))
		east_label.add_theme_constant_override("outline_size", 4)
		add_child(east_label)
	if south_label == null:
		south_label = Label.new()
		south_label.text = "S"
		south_label.add_theme_color_override("font_color", Color(0,0,0))
		south_label.add_theme_color_override("font_outline_color", Color(0,0,0))
		south_label.add_theme_constant_override("outline_size", 4)
		add_child(south_label)
	if west_label == null:
		west_label = Label.new()
		west_label.text = "W"
		west_label.add_theme_color_override("font_color", Color(0,0,0))
		west_label.add_theme_color_override("font_outline_color", Color(0,0,0))
		west_label.add_theme_constant_override("outline_size", 4)
		add_child(west_label)
	_update_compass_positions()

func _update_compass_positions() -> void:
	if masked_rect == null:
		return
	var pos := masked_rect.position
	var size := masked_rect.size
	var center := pos + size * 0.5
	var margin := 6.0
	# Place labels just outside the circle for clarity
	if north_label != null:
		north_label.position = Vector2(center.x - north_label.size.x * 0.5, pos.y - north_label.size.y - margin)
	if south_label != null:
		south_label.position = Vector2(center.x - south_label.size.x * 0.5, pos.y + size.y + margin)
	if east_label != null:
		east_label.position = Vector2(pos.x + size.x + margin, center.y - east_label.size.y * 0.5)
	if west_label != null:
		west_label.position = Vector2(pos.x - west_label.size.x - margin, center.y - west_label.size.y * 0.5)

func _align_minimap_to_container() -> void:
	if viewport_container == null or masked_rect == null:
		return
	# Use the SubViewportContainer's rect to size and center the circular minimap
	var pos := viewport_container.global_position
	var size := viewport_container.size
	masked_rect.size = size
	masked_rect.position = pos
	if border_rect != null:
		border_rect.size = size
		border_rect.position = pos
	_update_compass_positions()

func _create_waypoint_marker() -> void:
	"""Create a waypoint marker sprite for task navigation"""
	if waypoint_marker != null:
		# If marker already exists but might be orphaned, ensure it's in the viewport
		if waypoint_marker.get_parent() != viewport and viewport != null:
			if waypoint_marker.get_parent() != null:
				waypoint_marker.get_parent().remove_child(waypoint_marker)
			viewport.add_child(waypoint_marker)
			print("📍 Minimap: Waypoint marker re-parented to viewport in _create_waypoint_marker")
		return  # Already created
	
	if viewport == null:
		print("⚠️ Minimap: Cannot create waypoint marker - viewport is null")
		return
	
	# Create waypoint marker using icon_4_6.png
	waypoint_marker = Sprite2D.new()
	waypoint_marker.name = "WaypointMarker"
	
	# Load the waypoint icon
	var icon_path := "res://scenes/ui/UI by jer/used in UI/minimap items/icon_4_6.png"
	var waypoint_texture := load(icon_path) as Texture2D
	if waypoint_texture == null:
		push_error("📍 Minimap: Failed to load waypoint icon from " + icon_path)
		# Fallback to player marker icon if available
		if player_marker != null and player_marker.texture != null:
			waypoint_texture = player_marker.texture
			print("📍 Minimap: Using player marker texture as fallback")
		else:
			print("⚠️ Minimap: No fallback texture available for waypoint marker")
			return
	
	waypoint_marker.texture = waypoint_texture
	waypoint_marker.z_index = 1000  # Above everything including player marker
	waypoint_marker.scale = Vector2(1.0, 1.0)  # Very small - similar to minimap arrow size
	waypoint_marker.visible = false
	waypoint_marker.modulate = Color(1, 0.2, 0.2, 1)  # Bright red to stand out
	waypoint_marker.show_behind_parent = false  # Ensure it's not hidden
	viewport.add_child(waypoint_marker)
	
	# Verify it was added correctly
	if waypoint_marker.get_parent() == viewport:
		print("✅ Minimap: Waypoint marker created and added to viewport (z_index: ", waypoint_marker.z_index, ", scale: ", waypoint_marker.scale, ", texture: ", "loaded" if waypoint_marker.texture != null else "MISSING", ")")
	else:
		print("❌ Minimap: ERROR - Waypoint marker parent is not viewport! Parent: ", waypoint_marker.get_parent())
	
	# Create edge indicator for when waypoint is off-screen
	_create_waypoint_edge_indicator()

func _create_waypoint_edge_indicator() -> void:
	"""Create an edge indicator sprite that shows at the minimap edge when waypoint is off-screen"""
	if waypoint_edge_indicator != null:
		return  # Already created
	
	# Create edge indicator using the same icon
	var icon_path := "res://scenes/ui/UI by jer/used in UI/minimap items/icon_4_6.png"
	var edge_texture := load(icon_path) as Texture2D
	if edge_texture == null:
		# Fallback to player marker icon
		if player_marker != null and player_marker.texture != null:
			edge_texture = player_marker.texture
		else:
			print("⚠️ Minimap: Cannot create edge indicator - no texture available")
			return
	
	waypoint_edge_indicator = Sprite2D.new()
	waypoint_edge_indicator.name = "WaypointEdgeIndicator"
	waypoint_edge_indicator.texture = edge_texture
	waypoint_edge_indicator.z_index = 2000  # Very high z-index to be above everything
	waypoint_edge_indicator.scale = Vector2(0.8, 0.8)  # Very small - similar to minimap arrow size
	waypoint_edge_indicator.modulate = Color(1, 0, 0, 1)  # Pure red
	waypoint_edge_indicator.visible = false
	
	# Add to CanvasLayer (not viewport) so it's always visible
	add_child(waypoint_edge_indicator)
	print("✅ Minimap: Waypoint edge indicator created")

func _update_waypoint_edge_indicator(camera_pos: Vector2, waypoint_pos: Vector2, viewport_size: Vector2) -> void:
	"""Update the edge indicator position and rotation to point toward the waypoint"""
	if waypoint_edge_indicator == null:
		_create_waypoint_edge_indicator()
		if waypoint_edge_indicator == null:
			return
	
	# Calculate direction from camera to waypoint (in world coordinates)
	var waypoint_offset := waypoint_pos - camera_pos
	
	# Avoid division by zero
	if waypoint_offset.length() < 0.001:
		waypoint_edge_indicator.visible = false
		return
	
	var direction := waypoint_offset.normalized()
	
	# Debug: Print direction info every 120 frames to verify it's pointing correctly
	if Engine.get_process_frames() % 120 == 0:
		var angle_deg := rad_to_deg(atan2(direction.y, direction.x))
		print("📍 Edge Indicator: Camera at ", camera_pos, ", Waypoint at ", waypoint_pos, ", Direction: ", direction, ", Angle: ", angle_deg, "°")
	
	# Get minimap circle position and size
	if masked_rect == null:
		return
	
	var minimap_center := masked_rect.position + masked_rect.size * 0.5
	var minimap_radius := masked_rect.size.x * 0.5
	
	# Calculate position on the edge of the circle
	# Position the indicator at the edge, pointing outward
	var edge_distance := minimap_radius - 8  # Slightly inside the edge for better visibility
	var edge_pos := minimap_center + direction * edge_distance
	
	# Set position (use position since it's a child of CanvasLayer)
	waypoint_edge_indicator.position = edge_pos
	
	# Rotate to point toward the waypoint
	# Calculate angle from direction vector (atan2 gives angle in radians)
	# atan2(y, x) gives angle where 0 is right, PI/2 is down, PI is left, -PI/2 is up
	var angle := atan2(direction.y, direction.x)
	# Adjust rotation so sprite points in the correct direction
	# Try different adjustments: if sprite points right by default, use angle directly
	# If sprite points up by default, add PI/2. If it points down, subtract PI/2.
	# Testing: try without adjustment first, then with PI/2 if needed
	waypoint_edge_indicator.rotation = angle  # Try pointing right = 0 degrees first
	
	# Make it pulse for visibility (very subtle pulse)
	var pulse := sin(Engine.get_process_frames() * 0.2) * 0.1 + 1.0
	waypoint_edge_indicator.scale = Vector2(pulse, pulse) * 0.8  # Very small arrow size with subtle pulse
	
	# Make it visible
	waypoint_edge_indicator.visible = true
	waypoint_edge_indicator.z_index = 2000

func _get_waypoint_position_for_current_scene(target_scene: String, base_position: Vector2) -> Vector2:
	"""Get the appropriate waypoint position based on current scene"""
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return base_position
	
	var current_scene_path := ""
	if "scene_file_path" in current_scene:
		current_scene_path = String(current_scene.scene_file_path)
	
	var is_target_police := target_scene.contains("police_station")
	var is_target_barangay := target_scene.contains("baranggay_court") or target_scene.contains("barangay_court")
	var is_target_morgue := target_scene.contains("apartment_morgue") or target_scene.contains("morgue")
	
	# If we're already at the target scene, use the base position
	if is_target_police and current_scene_path.contains("police_station"):
		return base_position  # Use actual police station position (336, 992)
	if is_target_barangay and (current_scene_path.contains("baranggay_court") or current_scene_path.contains("barangay_court")):
		return base_position  # Use actual barangay hall position (144, 395)
	if is_target_morgue and current_scene_path.contains("apartment_morgue"):
		return base_position
	
	# Determine which transition area to use based on target scene and current scene
	var transition_area_name := ""
	
	if current_scene_path.contains("apartment_morgue"):
		if is_target_police:
			transition_area_name = "from_morgue_to_police_station"
		elif is_target_barangay:
			transition_area_name = "from_morgue_to_camp"  # First step towards barangay
		elif is_target_morgue:
			return base_position
	elif current_scene_path.contains("hotel_hospital"):
		if is_target_police:
			transition_area_name = "from_hospital_to_police_station"
		elif is_target_barangay:
			# Check which transition leads to barangay (hospital -> market -> barangay or hospital -> morgue -> camp -> barangay)
			transition_area_name = "from_hospital_to_market"  # Direct path to barangay via market
		elif is_target_morgue:
			transition_area_name = "from_hospital_to_morgue"
	elif current_scene_path.contains("police_station"):
		if is_target_barangay:
			transition_area_name = "from_police_to_baranggay"
		elif is_target_morgue:
			transition_area_name = "from_police_to_morgue"
	elif current_scene_path.contains("terminal_market"):
		if is_target_police:
			transition_area_name = "from_market_to_police"
		elif is_target_barangay:
			transition_area_name = "from_market_to_baranggay"
		elif is_target_morgue:
			transition_area_name = "from_market_to_police"
	elif current_scene_path.contains("camp"):
		if is_target_police:
			transition_area_name = "from_camp_to_morgue"  # First step towards police
		elif is_target_barangay:
			transition_area_name = "from_camp_to_barangay"
		elif is_target_morgue:
			transition_area_name = "from_camp_to_morgue"
	elif current_scene_path.contains("baranggay_court") or current_scene_path.contains("barangay_court"):
		if is_target_police:
			transition_area_name = "from_barangay_to_police_station"
		elif is_target_morgue:
			transition_area_name = "from_barangay_to_police_station"
	
	# Find the transition area in the current scene
	if transition_area_name != "":
		var transition_area := current_scene.find_child(transition_area_name, true, false)
		if transition_area != null and transition_area is Area2D:
			# Get the global position of the Area2D
			var area_pos := (transition_area as Area2D).global_position
			# Try to get the CollisionShape2D position for more accuracy
			var collision := transition_area.find_child("CollisionShape2D", true, false)
			if collision != null and collision is CollisionShape2D:
				var collision_pos := (collision as CollisionShape2D).global_position
				print("📍 Minimap: Found transition area '", transition_area_name, "' at ", collision_pos, " (Area2D: ", area_pos, ")")
				return collision_pos
			else:
				print("📍 Minimap: Found transition area '", transition_area_name, "' at ", area_pos, " (no CollisionShape2D)")
				return area_pos
		else:
			print("⚠️ Minimap: Transition area '", transition_area_name, "' not found in current scene")
	
	# Fallback to base position if transition area not found
	return base_position

func _on_waypoint_set(target_scene: String, target_position: Vector2) -> void:
	"""Handle waypoint set signal from TaskManager - called when new task is set"""
	# Reset waypoint state for new task
	waypoint_target_scene = target_scene
	
	# Get the appropriate waypoint position based on current scene
	waypoint_position = _get_waypoint_position_for_current_scene(target_scene, target_position)
	
	# waypoint_active will be set based on whether we're in exterior scene below
	
	# Ensure waypoint marker exists
	if waypoint_marker == null:
		_create_waypoint_marker()
		if waypoint_marker == null:
			print("⚠️ Minimap: Failed to create waypoint marker")
			return
	
	# Ensure edge indicator exists
	if waypoint_edge_indicator == null:
		_create_waypoint_edge_indicator()
	
	# Ensure waypoint marker is in the viewport
	if waypoint_marker.get_parent() != viewport:
		if waypoint_marker.get_parent() != null:
			waypoint_marker.get_parent().remove_child(waypoint_marker)
		if viewport != null:
			viewport.add_child(waypoint_marker)
			print("📍 Minimap: Waypoint marker re-parented to viewport")
	
	# Check if we're in an exterior scene
	var current_scene := get_tree().current_scene
	if current_scene == null:
		print("⚠️ Minimap: No current scene for waypoint")
		waypoint_active = false
		if waypoint_marker != null:
			waypoint_marker.visible = false
		return
	
	var current_scene_path := ""
	if "scene_file_path" in current_scene:
		current_scene_path = String(current_scene.scene_file_path)
	
	# Show waypoint on ALL exterior scenes - it points to where you need to go
	var is_exterior := _is_exterior_scene(current_scene)
	
	if is_exterior and waypoint_marker != null:
		waypoint_active = true
		waypoint_marker.visible = true
		# Use the target position (police station location) regardless of current scene
		waypoint_marker.global_position = target_position
		waypoint_marker.z_index = 1000  # Above everything
		waypoint_marker.scale = Vector2(1.0, 1.0)  # Very small - similar to minimap arrow size
		waypoint_marker.modulate = Color(1, 0.2, 0.2, 1)  # Bright red
		print("📍 Minimap: Waypoint shown at ", target_position, " pointing to ", target_scene, " (current scene: ", current_scene_path, ", is_exterior: ", is_exterior, ", marker visible: ", waypoint_marker.visible, ", scale: ", waypoint_marker.scale, ", z_index: ", waypoint_marker.z_index, ")")
	else:
		waypoint_active = false
		if waypoint_marker != null:
			waypoint_marker.visible = false
		print("📍 Minimap: Waypoint set but not in exterior scene (current: ", current_scene_path, ", target: ", target_scene, ", is_exterior: ", is_exterior, ")")

func _on_waypoint_cleared() -> void:
	"""Handle waypoint cleared signal from TaskManager - called when task is completed"""
	waypoint_active = false
	waypoint_target_scene = ""
	waypoint_position = Vector2.ZERO
	
	# Hide both waypoint marker and edge indicator
	if waypoint_marker != null:
		waypoint_marker.visible = false
	if waypoint_edge_indicator != null:
		waypoint_edge_indicator.visible = false
	
	print("📍 Minimap: Waypoint cleared - indicator hidden (task completed)")
