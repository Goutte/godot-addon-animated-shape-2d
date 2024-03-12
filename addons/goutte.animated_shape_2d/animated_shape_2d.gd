@tool
@icon("./animated_shape_2d.svg")
extends Node
class_name AnimatedShape2D
#class_name AnimatedCollisionShape2D
#class_name AnimatedSprite2DCollisions
#class_name CollisionShape2DFramer

## Customizes a CollisionShape2D for each frame of an AnimatedSprite2D.

# Usage:
# 1. Add this node anywhere in your scene
# 2. Target an input AnimatedSprite2D
# 3. Target an output CollisionShape2D
# 4. Load or Create a ShapeFrames2D (it's our database)
# 
# Notes:
# - You can put this pretty much anywhere you want in your scene.
# - This _could_ be a script on a CollisionShape2D, but this way your are free
#   to have your own script on your collision shape if you want to.
# - This is quite experimental ; contributions are welcome.
#   https://github.com/Goutte/godot-addon-animated-shape-2d

## Animated sprite we're going to watch to figure out which shape we want.
## We're reading the animation name and frame from it.
@export var animated_sprite: AnimatedSprite2D

## Target collision shape whose shape we're going to write to.
## We're also going to configure this CollisionShape2D (position, disabled)
## for each frame of the AnimatedSprite2D above.
@export var collision_shape: CollisionShape2D

## Shape data for each animation and frame of the animated sprite.
## This holds enough data to configure the collision shape for each frame
## of the animated sprite: shape, position, disabled…
@export var shape_frames: ShapeFrames2D

## If [code]true[/code], use the initial shape in the target CollisionShape2D
## as fallback when the shape is not defined in the ShapeFrames2D.
## If [code]false[/code], do not use fallback and therefore disable the shape.
## This has lower priority than use_previous_as_fallback.
@export var use_initial_as_fallback := true

## If [code]true[/code], use the previous shape in the target CollisionShape2D
## as fallback when the shape is not defined in the ShapeFrames2D.
## If [code]false[/code], do not use fallback and therefore disable the shape.
## This has higher priority than use_initial_as_fallback.
## This is handy if for example all your frames use the same shape,
## and shapes only change per animation.
@export var use_previous_as_fallback := false

## If [code]true[/code], use call_deferred() to set CollisionShape2D properties.
@export var use_deferred_calls := true

## Flip horizontally the collision shapes when the animated sprite is flipped,
## by inverting the scale of their parent Area2D.  Only works on collision
## shapes that are children of Area2D, to avoid weird behaviors with physics.
@export var handle_flip_h := true

## Maximum amount of shape size and position change per physics frame.
## Only used in the [code]INTERPOLATE[/code] mode.
@export var interpolation_step := 3.0


enum SHAPE_UPDATE_MODE {
	## Update the existing shape resource properties in the CollisionShape2D,
	## but only if shape types are compatible.
	UPDATE,
	## Works like [code]UPDATE[/code], but interpolates values instead of setting them.
	## This helps when sudden, big changes in a collision shape make the physics
	## engine glitch and your character starts clipping through the environment.
	## Use with [code]interpolation_step[/code].
	INTERPOLATE,
	## Always replace the existing shape resource in the CollisionShape2D.
	## This may trigger additional [code]entered[/code] signals.
	REPLACE,
}

## How the Shape2D resource of the CollisionShape2D is updated between frames.
## Weird things will happen if you change this at runtime.
@export var update_shape_mode := SHAPE_UPDATE_MODE.UPDATE


var fallback_shape: Shape2D
var fallback_position: Vector2
var fallback_disabled: bool
var initial_scale: Vector2
var collision_shape_parent: Node2D

var is_tweening_collision_shape_position := false
var target_collision_shape_position := Vector2.ZERO
var is_tweening_collision_shape_shape := false
var target_collision_shape_shape: Shape2D


func _ready():
	if not Engine.is_editor_hint():
		setup()
		update_shape()
	else:
		set_physics_process(false)


func _physics_process(_delta: float):
	if self.is_tweening_collision_shape_position:
		tween_collision_shape_position()
	if self.is_tweening_collision_shape_shape:
		tween_collision_shape_shape()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if self.animated_sprite == null:
		warnings.append("This node requires a target AnimatedSprite2D to read frames from.")
	if self.collision_shape == null:
		warnings.append("This node requires a target CollisionShape2D to write customizations to.")
	if self.shape_frames == null:
		warnings.append("This node requires a ShapeFrames2D to store data.  Make a new one?")
	return warnings


func setup():
	if self.collision_shape == null:
		return
	if self.shape_frames == null:
		return
	
	# We might update the original collision shape's shape, so we duplicate
	if self.collision_shape.shape:
		self.fallback_shape = self.collision_shape.shape.duplicate(true)
	self.fallback_position = self.collision_shape.position
	self.fallback_disabled = self.collision_shape.disabled
	self.collision_shape_parent = self.collision_shape.get_parent()
	if self.collision_shape_parent != null:
		self.initial_scale = self.collision_shape_parent.scale
	
	self.animated_sprite.animation_changed.connect(update_shape)
	self.animated_sprite.frame_changed.connect(update_shape)
	
	set_physics_process(self.update_shape_mode == SHAPE_UPDATE_MODE.INTERPOLATE)


func get_current_shape_frame() -> ShapeFrame2D:
	var animation_name := self.animated_sprite.get_animation()
	var frame := self.animated_sprite.get_frame()
	return self.shape_frames.get_shape_frame(animation_name, frame)


func update_shape():
	if self.shape_frames == null:
		return
	var shape_frame := get_current_shape_frame()
	
	var shape: Shape2D = null
	if shape_frame != null:
		shape = shape_frame.get_shape()
	var position := Vector2.ZERO
	var disabled := false
	if shape_frame != null:
		position = shape_frame.position
		disabled = shape_frame.disabled
	if shape == null and self.use_previous_as_fallback:
		# Improvement idea: allow flipping in this case as well
		return
	if shape == null and self.use_initial_as_fallback:
		shape = self.fallback_shape
		position = self.fallback_position
		disabled = self.fallback_disabled
	
	update_collision_shape_shape(shape)
	update_collision_shape_position(position)
	update_collision_shape_disabled(disabled)
	
	if self.handle_flip_h and is_collision_shape_parent_flippable():
		# Improvement idea: flip the CollisionBody2D itself and mirror its x pos
		if self.animated_sprite.flip_h:
			self.collision_shape_parent.scale.x = -self.initial_scale.x
		else:
			self.collision_shape_parent.scale.x = self.initial_scale.x


func update_collision_shape_disabled(disabled: bool):
	if self.use_deferred_calls:
		self.collision_shape.set_deferred(&"disabled", disabled)
	else:
		self.collision_shape.disabled = disabled


func update_collision_shape_position(new_position: Vector2):
	if new_position == self.collision_shape.position:
		return
	
	if self.update_shape_mode == SHAPE_UPDATE_MODE.INTERPOLATE:
		self.is_tweening_collision_shape_position = true
		self.target_collision_shape_position = new_position
	else:
		self.collision_shape.position = new_position


func update_collision_shape_shape(new_shape: Shape2D):
	if new_shape == self.collision_shape.shape:
		return
	
	if (
		self.update_shape_mode == SHAPE_UPDATE_MODE.INTERPOLATE
		and
		self.collision_shape.shape != null
		and
		new_shape != null
	):
		if (
			(self.collision_shape.shape.get_class() == new_shape.get_class())
		):
			self.is_tweening_collision_shape_shape = true
			self.target_collision_shape_shape = new_shape
			return
	
	if (
		self.update_shape_mode == SHAPE_UPDATE_MODE.UPDATE
		and
		self.collision_shape.shape != null
		and
		new_shape != null
	):
		if (
			(self.collision_shape.shape is RectangleShape2D)
			and
			(new_shape is RectangleShape2D)
		):
			self.collision_shape.shape.size = new_shape.size
			return
		
		if (
			(self.collision_shape.shape is CircleShape2D)
			and
			(new_shape is CircleShape2D)
		):
			self.collision_shape.shape.radius = new_shape.radius
			return
		
		if (
			(self.collision_shape.shape is CapsuleShape2D)
			and
			(new_shape is CapsuleShape2D)
		):
			self.collision_shape.shape.height = new_shape.height
			self.collision_shape.shape.radius = new_shape.radius
			return
		
		if (
			(self.collision_shape.shape is SegmentShape2D)
			and
			(new_shape is SegmentShape2D)
		):
			self.collision_shape.shape.a = new_shape.a
			self.collision_shape.shape.b = new_shape.b
			return
		
		if (
			(self.collision_shape.shape is WorldBoundaryShape2D)
			and
			(new_shape is WorldBoundaryShape2D)
		):
			self.collision_shape.shape.distance = new_shape.distance
			self.collision_shape.shape.normal = new_shape.normal
			return
		
		# If the update cannot be done, we want a duplicate of the shape
		# because we might update it later on.
		if use_deferred_calls:
			self.collision_shape.set_deferred(&"shape", new_shape.duplicate(true))
		else:
			self.collision_shape.shape = new_shape.duplicate(true)
		return
	
	# Or perhaps just simply REPLACE the shape.
	# This triggers (possibly unwanted) extra area_entered signals.
	if use_deferred_calls:
		self.collision_shape.set_deferred(&"shape", new_shape)
	else:
		self.collision_shape.shape = new_shape


# Make the shape properties go towards their target, but not by more than
# the configured interpolation step, to keep things smooth.
# This method is insanely verbose, but not very complicated.
# I did not want to use reflection for shorter code but worse perfs.
func tween_collision_shape_shape():
	if not self.is_tweening_collision_shape_shape:
		return
	
	if (
		self.collision_shape.shape == null
		or
		self.target_collision_shape_shape == null
	):
		return
	
	if (
		(self.collision_shape.shape is RectangleShape2D)
		and
		(self.target_collision_shape_shape is RectangleShape2D)
	):
		self.collision_shape.shape.size.x += clampf(
			self.target_collision_shape_shape.size.x
			-
			self.collision_shape.shape.size.x,
			-self.interpolation_step,
			self.interpolation_step,
		)
		self.collision_shape.shape.size.y += clampf(
			self.target_collision_shape_shape.size.y
			-
			self.collision_shape.shape.size.y,
			-self.interpolation_step,
			self.interpolation_step,
		)
		
		if self.collision_shape.shape.size == self.target_collision_shape_shape.size:
			self.is_tweening_collision_shape_shape = false
		
		return
	
	if (
		(self.collision_shape.shape is CircleShape2D)
		and
		(self.target_collision_shape_shape is CircleShape2D)
	):
		self.collision_shape.shape.radius += clampf(
			self.target_collision_shape_shape.radius
			-
			self.collision_shape.shape.radius,
			-self.interpolation_step,
			self.interpolation_step,
		)
		
		if self.collision_shape.shape.radius == target_collision_shape_shape.radius:
			self.is_tweening_collision_shape_shape = false
		
		return
	
	if (
		(self.collision_shape.shape is CapsuleShape2D)
		and
		(self.target_collision_shape_shape is CapsuleShape2D)
	):
		self.collision_shape.shape.height += clampf(
			self.target_collision_shape_shape.height
			-
			self.collision_shape.shape.height,
			-self.interpolation_step,
			self.interpolation_step,
		)
		self.collision_shape.shape.radius += clampf(
			self.target_collision_shape_shape.radius
			-
			self.collision_shape.shape.radius,
			-self.interpolation_step,
			self.interpolation_step,
		)
		
		if (
			self.collision_shape.shape.radius == target_collision_shape_shape.radius
			and
			self.collision_shape.shape.height == target_collision_shape_shape.height
		):
			self.is_tweening_collision_shape_shape = false
		
		return
	
	if (
		(self.collision_shape.shape is SegmentShape2D)
		and
		(self.target_collision_shape_shape is SegmentShape2D)
	):
		self.collision_shape.shape.a.x += clampf(
			self.target_collision_shape_shape.a.x
			-
			self.collision_shape.shape.a.x,
			-self.interpolation_step,
			self.interpolation_step,
		)
		self.collision_shape.shape.a.y += clampf(
			self.target_collision_shape_shape.a.y
			-
			self.collision_shape.shape.a.y,
			-self.interpolation_step,
			self.interpolation_step,
		)
		self.collision_shape.shape.b.x += clampf(
			self.target_collision_shape_shape.b.x
			-
			self.collision_shape.shape.b.x,
			-self.interpolation_step,
			self.interpolation_step,
		)
		self.collision_shape.shape.b.y += clampf(
			self.target_collision_shape_shape.b.y
			-
			self.collision_shape.shape.b.y,
			-self.interpolation_step,
			self.interpolation_step,
		)
		
		if (
			self.collision_shape.shape.a == target_collision_shape_shape.a
			and
			self.collision_shape.shape.b == target_collision_shape_shape.b
		):
			self.is_tweening_collision_shape_shape = false
		
		return
	
	# If shape types are incompatible or not supported, cancel the interpolation
	# and simply replace the shape, with a duplicate because we might update it.
	self.is_tweening_collision_shape_shape = false
	self.collision_shape.shape = target_collision_shape_shape.duplicate(true)


func tween_collision_shape_position():
	if not self.is_tweening_collision_shape_position:
		return
	
	self.collision_shape.position.x += clampf(
		self.target_collision_shape_position.x - self.collision_shape.position.x,
		-self.interpolation_step,
		self.interpolation_step,
	)
	self.collision_shape.position.y += clampf(
		self.target_collision_shape_position.y - self.collision_shape.position.y,
		-self.interpolation_step,
		self.interpolation_step,
	)
	
	if self.collision_shape.position == self.target_collision_shape_position:
		self.is_tweening_collision_shape_position = false


## We don't want to flip PhysicsBodies because it creates odd behaviors.
## Override this method if that's what you want for some reason.
func is_collision_shape_parent_flippable() -> bool:
	return (
		self.collision_shape_parent != null
		and
		not (self.collision_shape_parent is PhysicsBody2D)
	)
