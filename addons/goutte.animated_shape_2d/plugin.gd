@tool
extends EditorPlugin

#
# This plugin adds the following to the Editor:
# - An AnimatedShape2D Node you can add to your scenes in order to configure
#   a CollisionShape2D with dynamic values per frame of an AnimatedSprite2D.
#   This is very handy for making dynamic Hurtboxes, Solidboxes, or Hitboxes.
# - A GUI for editing a ShapeFrame2D, similar to the SpriteFrames GUI.
#

const BOTTOM_PANEL_CONTROL_SCENE := preload("./editor/shape_frames_bottom_panel_control.tscn")

var bottom_panel_button: Button
var bottom_panel_control: Control


func _enter_tree():
	# I. Register the "Animated Shape" bottom panel.
	self.bottom_panel_control = BOTTOM_PANEL_CONTROL_SCENE.instantiate()
	self.bottom_panel_control.configure(self)
	self.bottom_panel_button = add_control_to_bottom_panel(
		self.bottom_panel_control,
		tr("Animated Shape"),
	)
	
	# II. Show/Hide it depending on what's inspected in the Inspector.
	#     This could also work using what's selected in the Scene Tree Editor?
	on_inspector_edited_object_changed()
	get_editor_interface().get_inspector().edited_object_changed.connect(
		on_inspector_edited_object_changed,
	)


func _exit_tree():
	remove_control_from_bottom_panel(self.bottom_panel_control)
	
	if get_editor_interface().get_inspector().edited_object_changed.is_connected(
		on_inspector_edited_object_changed,
	):
		get_editor_interface().get_inspector().edited_object_changed.disconnect(
			on_inspector_edited_object_changed,
		)


func update_bottom_panel(animated_shape: AnimatedShape2D):
	if animated_shape == null:
		self.bottom_panel_button.button_pressed = false
		self.bottom_panel_button.visible = false
		self.bottom_panel_control.clear()
		return
	
	self.bottom_panel_button.visible = true
	self.bottom_panel_button.button_pressed = true
	self.bottom_panel_control.rebuild_gui(animated_shape)


func on_inspector_edited_object_changed():
	var edited_object := get_editor_interface().get_inspector().get_edited_object()
	if edited_object is ShapeFrame2D:
		return
	if edited_object is CollisionShape2D and (edited_object as CollisionShape2D).owner == null:
		return  # we're editing the previews' shape
	if edited_object is Shape2D:
		return  # same
	if edited_object == null:
		return  # same
	var animated_shape: AnimatedShape2D = null
	if edited_object is AnimatedShape2D:
		animated_shape = edited_object as AnimatedShape2D
	update_bottom_panel(animated_shape)

