# sprays_gen

_[English](README.md) | **Русский**_

**sprays_gen** позволяет генерировать плоские модели для [HD-Sprays](https://github.com/Next21Team/HD-Sprays) из изображений. Поддерживается большинство популярных форматов изображений, включая PNG, BMP, GIF и т.д. Вместе с моделями создается готовый конфигурационный файл *sprays.ini*.

## Требования
* интерпретатор Python 3
* модуль [Pillow](https://pillow.readthedocs.io/en/stable/)

## Использование
Перед запуском **sprays_gen** необходимо установить интерпретатор Python 3 и зависимые модули: [Pillow](https://pillow.readthedocs.io/en/stable/). Запуск осуществляется командой:

```python sprays_gen.py [-h] --input INPUT [--output OUTPUT] [--config CONFIG]```

`--input, -i` путь к файлу со списком спреев в формате JSON

`--output, -o` путь к директории, в которую необходимо записать результат (по умолчанию "dist")

`--config, -cfg` конфигурация config.ini (по умолчанию "DEFAULT")

Файл со списком спреев соответствует следующему шаблону:
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

Параметры файла со списком спреев:
* `model_name` - имя итоговой модели
* `path` - путь к файлу или директории с изображениями
* `framerate` - частота кадров (только для анимированного спрея)
* `cost` - цена спрея
* `bodies` - список спреев внутри директории `path` (не использовать для анимированного спрея)
* `name` - имя спрея

Параметры конфигурационного файла config.ini:
* `transparent_sensitivity` - максимальное значение альфа-канала для alphatest текстур
* `max_width` - максимальная ширина текстуры
* `max_height` - максимальная высота текстуры
* `scale` - соотношение разрешения текстуры к размеру модели
* `gif_max_frames` - максимальное количество кадров в GIF

В *example* содержится пример для генерации спрея:
* директория с изображениями *src*
* директория с результатом *dist*
* файл со списком спреев *sprays.json*
* скрипты с примером запуска *sprays_gen.bat* и *sprays_gen.sh*

После успешного запуска скрипта *sprays_gen* ожидается создание:
* модели *dist/spray_pack.mdl* из изображений директории *src/spray_pack*
* модели *animated_spray.mdl* из изображений директории *src/animated_spray*
* модели *animated_spray2.mdl* из анимированного изображения *src/animated_spray2.gif*
* конфигурационного файла *dist/sprays.ini*
