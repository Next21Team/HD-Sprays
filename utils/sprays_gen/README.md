# sprays_gen

_**English** | [Русский](README.ru.md)_

**sprays_gen** allows generating flat models for [HD-Sprays](https://github.com/Next21Team/HD-Sprays) from images. Most popular image formats are supported, including PNG, BMP, GIF, etc. Together with the models, a ready-made configuration file *sprays.ini* is created.

## Requirements
* Python 3 interpreter
* module [Pillow](https://pillow.readthedocs.io/en/stable/)

## Usage
Before running **sprays_gen** you need to install Python 3 interpreter and dependent modules: [Pillow](https://pillow.readthedocs.io/en/stable/). Launch command:

```python sprays_gen.py [-h] --input INPUT [--output OUTPUT] [--config CONFIG]```

`--input, -i` path to file with list of sprays in JSON format

`--output, -o` path to the directory where the result should be written (default "dist")

`--config, -cfg` config.ini configuration (default "DEFAULT")

The file with the list of sprays corresponds to the following template:
```json
{
	"model_name": {
		"name": "spray name",
		"path": "file or directory",
		"framerate": 25.0,
		"cost": 100,
		"bodies": [
			{
				"name": "spray name",
				"path": "file",
				"cost": 100
			}
		]
	}
}
```

Spray list file parameters:
* `model_name` - name of the final model
* `path` - path to file or directory with images
* `framerate` - frame rate (only for animated spray)
* `cost` - cost of spray
* `bodies` - list of sprays inside directory `path` (not used for animated spray)
* `name` - spray name

Configuration file config.ini parameters:
* `transparent_sensitivity` - maximum alpha channel value for alphatest textures
* `max_width` - max texture width
* `max_height` - max texture height
* `scale` - texture resolution to model size ratio
* `gif_max_frames` - maximum number of frames in gif

*example* contains:
* directory with images *src*
* directory with result *dist*
* file with list of sprays *sprays.json*
* scripts with launch example *sprays_gen.bat* and *sprays_gen.sh*

After successfully running the script *sprays_gen*, creation is expected:
* models *dist/spray_pack.mdl* from images directory *src/spray_pack*
* models *animated_spray.mdl* from images directory *src/animated_spray*
* models *animated_spray2.mdl* from animated image *src/animated_spray2.gif*
* configuration file *dist/sprays.ini*
