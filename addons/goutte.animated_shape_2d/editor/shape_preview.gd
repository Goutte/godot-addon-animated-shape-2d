@tool
extends CollisionShape2D

## For the temporary CollisionShape2D gizmo created in the Editor's 2D view.
## We use it to listen to position, rotation and size changes, to update our UI.


signal rectangle_changed


func _ready():
	set_notify_local_transform(true)


func _notification(what: int):
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		rectangle_changed.emit()
