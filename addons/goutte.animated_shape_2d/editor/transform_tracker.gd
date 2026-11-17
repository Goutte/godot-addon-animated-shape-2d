@tool
extends Node2D
class_name TransformTracker2D


signal transform_changed


func _ready():
	set_notify_transform(true)


func _notification(what: int):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()
