@tool
extends Node
## Animates a Shape2D for each frame of an AnimatedSprite.
## You can put this pretty much anywhere you want in your scene.
class_name AnimatedShape2D

#                 _                 _           _  _____ _
#     /\         (_)               | |         | |/ ____| |
#    /  \   _ __  _ _ __ ___   __ _| |_ ___  __| | (___ | |__   __ _ _ __   ___
#   / /\ \ | '_ \| | '_ ` _ \ / _` | __/ _ \/ _` |\___ \| '_ \ / _` | '_ \ / _ \
#  / ____ \| | | | | | | | | | (_| | ||  __/ (_| |____) | | | | (_| | |_) |  __/
# /_/    \_\_| |_|_|_| |_| |_|\__,_|\__\___|\__,_|_____/|_| |_|\__,_| .__/ \___|
#                                                                   | |
# v0.1.0-20231227                                                   |_|


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


var fallback_shape: Shape2D
var fallback_position: Vector2
var fallback_disabled: bool


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
	self.fallback_shape = self.collision_shape.shape
	self.fallback_position = self.collision_shape.position
	self.fallback_disabled = self.collision_shape.disabled
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
		return
	if shape == null and self.use_initial_as_fallback:
		shape = self.fallback_shape
		position = self.fallback_position
		disabled = self.fallback_disabled
	self.collision_shape.shape = shape
	self.collision_shape.position = position
	self.collision_shape.disabled = disabled
