@tool
extends Resource
class_name ShapeFrame2D
#class_name Shape2DFrame

## Data object for a single shape frame.
## Basically a configurator for a CollisionShape2D.
## Each frame of each animation of an AnimatedSprite2D will be matched to one
## of these, in a Dictionary in ShapeFrames2D.
## You can also use the metadata of this Resource to store custom records per frame.


## Position of the collision shape in its parent.
@export var position := Vector2.ZERO:
	set(value):
		if value != position:
			position = value
			emit_changed()

## Disable the collision shape when [code]true[/code].
@export var disabled := false:
	set(value):
		if value != disabled:
			disabled = value
			emit_changed()

## Shape of the collision shape.
@export var shape: Shape2D = null: get = get_shape, set = set_shape

func get_shape() -> Shape2D:
	return shape


func set_shape(value: Shape2D):
	shape = value
	emit_changed()


## Override the debug color of the shape.
## Especially useful when adding metadata to the shape.
## Black with full opacity disables this override.
@export var debug_color := Color.BLACK


## Used to make dummy ; perhaps keep as a procedural API ?
static func make_rectangle(
	size: Vector2,
	position := Vector2.ZERO,
	disabled := false,
) -> ShapeFrame2D:
	var sf := ShapeFrame2D.new()
	sf.shape = RectangleShape2D.new()
	sf.shape.size = size
	sf.position = position
	sf.disabled = disabled
	return sf
