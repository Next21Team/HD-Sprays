#!/bin/python

import configparser
import json
import os
import pathlib
import sys

from argparse import ArgumentParser
from dataclasses import dataclass
from img2mdl import MdlMaker


def fatal(*args, **kwargs):
    print("[ERR]", *args, file=sys.stderr, **kwargs)
    sys.exit(1)


def warn(*args, **kwargs):
    print("[WARN]", *args, **kwargs)


class Config:
    def __init__(self, path, preset: str):
        parser = configparser.ConfigParser()

        if os.path.isfile(path):
            parser.read(path)
        else:
            warn('Config file %s not does not exist' % path)

        if preset not in parser:
            warn("Config preset %s not found" % preset)

        self.transparent_sensitivity = parser.getint(preset, "transparent_sensitivity", fallback=False)
        self.max_width = parser.getint(preset, "max_width", fallback=512)
        self.max_height = parser.getint(preset, "max_height", fallback=512)
        self.scale = parser.getfloat(preset, "scale", fallback=0.087890625)
        self.gif_max_frames = parser.getint(preset, "gif_max_frames", fallback=40)


@dataclass
class Spray:
    name:       str
    model:      str
    cost:       int
    image_path: str
    spray_type: str = "n"
    body:       int = 0
    skin:       int = 0
    framerate:  float = 1.0
    width:      int = 0
    height:     int = 0
    scale:      float = 1.0
    access:     str = ""

    def write(self, file):
        file.write('"%s" "%s" "%s" %d %d %f %f %f %f %d "%s"\n' % (
            self.name,
            self.model,
            self.spray_type,
            self.body,
            self.skin,
            self.framerate,
            self.width,
            self.height,
            self.scale,
            self.cost,
            self.access
        ))


def parse_spraypack_body(model_name, dir_path, body, body_num) -> Spray:
    name = body.get("name")
    path = body.get("path")
    cost = body.get("cost")

    if name is None or type(name) is not str:
        warn("Missing name for %s body" % model_name)
        return

    if path is None or type(path) is not str:
        warn("Missing path for %s | %s" % (model_name, name))
        return

    if cost is None or type(cost) is not int:
        warn("Missing cost for %s | %s" % (model_name, name))
        return

    path = os.path.join(dir_path, path)
    if not os.path.isfile(path):
        warn("Invalid path for %s | %s" % (model_name, name))
        return

    return Spray(
            name=name,
            model=model_name + ".mdl",
            body=body_num,
            cost=cost,
            image_path=path,
        )


def parse_spraypack(model_name, path, bodies) -> list:
    sprays = []

    if path is None or type(path) is not str:
        warn("Missing path for %s" % model_name)
        return sprays

    if type(bodies) is not list:
        warn("Missing bodies for %s" % model_name)
        return sprays

    if not os.path.isdir(path):
        warn("Invalid path for %s" % model_name)
        return sprays

    b = 0
    for body in bodies:
        spray = parse_spraypack_body(model_name, path, body, b)
        if spray:
            sprays.append(spray)
            b += 1

    return sprays


def parse_spray(model_name, data) -> Spray:
    name      = data.get("name")
    path      = data.get("path")
    cost      = data.get("cost")
    framerate = data.get("framerate")

    if name is None or type(name) is not str:
        warn("Missing name for %s" % model_name)
        return

    if path is None or type(path) is not str:
        warn("Missing path for %s" % model_name)
        return

    if cost is None or type(cost) is not int:
        warn("Missing cost for %s" % model_name)
        return

    if not os.path.isfile(path) and not os.path.isdir(path):
        warn("Invalid path for %s" % model_name)
        return

    if framerate is None or type(framerate) not in (int, float):
        framerate = 1.0

    return Spray(
            name=name,
            model=model_name + ".mdl",
            framerate=framerate,
            cost=cost,
            image_path=path,
        )


def parse_sprays_list(list_path):
    with open(list_path, "r", encoding="utf-8") as fd:
        sprays_list = json.load(fd)

    spray_packs = []

    for model_name, data in sprays_list.items():
        sprays = None

        bodies = data.get("bodies")
        if bodies:
            path = data.get("path")
            sprays = parse_spraypack(model_name, path, bodies)
        else:
            spray = parse_spray(model_name, data)
            if spray:
                sprays = [spray]

        if sprays:
            spray_packs.append(sprays)

    return spray_packs


def make_sprays(spray_packs, output_dir_path, cfg: Config):
    for sprays in spray_packs:
        mdl_maker = MdlMaker(sprays[0].model)

        if len(sprays) > 1:
            for spray in sprays:
                img = mdl_maker.add_image(spray.image_path,
                                    cfg.max_width,
                                    cfg.max_height,
                                    cfg.transparent_sensitivity,
                                    1)[0]

                spray.width = img.width * cfg.scale
                spray.height = img.width * cfg.scale
                spray.spray_type = "n"
        else:
            spray = sprays[0]
            if os.path.isdir(spray.image_path):
                images = sorted(filter(lambda x: os.path.isfile(os.path.join(spray.image_path, x)),
                                       os.listdir(spray.image_path)))

                for i in images:
                    image_path = os.path.join(spray.image_path, i)
                    img = mdl_maker.add_image(image_path,
                                        cfg.max_width,
                                        cfg.max_height,
                                        cfg.transparent_sensitivity,
                                        1)[0]

                    spray.width = max(spray.width, img.width * cfg.scale)
                    spray.height = max(spray.height, img.width * cfg.scale)
                    spray.spray_type = "a"

            else:
                imgs = mdl_maker.add_image(spray.image_path,
                                          cfg.max_width,
                                          cfg.max_height,
                                          cfg.transparent_sensitivity,
                                          cfg.gif_max_frames)

                spray.width = max(img.width * cfg.scale for img in imgs)
                spray.height = img.width * cfg.scale
                spray.spray_type = "a" if len(imgs) > 1 else "n"

        mdl_path = os.path.join(output_dir_path, mdl_maker.name)

        with open(mdl_path, 'wb') as fd:
            fd.write(mdl_maker.pack_studio_model(cfg.scale))


def save_sprays_list(spray_packs, file_path):
     with open(file_path, "w", encoding="utf-8") as fd:
         fd.write('; "name"   "model"   type   body  skin    framerate   width   height   scale   cost   access\n')
         for sprays in spray_packs:
             for spray in sprays:
                 spray.write(fd)


def parse_args():
    parser = ArgumentParser()
    parser.add_argument('--input', '-i', required=True, help='sprays list file path')
    parser.add_argument('--output', '-o', help='output directory', default="dist")
    parser.add_argument('--config', '-cfg', help='config preset', default="DEFAULT")
    return parser.parse_args()


def main():
    work_path = pathlib.Path(__file__).parent.resolve()
    cfg_path = os.path.join(work_path, 'config.ini')

    args = parse_args()
    cfg = Config(cfg_path, args.config)

    if not os.path.isfile(args.input):
        fatal('Sprays list file %s not does not exist' % args.input)

    spray_packs = parse_sprays_list(args.input)

    print("Detected %d spray models. Type <y> to continue" % len(spray_packs))
    if input() != "y":
        sys.exit(0)

    if not os.path.isdir(args.output):
        os.mkdir(args.output)

    make_sprays(spray_packs, args.output, cfg)
    save_sprays_list(spray_packs, os.path.join(args.output, "sprays.ini"))


if __name__ == '__main__':
    main()
