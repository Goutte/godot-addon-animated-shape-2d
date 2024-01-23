Animated Shape 2D Addon for Godot
---------------------------------

[![MIT](https://img.shields.io/github/license/Goutte/godot-addon-animated-shape-2d.svg?style=for-the-badge)](https://github.com/Goutte/godot-addon-animated-shape-2d)
[![Release](https://img.shields.io/github/release/Goutte/godot-addon-animated-shape-2d.svg?style=for-the-badge)](https://github.com/Goutte/godot-addon-animated-shape-2d/releases)
[![FeedStarvingDev](https://img.shields.io/liberapay/patrons/Goutte.svg?style=for-the-badge&logo=liberapay)](https://liberapay.com/Goutte/)


A [Godot](https://godotengine.org/) `^4.2` addon that adds an `AnimatedShape2D` node that can customize a `CollisionShape2D` for each frame of each animation of an `AnimatedSprite2D`.

It is useful to make custom hitboxes, hurtboxes, and hardboxes for each pose of your character,
if you animated it using `AnimatedSprite2D`.

It comes with an Editor GUI to preview your shapes, in the fashion of the `SpriteFrames` bottom panel.

You can also use it to "tag" specific animation frames with custom metadata.


Features
--------

- customize a shape for each frame of your animations
- store metadata for each frame of your animations
- configurable fallbacks
- editor GUI, updated in real time
- copy & pasting, with either shallow of deep copies
- supports undo & redo where it matters
- dogfed
- extensible


Install
-------

The installation is as usual, through the `Assets Library` within Godot, look for [_AnimatedShape2D_](https://godotengine.org/asset-library/asset/2484).
You can also simply copy the files of this project into yours, it should work.

Then, enable the plugin in `Scene > Project Settings > Plugins`.


Usage
-----

1. Add a `AnimatedShape2D` anywhere in your scene and inspect it.
2. Target a `AnimatedSprite2D` to read frames from.
3. Target a `CollisionShape2D` to write to.
4. Make a new empty `ShapeFrames2D` to store the customization data into.
5. Add shape customizations to specific frames using the bottom panel.
6. Star this repository if you are happy ; share the love!

> You can only target one `CollisionShape2D` per `AnimatedShape2D`.
> Make one `AnimatedShape2D` per type of box you want to customize. _(hitbox, hurtbox, etc.)_


How it Works
------------

`AnimatedShape2D` stores enough data in a `ShapeFrames2D` resource to fully configure a `CollisionShape2D` for each frame of each animation of an `AnimatedSprite2D`.

It listens to the `AnimatedSprite2D` frame|animation changes, and updates its target `CollisionShape2D` accordingly.

_That's it._



-----

> 🦊 _Feedback and contributions are welcome!_
> https://github.com/Goutte/godot-addon-animated-shape-2d

