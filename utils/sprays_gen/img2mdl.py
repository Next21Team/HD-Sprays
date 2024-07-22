import math

from dataclasses import dataclass
from os import path
from PIL import Image

from binary_writer import *


@dataclass
class Frame:
    name: str
    image: Image
    is_masked: bool


class MdlMaker:
    def __init__(self, name):
        self.name = name
        self.frames = []

    def add_image(self, img_path, max_width, max_height,
                  transparent_sensitivity, max_frames):
        src_img = Image.open(img_path)
        images = []

        src_frames = []
        if hasattr(src_img, "n_frames"):
            if max_frames > 0 and src_img.n_frames > max_frames:
                frame_step = src_img.n_frames / max_frames
            else:
                frame_step = 1

            f = 0
            while math.ceil(f) < src_img.n_frames:
                src_img.seek(math.ceil(f))
                src_frames.append(src_img.convert('RGBA'))
                f += frame_step
        else:
            src_frames.append(src_img.convert('RGBA'))

        for f, src_frame in enumerate(src_frames):
            if src_frame.width > max_width:
                src_frame.thumbnail((max_width, src_frame.height), Image.LANCZOS)
            if src_frame.height > max_height:
                src_frame.thumbnail((src_frame.width, max_height), Image.LANCZOS)

            src_frame = src_frame.crop((0, 0, math.floor(src_frame.width / 8) * 8,
                            math.floor(src_frame.height / 8) * 8))

            img = src_frame.quantize(256, 2)

            alpha_mask = list(src_frame.split()[-1].getdata())
            colors = list(img.getdata())

            min_alpha = sorted(alpha_mask)[0]
            is_masked = min_alpha < transparent_sensitivity

            if is_masked:
                transparents_index = colors[alpha_mask.index(min_alpha)]

                for i, c in enumerate(colors):
                    if alpha_mask[i] < transparent_sensitivity:
                        colors[i] = 255
                    elif c == 255:
                        colors[i] = transparents_index
                    elif c == transparents_index:
                        colors[i] = 255

                img.putdata(colors)

            frame_name = path.splitext(path.basename(img_path))[0]
            if len(src_frames) > 1:
                frame_name += "_%d" % f

            self.frames.append(Frame(frame_name, img, is_masked))
            images.append(img)

        return images

    def pack_studio_model(self, scale):
        frames_num = len(self.frames)

        bones_segment = self._pack_studio_bones()
        sequences_segment = self._pack_studio_sequences()

        bodyparts_offset = 0x028C
        bodyparts_segment = self._pack_studio_bodyparts(bodyparts_offset, scale)

        textures_offset = bodyparts_offset + len(bodyparts_segment)
        skins_offset = textures_offset + frames_num * 80
        pixeldata_offset = ((skins_offset + frames_num * 2) + 3) & ~3
        textures_segment = self._pack_studio_textures(textures_offset)

        data = b''
        data += b'IDST'
        data += pack_uint32(10) # version
        data += pack_string(self.name, 64)
        data += pack_uint32(textures_offset + len(textures_segment))
        data += pack_float32((0,)* 15) # eye position, min, max, bbmin, bbmax
        data += pack_uint32(0) # flags

        data += pack_uint32((1, 0xF4)) # bones
        data += pack_uint32((0, 0x0164)) # bone controllers
        data += pack_uint32((0, 0x0164)) # hitboxes
        data += pack_uint32((1, 0x0174)) # sequences
        data += pack_uint32((1, 0x0224)) # sequence groups

        data += pack_uint32((frames_num, textures_offset, pixeldata_offset)) # textures
        data += pack_uint32((frames_num, 1, skins_offset)) # skins
        data += pack_uint32((1, bodyparts_offset)) # bodyparts

        data += pack_uint32((0, 0x164)) # attachments
        data += pack_uint32((0, 0, 0, 0))
        data += pack_uint32((0, bodyparts_offset)) # transitions

        data += bones_segment
        data += sequences_segment
        data += bodyparts_segment
        data += textures_segment

        return data

    def _pack_studio_bones(self):
        data = b''
        data += pack_string("root", 32)
        data += b'\xFF\xFF\xFF\xFF\x00\x00\x00\x00'
        data += b'\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x01\x80\x3B\x00\x01\x80\x3B\x00\x01\x80\x3B\x6D\x11\x49\x37\x6D\x11\x49\x37\x6D\x11\x49\x38'
        return data

    def _pack_studio_sequences(self):
        data = b''
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x0C\x00\x01\x01\xFF\x7F'
        data += pack_string("idle", 32)
        data += b'\x00\x00\x80\x3F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x24\x02\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x24\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x04\x01\x04\xB6\x00\x00\x34\xC2\x00\x00\x34\xC2\x04\x01\x04\x36'
        data += b'\x00\x00\x34\x42\x00\x00\x34\x42\x01\x00\x00\x00\x64\x01\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x80\x3F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x64\x65\x66\x61\x75\x6C\x74\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        data += b'\x00\x00\x00\x00\x00\x00\x00\x00'
        return data

    def _pack_studio_bodyparts(self, bodyparts_offset, scale):
        data_offset = bodyparts_offset + 76

        data = b''
        data += pack_string("sprays", 64)
        data += pack_uint32((len(self.frames), 1, data_offset))

        data_offset += len(self.frames) * 112

        for i, frame in enumerate(self.frames):
            offset = data_offset + i * 124

            data += pack_string(frame.name, 64)
            data += pack_int32(0) # type
            data += pack_float32(0) # bounding radius

            data += pack_uint32((1, offset + 68)) # mesh
            data += pack_uint32((4, offset + 0, offset + 8)) # vertices
            data += pack_uint32((1, offset + 4, offset + 56)) # normals

            data += pack_uint32((0, 0)) # boneweighted info

        for i, frame in enumerate(self.frames):
            offset = data_offset + i * 124
            w, h = frame.image.width, frame.image.height
            x, y = w * scale, h * scale

            data += b'\x00\x00\x00\x00\x00\x00\x00\x00'

            data += pack_float32((-x, 0, -y))
            data += pack_float32((x, 0, -y))
            data += pack_float32((-x, 0, y))
            data += pack_float32((x, 0, y))
            data += pack_float32((0, -1, 0))

            data += pack_uint32((2, offset + 88, i, 1, 0))

            data += pack_int16(4)
            data += pack_int16((0, 0, 1, h - 2))
            data += pack_int16((2, 0, 1, 1))
            data += pack_int16((1, 0, w - 2, h - 2))
            data += pack_int16((3, 0, w - 2, 1))
            data += pack_int16(0)

        return data

    def _pack_studio_textures(self, textures_offset):
        frames_num = len(self.frames)

        skins_offset = textures_offset + frames_num * 80
        pixeldata_offset = ((skins_offset + frames_num * 2) + 3) & ~3

        data = b''

        for frame in self.frames:
            w, h = frame.image.width, frame.image.height
            data += pack_string(frame.name + '.bmp', 64)
            data += pack_uint32((64 if frame.is_masked else 0, w, h, pixeldata_offset))
            pixeldata_offset += ((w * h + 256 * 3) + 3) & ~3

        data += pack_int16([i for i in range(frames_num)])
        if frames_num % 2 != 0:
            data += b'\x00\x00'

        for frame in self.frames:
            idx_len = frame.image.width * frame.image.height
            data += pack_uint8(frame.image.getdata())
            data += pack_uint8(frame.image.getpalette())
            if idx_len % 4 != 0:
                data += b'\x00' * (4 - (idx_len % 4))

        return data
