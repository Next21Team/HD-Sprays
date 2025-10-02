# HD-Sprays

_**English** | [Русский](README.ru.md)_

AMX Mod X plugin for Counter-Strike.

Adds functionality for players to draw high resolution sprays using models and sprites installed on the server. Plugin features:
* API for flexible integration
* display the nickname of the player who drew the spray
* spray preview
* support for submodels and skins
* animation support (skeletal and frame animations)
* sprite support
* saving the spray selected by the player to the local nVault database by the steam_id

## Settings

### Cvars:
| Cvar name | Default value | Description |
| --- |---------------|-----------------------------|
| hd_spray_light | 0             | Enables the spray highlighting. |
| hd_spray_lifetime | 200.0      | Time to disappear the drawn spray in seconds. |
| hd_max_sprays | 32             | Maximum number of sprays drawn (maximum number of created entities on the map). If the value is exceeded, the oldest drawn spray is deleted. |
| hd_spray_client_decal | 1      | Allow players to draw regular sprays (decals). |
| hd_spray_movable_surface | 0   | Allow players to draw sprays on moving entities. |
| hd_spray_intersects | 1        | Restricts draw sprays on over the other sprays. |
| hd_spray_show_owner | 1        | Enable display of player's nickname when aiming at a spray. |
| hd_spray_round_cleanup | 0     | Enable removal of all drawn sprays at the start of a round. |
| hd_spray_print_delay | 0     | Print the time until a new spray can be drawn. (0 - don't print, 1 - print in the center, 2 - print in the chat) |

### Spray configuration:
The configuration file is *addons/amxmodx/configs/sprays.ini*. Example configuration:
```
; "name"         "model"              type  body  skin  framerate  width  height  scale  cost  access
"spray 1"        "spray_pack.mdl"     "n"   0     0     1.0        45.0   45.0    1.0    150   ""
"spray 2"        "spray_pack.mdl"     "n"   1     0     1.0        45.0   45.0    1.0    300   "t"
"animated spray" "animated_spray.mdl" "a"   0     0     10.0       40.0   45.0    1.0    500   ""
```

Parameter description:
* `name` - spray name.
* `model` - model name. Models with *.mdl* or *.spr* extension are allowed. Same models can be used on different sprays.
* `type` - spray type (*n* - normal spray, *a* - animated spray).
* `body` - submodel number (sprite frame).
* `skin` - skin number.
* `framerate` - frame rate for the animated spray.
* `width` - spray width.
* `height` - spray height.
* `scale` - sprite scale.
* `cost` - cost. *This parameter can only be used via API*.
* `access` - access flag. *This parameter can only be used via API*.

## API
API is described in [this file](addons/amxmodx/scripting/include/hdsprays.inc).
An example with menu implementation is presented in plugin [next21_hd_sprays_menu.sma](addons/amxmodx/scripting/next21_hd_sprays_menu.sma). Open sprays menu is done with the command `say /spray`.

## Spray generator
To quickly create sprays from a set of images, it is recommended to use the tool **sprays_gen**. [Detailed description of the tool](utils/sprays_gen/README.md)

## Requirements
- [Reapi](https://github.com/s1lentq/reapi)

## Authors
- [Psycrow](https://github.com/Psycrow101)
- [Polarhigh](https://github.com/Polarhigh)