@tool
extends Control

const FRAME_SCENE := preload("./shape_frame_editor.tscn")

@onready var animation_names_item_list: ItemList = %AnimationNamesItemList
@onready var frames_container := %FramesContainer

## The thing we are previewing and editing.
var animated_shape: AnimatedShape2D

## Used to access Editor things like UndoRedo.
## Someday we will not need this anymore, hopefully.
var editor_plugin: EditorPlugin

var zoom_level := 1.0: set = set_zoom_level
var background_color := Color.WEB_GRAY


func configure(
	editor_plugin: EditorPlugin,
):
	self.editor_plugin = editor_plugin


func clear():
	self.animation_names_item_list.deselect_all()
	self.animation_names_item_list.clear()
	clear_shape_frames()
	self.animated_shape = null


func clear_shape_frames():
	for child in self.frames_container.get_children():
		child.queue_free()


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
	if inspector.property_edited.is_connected(on_change_reload):
		inspector.property_edited.disconnect(on_change_reload)
	if missing_requirements:
		inspector.property_edited.connect(on_change_reload)
		return
	
	var animation_name := &"default"
	if is_instance_valid(self.animated_shape.animated_sprite):
		animation_name = self.animated_shape.animated_sprite.animation
	rebuild_animation_names_item_list(self.animated_shape, animation_name)


func on_change_reload(_property: String):
	var inspector := EditorInterface.get_inspector()
	if not (inspector.get_edited_object() is AnimatedShape2D):
		return
	if inspector.property_edited.is_connected(on_change_reload):
		inspector.property_edited.disconnect(on_change_reload)
	rebuild_gui(self.animated_shape, true)


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
	
	var button_group := ButtonGroup.new()
	var frames_count := self.animated_shape.animated_sprite.sprite_frames.get_frame_count(animation_name)
	for frame_index in frames_count:
		var frame_scene := FRAME_SCENE.instantiate() as ShapeFrameEditor
		frame_scene.configure(self.animated_shape, animation_name, frame_index)
		frame_scene.set_undo_redo(self.editor_plugin.get_undo_redo())
		frame_scene.set_zoom_level(self.zoom_level)
		frame_scene.set_background_color(self.background_color)
		frame_scene.build(button_group)
		frames_container.add_child(frame_scene)


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

