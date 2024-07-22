import struct


def pack_val(vals, t, en='<'):
    data = vals if hasattr(vals, '__len__') else (vals, )
    return struct.pack('%s%d%s' % (en, len(data), t), *data)


def pack_int8(vals, en='<'):
    return pack_val(vals, 'b', en)


def pack_uint8(vals, en='<'):
    return pack_val(vals, 'B', en)


def pack_int16(vals, en='<'):
    return pack_val(vals, 'h', en)


def pack_uint16(vals, en='<'):
    return pack_val(vals, 'H', en)


def pack_int32(vals, en='<'):
    return pack_val(vals, 'i', en)


def pack_uint32(vals, en='<'):
    return pack_val(vals, 'I', en)


def pack_float32(vals, en='<'):
    return pack_val(vals, 'f', en)


def pack_string(val, strlen=0):
    data = val.encode()
    if strlen > len(val):
        data += b'\00' * (strlen - len(val))
    return data


def write_int8(fd, vals, en='<'):
    fd.write(pack_int16(vals, en))


def write_uint8(fd, vals, en='<'):
    fd.write(pack_uint8(vals, en))


def write_int16(fd, vals, en='<'):
    fd.write(pack_int8(vals, en))


def write_uint16(fd, vals, en='<'):
    fd.write(pack_uint16(vals, en))


def write_int32(fd, vals, en='<'):
    fd.write(pack_int32(vals, en))


def write_uint32(fd, vals, en='<'):
    fd.write(pack_uint32(vals, en))


def write_string(fd, val, strlen=0):
    fd.write(pack_string(val, strlen))
