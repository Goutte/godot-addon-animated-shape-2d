@tool
extends Control
## Editor GUI for a single ShapeFrame2D.
## Shows a preview of the sprite and the shape, as well as action buttons.
class_name ShapeFrameEditor

# Don't use @ready wince we're using nodes before _ready
#@onready var sprite_texture := %SpriteFrameTexture

## Animated shape resource we are editing.
## This holds enough data to configure a CollisionShape2D for a specific frame.
var animated_shape: AnimatedShape2D
## Animation name of the AnimatedSprite2D we're targeting.
var animation_name: String
## Frame of the above animation we are targeting.
var frame_index: int

## Zoom level of the preview.  Only integers are supported in there for now.
var zoom_level := 1.0

var undo_redo: EditorUndoRedoManager


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


func _enter_tree():
	connect_to_shape_frame()


func _exit_tree():
	disconnect_from_shape_frame()


func build():
	update()


func get_shape_frame() -> ShapeFrame2D:
	if self.animated_shape == null:
		return null
	if self.animated_shape.shape_frames == null:
		return null
	return self.animated_shape.shape_frames.get_shape_frame(
		self.animation_name, self.frame_index,
	)


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
	%Origin.transform = (
		self.animated_shape.animated_sprite.global_transform.affine_inverse()
		*
		self.animated_shape.collision_shape.get_parent().global_transform
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
		%ShapeHolder.position = shape_frame.position
		%ShapeHolder.disabled = shape_frame.disabled
		%ShapeHolder.debug_color = self.animated_shape.collision_shape.debug_color
	
	# IV. Adjust the preview to the zoom level
	%ZoomAdjuster.scale = Vector2.ONE * self.zoom_level
	
	# V. Tooltip on the main sprite button
	%SpriteButton.tooltip_text = "%s/%d" % [self.animation_name, self.frame_index]
	if shape_frame != null:
		%SpriteButton.tooltip_text += " %s" % [shape_frame]
		%SpriteButton.tooltip_text += "\nClick to edit in the Inspector."
	
	# X. Action button: Create
	if shape_frame == null:
		%CreateButton.visible = true
		%CreateButton.disabled = false
	else:
		%CreateButton.visible = false
		%CreateButton.disabled = true
	
	# XI. Action button: Copy
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


func set_zoom_level(new_zoom_level: float):
	zoom_level = new_zoom_level


func inspect_shape_frame():
	var shape_frame := get_shape_frame()
	if shape_frame == null:
		return
	EditorInterface.edit_resource(shape_frame)


func on_shape_frame_changed():
	update()


func _on_sprite_button_pressed():
	inspect_shape_frame()


func _on_create_button_pressed():
	var shape_frame := get_shape_frame()
	if shape_frame != null:
		return
	
	# We could also use the UndoRedo here, but…  Hassle > Gain
	
	shape_frame = ShapeFrame2D.new()
	shape_frame.disabled = self.animated_shape.collision_shape.disabled
	shape_frame.position = self.animated_shape.collision_shape.position
	shape_frame.shape = self.animated_shape.collision_shape.shape.duplicate(true)
	self.animated_shape.shape_frames.set_shape_frame(
		self.animation_name, self.frame_index, shape_frame,
	)
	
	update()
	connect_to_shape_frame()
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
			self.animated_shape.shape_frames, &"set_shape_frame",
			self.animation_name, self.frame_index, pasted_shape_frame,
		)
		self.undo_redo.add_do_method(
			self, &"connect_to_shape_frame",
		)
		self.undo_redo.add_do_method(
			self, &"update",
		)
		self.undo_redo.add_undo_method(
			self, &"disconnect_from_shape_frame",
		)
		self.undo_redo.add_undo_method(
			self.animated_shape.shape_frames, &"set_shape_frame",
			self.animation_name, self.frame_index, previous_shape_frame,
		)
		self.undo_redo.add_undo_method(
			self, &"connect_to_shape_frame",
		)
		self.undo_redo.add_undo_method(
			self, &"update",
		)
		self.undo_redo.commit_action()
	else:
		# Same as above, without the UndoRedo shenanigans.
		disconnect_from_shape_frame()
		self.animated_shape.shape_frames.set_shape_frame(
			self.animation_name, self.frame_index, pasted_shape_frame,
		)
		connect_to_shape_frame()
		update()


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
			self.animated_shape.shape_frames, &"remove_shape_frame",
			self.animation_name, self.frame_index,
		)
		self.undo_redo.add_do_method(
			self, &"update",
		)
		self.undo_redo.add_undo_method(
			self.animated_shape.shape_frames, &"set_shape_frame",
			self.animation_name, self.frame_index, shape_frame,
		)
		self.undo_redo.add_undo_method(
			self, &"connect_to_shape_frame",
		)
		self.undo_redo.add_undo_method(
			self, &"update",
		)
		self.undo_redo.commit_action()
	else:
		# Same as above, but without the UndoRedo shenanigans
		disconnect_from_shape_frame()
		self.animated_shape.shape_frames.remove_shape_frame(
			self.animation_name, self.frame_index,
		)
		update()
