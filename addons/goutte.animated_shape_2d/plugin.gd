@tool
extends EditorPlugin

#
# This plugin/addon adds the following to the Editor:
# - An AnimatedShape2D Node you can add to your scenes in order to configure
#   a CollisionShape2D with dynamic values per frame of an AnimatedSprite2D.
#   This is very handy for making dynamic Hurtboxes, Solidboxes, or Hitboxes.
# - A GUI for editing a ShapeFrame2D, similar to the SpriteFrames GUI.
#

const SHAPE_FRAMES_EDITOR_SCENE := preload("./editor/shape_frames_bottom_panel_control.tscn")

var shape_frames_editor: Control
var shape_frames_dock: EditorDock


func _enter_tree():
	# I. Register our shape frames editor in one of the bottom dock slots.
	self.shape_frames_editor = SHAPE_FRAMES_EDITOR_SCENE.instantiate()
	self.shape_frames_editor.configure(self)
	
	self.shape_frames_dock = EditorDock.new()
	self.shape_frames_dock.title = tr("ShapeFrames")
	self.shape_frames_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	self.shape_frames_dock.add_child(self.shape_frames_editor)
	add_dock(self.shape_frames_dock)
	
	# II. Show/Hide it depending on what's inspected in the Inspector.
	#     This could also work using what's selected in the Scene Tree Editor?
	on_inspector_edited_object_changed()
	get_editor_interface().get_inspector().edited_object_changed.connect(
		on_inspector_edited_object_changed,
	)


func _exit_tree():
	# I. Deregister our dock and free its nodes
	remove_dock(self.shape_frames_dock)
	self.shape_frames_editor.queue_free()  # zealous, but it's OK
	self.shape_frames_editor = null
	self.shape_frames_dock.queue_free()
	self.shape_frames_dock = null
	
	# II. And don't forget to (un)subscribe — and hit the bell icon
	if get_editor_interface().get_inspector().edited_object_changed.is_connected(
		on_inspector_edited_object_changed,
	):
		get_editor_interface().get_inspector().edited_object_changed.disconnect(
			on_inspector_edited_object_changed,
		)


func update_bottom_panel(animated_shape: AnimatedShape2D):
	if animated_shape == null:
		self.shape_frames_dock.close()
		return
	
	self.shape_frames_dock.make_visible()
	self.shape_frames_editor.rebuild_gui(animated_shape)


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
