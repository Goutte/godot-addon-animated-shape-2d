@tool
extends Control
class_name ShapeFrameEditor

## Editor GUI for a single ShapeFrame2D.
## Shows a preview of the sprite and the shape, as well as action buttons.


const SHAPE_PREVIEW_SCRIPT := preload("./shape_preview.gd")


# Using @export instead of @onready allows accessing these subnodes at any time,
# including before ready and during the exit from the tree. (we want both)
# We do have to manyually set them (once) in the inspector, which is OK.
@export var sprite_button: Button  # %SpriteButton


## Animated shape resource we are editing.
## This holds enough data to configure a CollisionShape2D for a specific frame.
var animated_shape: AnimatedShape2D
## Animation name of the AnimatedSprite2D we're targeting.
var animation_name: String
## Frame of the above animation we are targeting.
var frame_index: int

## Zoom level of the preview.  Only integers are supported in there for now.
var zoom_level := 1.0
## Bakground color of the preview.
var background_color := Color.WEB_GRAY

var undo_redo: EditorUndoRedoManager


signal frame_selected
signal frame_deselected
signal changed


## Mandatory dependency injection, since it's best to leave _init() alone.
func configure(
	animated_shape: AnimatedShape2D,
	animation_name: String,
	frame_index: int,
):
	self.animated_shape = animated_shape
	self.animation_name = animation_name
	self.frame_index = frame_index


## Optional dependency injection
func set_undo_redo(undo_redo: EditorUndoRedoManager):
	self.undo_redo = undo_redo


func set_zoom_level(new_zoom_level: float):
	zoom_level = new_zoom_level


func set_background_color(new_background_color: Color):
	background_color = new_background_color


func _enter_tree():
	connect_to_shape_frame()


func _exit_tree():
	disconnect_from_shape_frame()
	remove_preview_of_shape_frame()
	if is_selected():
		frame_deselected.emit()


func build(button_group: ButtonGroup):
	update()
	# I had to set the ButtonGroup procedurally, a resource file won't work.
	sprite_button.button_group = button_group


func get_shape_frame() -> ShapeFrame2D:
	if self.animated_shape == null:
		return null
	if self.animated_shape.shape_frames == null:
		return null
	return self.animated_shape.shape_frames.get_shape_frame(
		self.animation_name, self.frame_index,
	)


func set_shape_frame(value: ShapeFrame2D):
	if self.animated_shape == null:
		return
	if self.animated_shape.shape_frames == null:
		return
	disconnect_from_shape_frame()
	self.animated_shape.shape_frames.set_shape_frame(
		self.animation_name, self.frame_index, value,
	)
	connect_to_shape_frame()
	update()
	emit_changed()


## Connect to the edited Resource, in order to update the GUI in real time.
func connect_to_shape_frame():
	var shape_frame := get_shape_frame()
	if shape_frame != null:
		shape_frame.changed.connect(on_shape_frame_changed)


## Disconnect from the edited Resource, to not leave connections hanging.
func disconnect_from_shape_frame():
	var shape_frame := get_shape_frame()
	if shape_frame != null:
		if shape_frame.changed.is_connected(on_shape_frame_changed):
			shape_frame.changed.disconnect(on_shape_frame_changed)


func is_selected() -> bool:
	return sprite_button.button_pressed


func select():
	sprite_button.button_pressed = true


func show_link_marker():
	%LinkMarker.show()


func hide_link_marker():
	%LinkMarker.hide()


## The crux of the matter ; update the scene according to the data.
func update():
	if self.animated_shape == null:
		return
	if self.animated_shape.animated_sprite == null:
		return
	if self.animated_shape.animated_sprite.sprite_frames == null:
		return
	
	# I. The actual sprite from the SpriteFrames, for this frame.
	%SpriteFrameTexture.texture = self.animated_shape.animated_sprite.sprite_frames.get_frame_texture(self.animation_name, self.frame_index)
	%SpriteFrameTexture.custom_minimum_size = self.zoom_level * %SpriteFrameTexture.texture.get_size()
	%SpriteFrameTexture.texture_filter = self.animated_shape.animated_sprite.texture_filter
	if %SpriteFrameTexture.texture_filter == TEXTURE_FILTER_PARENT_NODE:
		%SpriteFrameTexture.texture_filter = TEXTURE_FILTER_NEAREST
	%SpriteFrameTexture.texture_repeat = self.animated_shape.animated_sprite.texture_repeat
	if %SpriteFrameTexture.texture_repeat == TEXTURE_REPEAT_PARENT_NODE:
		%SpriteFrameTexture.texture_repeat = TEXTURE_REPEAT_DISABLED
	
	# II. Origin (0, 0) of the parent of the collision shape,
	# relative to the sprite, to help positioning our collision shape
	# at the right spot relative to the sprite in this preview.
	var collision_shape_parent_transform := Transform2D()
	if self.animated_shape.collision_shape.get_parent() is Node2D:
		collision_shape_parent_transform = self.animated_shape.collision_shape.get_parent().global_transform
	%Origin.transform = (
		self.animated_shape.animated_sprite.global_transform.affine_inverse()
		*
		collision_shape_parent_transform
	)
	if self.animated_shape.animated_sprite.centered:
		%Origin.position += (
			self.animated_shape.animated_sprite.sprite_frames.get_frame_texture(
				self.animation_name, self.frame_index,
			).get_size()
			*
			0.5
		)
	%Origin.position -= (
		self.animated_shape.animated_sprite.offset
	)
	
	# III. Display the preview of the collision shape.
	if self.animated_shape.shape_frames == null:
		return
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		%ShapeHolder.shape = null
	else:
		%ShapeHolder.shape = shape_frame.get_shape()
		%ShapeHolder.disabled = shape_frame.disabled
		%ShapeHolder.position = shape_frame.position
		%ShapeHolder.rotation = shape_frame.rotation
		%ShapeHolder.debug_color = self.animated_shape.collision_shape.debug_color
		if shape_frame.debug_color != Color.BLACK:
			%ShapeHolder.debug_color = shape_frame.debug_color
			
	
	# IV. Adjust the preview to the zoom level
	%ZoomAdjuster.scale = Vector2.ONE * self.zoom_level
	
	# V. Background clear color.
	%BackgroundColor.color = self.background_color
	
	# VI. Tooltip on the main sprite button
	sprite_button.tooltip_text = "%s/%d" % [self.animation_name, self.frame_index]
	if shape_frame != null:
		sprite_button.tooltip_text += " %s" % [shape_frame]
		sprite_button.tooltip_text += "\nClick to edit."
	
	# X. Action button: Create
	if shape_frame == null:
		%CreateButton.visible = true
		%CreateButton.disabled = false
	else:
		%CreateButton.visible = false
		%CreateButton.disabled = true
	
	# XI. Action button: Edit
	#if shape_frame == null:
		#%EditButton.visible = false
		#%EditButton.disabled = true
	#else:
		#%EditButton.visible = true
		#%EditButton.disabled = false
	
	# XII. Action button: Copy
	if shape_frame == null:
		%CopyButton.visible = false
		%CopyButton.disabled = true
	else:
		%CopyButton.visible = true
		%CopyButton.disabled = false
	
	# XIII. Action button: Delete
	if shape_frame == null:
		%DeleteButton.visible = false
		%DeleteButton.disabled = true
	else:
		%DeleteButton.visible = true
		%DeleteButton.disabled = false
	
	# L. 2D View Preview / Mouse GUI Editor
	if is_preview_showing():
		preview_shape_frame()


func inspect_shape_frame():
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		if self.animated_shape:
			EditorInterface.edit_node(self.animated_shape)
		return
	EditorInterface.edit_resource(shape_frame)


## The UndoRedo does not like when we use different objects, so we wrap this method here.
#func set_shape_frame(animation_name: StringName, frame_index: int):
	#self.animated_shape.shape_frames.set_(animation_name, frame_index)


## The UndoRedo does not like when we use different objects, so we wrap this method here.
func remove_shape_frame():
	self.animated_shape.shape_frames.remove_shape_frame(self.animation_name, self.frame_index)


#  _____                _
# |  __ \              (_)
# | |__) | __ _____   ___  _____      __
# |  ___/ '__/ _ \ \ / / |/ _ \ \ /\ / /
# | |   | | |  __/\ V /| |  __/\ V  V /
# |_|   |_|  \___| \_/ |_|\___| \_/\_/   Gizmo
#
# The big one shown in the 2D Editor when we select this shape frame.
# This is actually more than a preview since we can *edit* the shape with it.
# Perhaps we should call this Gizmo, to distinguish it from the bottom preview.


var sprite_preview: AnimatedSprite2D
var preview_background: ColorRect
var preview_shape: CollisionShape2D


func is_preview_showing() -> bool:
	return is_instance_valid(self.sprite_preview)


func remove_preview_of_shape_frame():
	if is_instance_valid(preview_shape):
		preview_shape.queue_free()
		preview_shape = null
	if is_instance_valid(preview_background):
		preview_background.queue_free()
		preview_background = null
	if is_instance_valid(sprite_preview):
		sprite_preview.queue_free()
		sprite_preview = null


func preview_shape_frame():
	if not is_instance_valid(sprite_preview):
		sprite_preview = animated_shape.animated_sprite.duplicate()
		sprite_preview.name = &"PreviewAnimatedSprite2D"
		sprite_preview.owner = null
	sprite_preview.animation = self.animation_name
	sprite_preview.frame = self.frame_index
	
	if not is_instance_valid(preview_background):
		preview_background = ColorRect.new()
		preview_background.name = &"PreviewBackgroundColorRect"
		preview_background.owner = null
		preview_background.show_behind_parent = true
		preview_background.set_anchors_preset(PRESET_FULL_RECT)
		if sprite_preview.centered:
			var s := sprite_preview.sprite_frames.get_frame_texture(sprite_preview.animation, sprite_preview.frame).get_size()
			preview_background.offset_left -= s.x * 0.5
			preview_background.offset_right -= s.x * 0.5
			preview_background.offset_top -= s.y * 0.5
			preview_background.offset_bottom -= s.y * 0.5
		# TODO: handle sprite offset too, probably
	preview_background.color = self.background_color
	
	if preview_background.get_parent() != sprite_preview:
		if preview_background.get_parent() != null:
			preview_background.get_parent().remove_child(preview_background)
		sprite_preview.add_child(preview_background)
	
	var shape_frame := get_shape_frame()
	if shape_frame != null:
		if not is_instance_valid(preview_shape):
			preview_shape = CollisionShape2D.new()
			preview_shape.name = &"PreviewCollisionShape2D"
			preview_shape.set_script(SHAPE_PREVIEW_SCRIPT)
			preview_shape.rectangle_changed.connect(on_preview_shape_rectangle_changed)
			preview_shape.item_rect_changed.connect(on_preview_shape_rect_changed)
			self.animated_shape.collision_shape.add_sibling(preview_shape)
		preview_shape.shape = shape_frame.shape
		preview_shape.disabled = shape_frame.disabled
		preview_shape.position = shape_frame.position
		preview_shape.rotation = shape_frame.rotation
		preview_shape.debug_color = self.animated_shape.collision_shape.debug_color
		if shape_frame.debug_color != Color.BLACK:
			preview_shape.debug_color = shape_frame.debug_color
	else:
		if is_instance_valid(preview_shape):
			preview_shape.queue_free()
			preview_shape = null
	
	if sprite_preview.get_parent() == null:
		self.animated_shape.animated_sprite.add_sibling(sprite_preview)
	
	var selection := EditorInterface.get_selection().get_selected_nodes()
	var already_selected := not selection.is_empty()
	if already_selected:
		already_selected = (selection[0] == preview_shape)
	if is_instance_valid(preview_shape) and not already_selected:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(preview_shape)
		
		# We need to use the mouse move mode because the selection mode does
		# not like non-owned nodes, even if they are _already selected_.
		# The selection mode can resize, but not reposition.
		var mouse_move_button := get_mouse_mode_button_by_icon(&"ToolMove")
		if mouse_move_button != null:
			mouse_move_button.pressed.emit()
		else:
			# Ouch, the hack above broke, as expected. Best ignore this "error".
			# Just make sure you use the Mouse Move Mode when editing the 2D
			# preview, and not the Select Mode (we can't reposition with it).
			push_warning("Mouse Move Button of 2D Workspace not found.  Make sure you use the Mouse Move Mode when editing the 2D Preview of your shape, because the Select Mode is not able to reposition it.")


## This is a hacky way of finding the tool button, by matching its icon.
## If you know how to do this properly, please share.
# Here's a dump of the children of the main screen:
# name: @CanvasItemEditor@10138 class: CanvasItemEditor
# name: @Node3DEditor@10898 class: Node3DEditor
# name: @WindowWrapper@11751 class: WindowWrapper
# name: @WindowWrapper@11833 class: WindowWrapper
# name: @EditorAssetLibrary@12226 class: EditorAssetLibrary
# I'm not sure why the node names look like this and at this point I'm too afraid to ask.
# Anyway, we can discriminate using the class name, that's good enough.
func get_mouse_mode_button_by_icon(icon_name: StringName) -> Button:
	var main_screen: Control = EditorInterface.get_editor_main_screen()
	var editor_class: String = "CanvasItemEditor"
	
	var editor_container: Node = null
	for child in main_screen.get_children():
		if child.get_class() == editor_class:
			editor_container = child
			break
	
	if not editor_container:
		push_warning("Failed to find the node with class '%s'." % [editor_class])
		return null
	
	var target_icon := EditorInterface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
	var buttons := editor_container.find_children("*", "Button", true, false)
	
	for button: Button in buttons:
		if button.icon == target_icon:
			return button
	
	return null


#func dump_main_screen_children():
	#var main_screen: Control = EditorInterface.get_editor_main_screen()
	#for child in main_screen.get_children():
		#prints("name:", child.name, "class:", child.get_class())


func on_preview_shape_rectangle_changed():
	update_from_preview_shape()


func on_preview_shape_rect_changed():
	# I wanna know when this starts working.
	print("Oh, now item_rect_changed signal works.  Used to not.")
	# Enable this when it works, and remove workaraound?
	#update_from_preview_shape()


func update_from_preview_shape():
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		return
	if not is_instance_valid(self.preview_shape):
		return
	shape_frame.position = self.preview_shape.position
	shape_frame.rotation = self.preview_shape.rotation


#  _      _     _
# | |    (_)   | |
# | |     _ ___| |_ ___ _ __   ___ _ __ ___
# | |    | / __| __/ _ \ '_ \ / _ \ '__/ __|
# | |____| \__ \ ||  __/ | | |  __/ |  \__ \
# |______|_|___/\__\___|_| |_|\___|_|  |___/
#

## UndoRedo won't accept calling methods on signals, so we'll call this instead.
func emit_changed():
	self.changed.emit()

func on_shape_frame_changed():
	update()
	emit_changed()


func _on_sprite_button_toggled(toggled_on: bool):
	if toggled_on:
		self.frame_selected.emit()
		preview_shape_frame()
		#inspect_shape_frame()  # nope, the preview has priority somehow
		#inspect_shape_frame.call_deferred()  # nope too
		# So, we use this horrendous await that will create bugs:
		get_tree().create_timer(0.064).timeout.connect(
			func():
				inspect_shape_frame()
		)
	else:
		self.frame_deselected.emit()
		remove_preview_of_shape_frame()


func _on_create_button_pressed():
	var shape_frame := get_shape_frame()
	if shape_frame != null:
		return
	
	# We could also use the UndoRedo here, but…  Hassle > Gain
	
	shape_frame = ShapeFrame2D.new()
	shape_frame.disabled = self.animated_shape.collision_shape.disabled
	shape_frame.position = self.animated_shape.collision_shape.position
	shape_frame.rotation = self.animated_shape.collision_shape.rotation
	if self.animated_shape.collision_shape.shape:
		shape_frame.shape = self.animated_shape.collision_shape.shape.duplicate(true)
	else:
		shape_frame.shape = RectangleShape2D.new()
	self.animated_shape.shape_frames.set_shape_frame(
		self.animation_name, self.frame_index, shape_frame,
	)
	
	update()
	connect_to_shape_frame()
	inspect_shape_frame()
	emit_changed()


func _on_edit_button_pressed():
	inspect_shape_frame()


func _on_copy_button_pressed():
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		return
	DisplayServer.clipboard_set(var_to_str(shape_frame.get_instance_id()))


func _on_paste_button_pressed():
	var previous_shape_frame := get_shape_frame()
	var copied_instance_id: int = str_to_var(DisplayServer.clipboard_get())
	if copied_instance_id == null:
		return
	var pasted_shape_frame: ShapeFrame2D = instance_from_id(copied_instance_id)
	if pasted_shape_frame == null:
		return
	if not (pasted_shape_frame is ShapeFrame2D):
		return
	
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		pasted_shape_frame = pasted_shape_frame.duplicate(true)
	
	if self.undo_redo != null:
		self.undo_redo.create_action(
			tr("Paste Shape Frame"), UndoRedo.MERGE_DISABLE, self,
		)
		self.undo_redo.add_do_method(
			self, &"disconnect_from_shape_frame",
		)
		self.undo_redo.add_do_method(
			self, &"set_shape_frame",
			pasted_shape_frame,
		)
		#self.undo_redo.add_do_method(
			#self, &"connect_to_shape_frame",
		#)
		#self.undo_redo.add_do_method(
			#self, &"update",
		#)
		#self.undo_redo.add_do_method(
			#self, &"inspect_shape_frame",
		#)
		#self.undo_redo.add_do_method(
			#self, &"emit_changed",
		#)
		self.undo_redo.add_undo_method(
			self, &"disconnect_from_shape_frame",
		)
		self.undo_redo.add_undo_method(
			self, &"set_shape_frame",
			previous_shape_frame,
		)
		#self.undo_redo.add_undo_method(
			#self, &"connect_to_shape_frame",
		#)
		#self.undo_redo.add_undo_method(
			#self, &"update",
		#)
		#self.undo_redo.add_undo_method(
			#self, &"inspect_shape_frame",
		#)
		#self.undo_redo.add_undo_method(
			#self, &"emit_changed",
		#)
		self.undo_redo.commit_action()
	else:
		# Same as above, without the UndoRedo shenanigans.
		disconnect_from_shape_frame()
		self.animated_shape.shape_frames.set_shape_frame(
			self.animation_name, self.frame_index, pasted_shape_frame,
		)
		connect_to_shape_frame()
		update()
		emit_changed()


func _on_delete_button_pressed():
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		return
	
	if self.undo_redo != null:
		self.undo_redo.create_action(
			tr("Delete Shape Frame"), UndoRedo.MERGE_DISABLE, self,
		)
		self.undo_redo.add_do_method(
			self, &"disconnect_from_shape_frame",
		)
		self.undo_redo.add_do_method(
			self, &"remove_shape_frame",
		)
		self.undo_redo.add_do_method(
			self, &"update",
		)
		self.undo_redo.add_do_method(
			self, &"inspect_shape_frame",
		)
		self.undo_redo.add_do_method(
			self, &"emit_changed",
		)
		self.undo_redo.add_undo_method(
			self, &"set_shape_frame",
			shape_frame,
		)
		#self.undo_redo.add_undo_method(
			#self, &"connect_to_shape_frame",
		#)
		self.undo_redo.add_undo_method(
			self, &"update",
		)
		self.undo_redo.add_undo_method(
			self, &"inspect_shape_frame",
		)
		self.undo_redo.add_undo_method(
			self, &"emit_changed",
		)
		self.undo_redo.commit_action()
	else:
		# Same as above, but without the UndoRedo shenanigans
		disconnect_from_shape_frame()
		remove_shape_frame()
		update()
		emit_changed()
