@tool
@icon("./animated_shape_2d.svg")
extends Node
class_name AnimatedShape2D

## Animates a CollisionShape2D for each frame of an AnimatedSprite2D.
## You can put this pretty much anywhere you want in your scene.


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

## Flip horizontally the collision shapes when the animated sprite is flipped,
## by inverting the scale of their parent Area2D.  Only works on collision
## shapes that are children of Area2D, to avoid weird behaviors with physics.
@export var handle_flip_h := true


enum SHAPE_UPDATE_MODE {
	## Update the existing shape resource properties in the CollisionShape2D,
	## but only if shape types are compatible.
	UPDATE,
	## Always replace the existing shape resource in the CollisionShape2D.
	## This may trigger additional [code]entered[/code] signals.
	REPLACE,
}

## How the Shape2D resource is updated between frames.
@export var update_shape_mode := SHAPE_UPDATE_MODE.UPDATE


var fallback_shape: Shape2D
var fallback_position: Vector2
var fallback_disabled: bool
var initial_scale: Vector2
var collision_shape_parent: Node2D


func _ready():
	if not Engine.is_editor_hint():
		setup()


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
	self.fallback_shape = self.collision_shape.shape
	if self.update_shape_mode == SHAPE_UPDATE_MODE.UPDATE:
		# We're going to update the original collision shape's shape, so we copy
		self.fallback_shape = self.collision_shape.shape.duplicate(true)
	self.fallback_position = self.collision_shape.position
	self.fallback_disabled = self.collision_shape.disabled
	self.collision_shape_parent = self.collision_shape.get_parent()
	if self.collision_shape_parent != null:
		self.initial_scale = self.collision_shape_parent.scale
	
	self.animated_sprite.animation_changed.connect(update_shape)
	self.animated_sprite.frame_changed.connect(update_shape)


func update_shape():
	var animation_name := self.animated_sprite.get_animation()
	var frame := self.animated_sprite.get_frame()
	var shape_frame := self.shape_frames.get_shape_frame(animation_name, frame)
	
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
	self.collision_shape.position = position
	self.collision_shape.disabled = disabled
	if self.handle_flip_h and is_collision_shape_parent_flippable():
		# Improvement idea: flip the CollisionBody2D itself and mirror its x pos
		if self.animated_sprite.flip_h:
			self.collision_shape_parent.scale.x = -self.initial_scale.x
		else:
			self.collision_shape_parent.scale.x = self.initial_scale.x


func update_collision_shape_shape(new_shape: Shape2D):
	if new_shape == self.collision_shape.shape:
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
		
		# If the update cannot be done, we want to duplicate the shape
		# because we might update it later on.
		self.collision_shape.shape = new_shape.duplicate(true)
		return
	
	self.collision_shape.shape = new_shape


## We don't want to flip PhysicsBodies because it creates odd behaviors.
## Override this method if that's what you want for some reason.
func is_collision_shape_parent_flippable() -> bool:
	return (
		self.collision_shape_parent != null
		and
		not (self.collision_shape_parent is PhysicsBody2D)
	)
