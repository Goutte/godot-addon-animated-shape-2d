@tool
extends Resource
class_name ShapeFrames2D
#class_name Shape2DFrames

## Resource holding the configuration of a CollisionShape2D,
## for each frame of each animation of a SpriteFrames.
## This is basically a mapping of ShapeFrame2D for each (animation name, frame).


## This helps avoiding infinite loops in case you pass INF as frame index.
## If you hit that limit (what are you doing?!), it is safe to bump it up.
const MAXIMUM_FRAMES_AMOUNT := 666


## Actual data of this resource.
## This is a Dictionary of Arrays of ShapeFrame2D, indexed by animation name.
## In each Array of ShapeFrame2D, there ought to be one ShapeFrame2D per frame
## in the corresponding animation of the AnimatedSprite2D.
## It means that the shape of this should follow the shape of the SpriteFrames.
## [code]
## {
## 	'<animation name>': [ ShapeFrame2D, … ],
## 	…
## }
## [/code]
@export var data := Dictionary()


## Returns the shape frame data for the provided animation and frame.
## This should return null if no data was found.
func get_shape_frame(animation_name: StringName, frame: int) -> ShapeFrame2D:
	if self.data.has(animation_name):
		var animation_data: Array = self.data[animation_name] as Array
		if animation_data == null:
			return null
		if animation_data.size() > frame:
			return animation_data[frame] as ShapeFrame2D
	return null


## Sets a ShapeFrame2D for the provided animation and frame.
## When the AnimatedSprite2D shows this frame, the CollisionShape2D will be
## configured using the provided ShapeFrame2D.  See AnimatedShape2D.
func set_shape_frame(
	animation_name: StringName,
	frame: int,
	shape_frame: ShapeFrame2D,
):
	if not self.data.has(animation_name):
		self.data[animation_name] = Array()
	var animation_data: Array = self.data[animation_name] as Array
	frame = max(frame, 0)
	frame = min(frame, MAXIMUM_FRAMES_AMOUNT)
	if animation_data.size() <= frame:
		animation_data.resize(frame + 1)
	animation_data[frame] = shape_frame


## Removes the ShapeFrame2D datum for the provided key tuple.
## This will let the frame fall back to configured defaults.
func remove_shape_frame(animation_name: StringName, frame: int):
	if not self.data.has(animation_name):
		return
	var animation_data: Array = self.data[animation_name] as Array
	if animation_data.size() > frame:
		animation_data[frame] = null


# Example of a tentative procedural API to make this.
# Prefer using the Editor for now.
#static func make_dummy() -> ShapeFrames2D:
	#var dummy := ShapeFrames2D.new()
	#dummy.data = {
		#&'jump_ascent': [
			#ShapeFrame2D.make_rectangle(Vector2(16, 32), Vector2(0, -17)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 28), Vector2(0, -15)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 22), Vector2(0, -12)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
		#],
		#&'jump_descent': [
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 22), Vector2(0, -12)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 28), Vector2(0, -15)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 32), Vector2(0, -17)),
		#],
		#&'jump_flight': [
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
			#ShapeFrame2D.make_rectangle(Vector2(16, 16), Vector2(0, -9)),
		#],
	#}
	#return dummy
