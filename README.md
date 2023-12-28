Unicode Normalizer Addon for Godot
----------------------------------

[![MIT](https://img.shields.io/github/license/Goutte/godot-addon-unicode-normalizer.svg)](https://github.com/Goutte/godot-addon-unicode-normalizer)
[![Release](https://img.shields.io/github/release/Goutte/godot-addon-unicode-normalizer.svg)](https://github.com/Goutte/godot-addon-unicode-normalizer/releases)


A [Godot](https://godotengine.org/) `4.x` addon that adds a `UnicodeNormalizer` singleton.

The `UnicodeNormalizer` helps removing diacritics and substituting tough characters.
It is handy when making your own fonts, or font engines.

> _"Dès Noël, où un zéphyr haï me vêt d'œufs..." → "Des Noel, ou un zephyr hai me vet d'oeufs..."_


Features
--------

- fast (benchmarked, uses binary search)
- light (`~16Kio` database)
- derived from unicode's database of decompositions and substitutions
- extensible


Install
-------

The installation is as usual, through the Assets Library.
You can also simply copy the files of this project into yours, it should work.

Then, enable the plugin in `Scene > Project Settings > Plugins`.


Usage
-----

Please see the [addons' README](./addons/goutte.unicode/README.md).


-----

> 🦊 _Feedback and contributions are welcome!_


