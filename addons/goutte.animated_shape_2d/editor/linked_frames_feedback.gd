@tool
extends Node


@export var editor: ShapeFramesBottomPanelControl


func update_for(animation_name: StringName, frame_index: int):
	assert(editor.currently_selected_animation_name == animation_name)
	# 1. Grab the sprite frame resource of the selected frame
	var frame_editor := editor.get_frame_at(frame_index)
	var shape_frame := frame_editor.get_shape_frame()
	# 2. Iterate over all frames to find linked frames
	var linked_frames_editors: Array[ShapeFrameEditor]= []
	for some_frame_editor in editor.frames_list:
		if shape_frame == null:
			continue
		if some_frame_editor.get_shape_frame() != shape_frame:
			continue
		linked_frames_editors.append(some_frame_editor)
	# 3. Hide the link marker everywhere
	for some_frame_editor in editor.frames_list:
		some_frame_editor.hide_link_marker()
	# 4. Show the link marker where appropriate
	if linked_frames_editors.size() > 1:
		for linked_frame_editor in linked_frames_editors:
			linked_frame_editor.show_link_marker()


func _on_shape_frames_bottom_panel_control_frame_selected(animation_name: StringName, frame_index: int):
	update_for(animation_name, frame_index)


func _on_shape_frames_bottom_panel_control_frame_changed(animation_name, frame_index):
	var selected_frame_editor := editor.get_selected_frame()
	update_for(selected_frame_editor.animation_name, selected_frame_editor.frame_index)

