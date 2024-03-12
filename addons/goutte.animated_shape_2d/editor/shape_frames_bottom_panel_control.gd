@tool
extends Control
class_name ShapeFramesBottomPanelControl
#class_name ShapeFramesEditor

## Bottom panel for the Editor, shown along with Output, Debugger, etc.
## Dedicated to editing a single AnimatedShape2D.
## Will show a list of animation names, and frames for each animation.

const FRAME_SCENE := preload("./shape_frame_editor.tscn")

@onready var animation_names_item_list: ItemList = %AnimationNamesItemList
@onready var frames_container := %FramesContainer

## The thing we are previewing and editing.
var animated_shape: AnimatedShape2D

## Used to access Editor things like UndoRedo.
## Someday we will not need this anymore, hopefully.
var editor_plugin: EditorPlugin

## Zoom level of the button previews ; only integers for now.  Contribs welcome.
var zoom_level := 1.0: set = set_zoom_level

## Customizable background color of previews.
var background_color := Color.WEB_GRAY

## Button Group for the various frames, so that only one is selected at a time.
## We assign this procedurally because assigning it in the scene did not work.
var frames_button_group: ButtonGroup

var currently_selected_animation_name: StringName

## Array of ShapeFrameEditor currently shown, for the selected animation.
## These are the children of frames_container, except when config is missing.
var frames_list: Array[ShapeFrameEditor] = []  # of ShapeFrameEditor


signal frame_selected(animation_name: String, frame_index: int)
signal frame_deselected(animation_name: String, frame_index: int)
signal frame_changed(animation_name: String, frame_index: int)


func configure(
	editor_plugin: EditorPlugin,
):
	self.editor_plugin = editor_plugin


func clear():
	self.animation_names_item_list.deselect_all()
	self.animation_names_item_list.clear()
	self.animated_shape = null
	clear_shape_frames()


func clear_shape_frames():
	# We iterate the container node and not the frames_list to also remove the
	# initial label helpers that appear when the AnimatedShape2D lacks config.
	for child in self.frames_container.get_children():
		child.queue_free()
	self.frames_list.clear()


func rebuild_gui(
	for_animated_shape: AnimatedShape2D,
	force := false,
):
	if (self.animated_shape == for_animated_shape) and not force:
		return
	
	clear()
	self.animated_shape = for_animated_shape
	
	#%BackgroundColorPicker.color = …  # from editor settings ?
	self.background_color = %BackgroundColorPicker.color
	
	var missing_requirements := false
	if not is_instance_valid(self.animated_shape.animated_sprite):
		var label := Label.new()
		label.text = tr("Please assign an input animated sprite to this AnimatedShape2D.")
		self.frames_container.add_child(label)
		missing_requirements = true
	if not is_instance_valid(self.animated_shape.collision_shape):
		var label := Label.new()
		label.text = tr("Please assign a target collision shape to this AnimatedShape2D.")
		self.frames_container.add_child(label)
		missing_requirements = true
	if not is_instance_valid(self.animated_shape.shape_frames):
		var label := Label.new()
		label.text = tr("Please create or load shape frames data for this AnimatedShape2D.")
		self.frames_container.add_child(label)
		missing_requirements = true
	
	var inspector := EditorInterface.get_inspector()
	if inspector.property_edited.is_connected(on_change_do_reload):
		inspector.property_edited.disconnect(on_change_do_reload)
	if missing_requirements:
		inspector.property_edited.connect(on_change_do_reload)
		return
	
	var animation_name := &"default"
	if is_instance_valid(self.animated_shape.animated_sprite):
		animation_name = self.animated_shape.animated_sprite.animation
	rebuild_animation_names_item_list(self.animated_shape, animation_name)


func rebuild_animation_names_item_list(
	animated_shape: AnimatedShape2D,
	selected_animation_name: String,
):
	if animated_shape == null:
		print("AnimatedShape2D: no animated shape is configured.")
		return
	if animated_shape.animated_sprite == null:
		print("AnimatedShape2D: no animated sprite is configured.")
		return
	if animated_shape.animated_sprite.sprite_frames == null:
		print("AnimatedShape2D: no sprite frames is configured.")
		return
	
	var index := 0
	var selected_index := 0
	for animation_name in animated_shape.animated_sprite.sprite_frames.get_animation_names():
		self.animation_names_item_list.add_item(animation_name)
		if animation_name == selected_animation_name:
			selected_index = index
		index += 1
	
	self.animation_names_item_list.select(selected_index)
	self.animation_names_item_list.item_selected.emit(selected_index)


func rebuild_view_of_animation(animation_name: String):
	clear_shape_frames()
	self.currently_selected_animation_name = animation_name
	
	self.frames_button_group = ButtonGroup.new()
	var frames_count := self.animated_shape.animated_sprite.sprite_frames.get_frame_count(animation_name)
	for frame_index in frames_count:
		var frame_scene := FRAME_SCENE.instantiate() as ShapeFrameEditor
		frame_scene.configure(self.animated_shape, animation_name, frame_index)
		frame_scene.set_undo_redo(self.editor_plugin.get_undo_redo())
		frame_scene.set_zoom_level(self.zoom_level)
		frame_scene.set_background_color(self.background_color)
		frame_scene.build(self.frames_button_group)
		self.frames_container.add_child(frame_scene)
		self.frames_list.append(frame_scene)
	
	for frame_scene: ShapeFrameEditor in self.frames_list:
		if frame_scene == null:
			continue
		frame_scene.frame_selected.connect(on_frame_selected.bind(frame_scene.animation_name, frame_scene.frame_index))
		frame_scene.frame_deselected.connect(on_frame_deselected.bind(frame_scene.animation_name, frame_scene.frame_index))
		frame_scene.changed.connect(on_frame_changed.bind(frame_scene.animation_name, frame_scene.frame_index))


func rebuild_view_of_animation_by_index(item_index: int):
	var animation_name := self.animation_names_item_list.get_item_text(item_index)
	rebuild_view_of_animation(animation_name)


func rebuild_view_of_selected_animation():
	var selected_animations_indices := self.animation_names_item_list.get_selected_items()
	if not selected_animations_indices.is_empty():
		rebuild_view_of_animation_by_index(selected_animations_indices[0])


func set_zoom_level(new_zoom_level: float):
	if new_zoom_level == zoom_level:
		return
	zoom_level = new_zoom_level
	rebuild_view_of_selected_animation()


func get_selected_frame() -> ShapeFrameEditor:
	for frame_editor: ShapeFrameEditor in self.frames_list:
		if frame_editor == null:
			continue
		if frame_editor.is_selected():
			return frame_editor
	return null


func get_frame_at(frame_index: int) -> ShapeFrameEditor:
	if frame_index < 0:
		return null
	if frame_index > self.frames_list.size() - 1:
		return null
	return self.frames_list[frame_index]


func shift_frames_from_selected(cursor_direction: int) -> Error:
	var frame_editor := get_selected_frame()
	if not is_instance_valid(frame_editor):
		return ERR_CANT_ACQUIRE_RESOURCE
	if frame_editor.get_shape_frame() == null:
		return ERR_DOES_NOT_EXIST
	var shifted := shift_frames(cursor_direction, frame_editor.frame_index)
	if shifted != OK:
		return shifted
	var new_selected := get_frame_at(frame_editor.frame_index + cursor_direction)
	if is_instance_valid(new_selected):
		new_selected.select()
	return OK


## Shift the frames from frame index, one slot in the specified direction.
func shift_frames(cursor_direction: int, from_frame_index: int) -> Error:
	if (cursor_direction != 1) and (cursor_direction != -1):
		push_warning("AnimatedShape2D: unsupported value for cursor direction.")
		return ERR_INVALID_PARAMETER
	
	# Collect to frame(s) to shift
	var frames_to_shift := Array()
	var cursor_index := from_frame_index
	var minimum_index := 0
	var maximum_index := self.frames_list.size() - 1
	var ok := false
	while true:
		if cursor_index < minimum_index:
			break
		if cursor_index > maximum_index:
			break
		var current_frame_editor: ShapeFrameEditor = self.frames_list[cursor_index]
		if current_frame_editor.get_shape_frame() == null:
			ok = true
			break
		frames_to_shift.append(current_frame_editor)
		cursor_index += cursor_direction
	
	if not ok:
		print("AnimatedShape2D: cancelling shift because there is no room.")
		return ERR_ALREADY_EXISTS
	
	# Now we can do the actual shifting
	for i in frames_to_shift.size():
		var j := cursor_index - i * cursor_direction
		self.frames_list[j].set_shape_frame(self.frames_list[j-cursor_direction].get_shape_frame())
	self.frames_list[cursor_index - frames_to_shift.size() * cursor_direction].set_shape_frame(null)
	
	return OK


func on_frame_selected(animation_name: String, frame_index: int):
	frame_selected.emit(animation_name, frame_index)
	# Below could be a subscriber to the above signal?
	var shape_frame := animated_shape.shape_frames.get_shape_frame(
		animation_name, frame_index,
	)
	if shape_frame != null:
		%ShiftLeftButton.disabled = false
		%ShiftRightButton.disabled = false


func on_frame_deselected(animation_name: String, frame_index: int):
	frame_deselected.emit(animation_name, frame_index)
	# Below could be a subscriber to the above signal?
	%ShiftLeftButton.disabled = true
	%ShiftRightButton.disabled = true


func on_frame_changed(animation_name: String, frame_index: int):
	frame_changed.emit(animation_name, frame_index)


## Updates the bottom panel as the user fills the required properties.
## This listener is only connected when something is missing.
func on_change_do_reload(_property: String):
	var inspector := EditorInterface.get_inspector()
	if not (inspector.get_edited_object() is AnimatedShape2D):
		return
	if inspector.property_edited.is_connected(on_change_do_reload):
		inspector.property_edited.disconnect(on_change_do_reload)
	rebuild_gui(self.animated_shape, true)


func _on_animation_names_item_list_item_selected(index: int):
	rebuild_view_of_animation_by_index(index)


func _on_zoom_less_button_pressed():
	var new_zoom_level := self.zoom_level - 1.0
	# Note: current zoom logic in TextureRect won't allow going below 1
	#if self.zoom_level <= 1.0:
		#new_zoom_level = self.zoom_level * 0.5
	#new_zoom_level = max(0.125, new_zoom_level)
	new_zoom_level = max(1.0, new_zoom_level)
	set_zoom_level(new_zoom_level)


func _on_zoom_reset_button_pressed():
	set_zoom_level(1.0)


func _on_zoom_more_button_pressed():
	var new_zoom_level := self.zoom_level + 1.0
	# Note: current zoom logic in TextureRect won't allow going below 1
	#if self.zoom_level <= 1.0:
		#new_zoom_level = self.zoom_level * 2.0
	#new_zoom_level = max(0.125, new_zoom_level)
	new_zoom_level = max(1.0, new_zoom_level)
	new_zoom_level = min(10.0, new_zoom_level)
	set_zoom_level(new_zoom_level)


func _on_background_color_picker_color_changed(color: Color):
	self.background_color = color
	rebuild_view_of_selected_animation()


func _on_shift_left_button_pressed():
	shift_frames_from_selected(-1)


func _on_shift_right_button_pressed():
	shift_frames_from_selected(1)

