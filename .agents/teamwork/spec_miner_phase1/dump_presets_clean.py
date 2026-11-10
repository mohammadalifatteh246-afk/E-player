import struct

path = r'C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll'
with open(path, 'rb') as f:
    data = f.read()

# Base offset: 0xA080
# 18 presets, each 64 bytes: char name[20], float preamp, float bands[10]
presets = []
for i in range(18):
    off = 0xA080 + i * 64
    name_raw = data[off:off+20]
    name = name_raw.split(b'\x00')[0].decode('latin1')
    preamp = struct.unpack_from('<f', data, off + 20)[0]
    bands = [struct.unpack_from('<f', data, off + 24 + j*4)[0] for j in range(10)]
    presets.append({
        'index': i,
        'name': name,
        'preamp': round(preamp, 1),
        'bands': [round(b, 1) for b in bands]
    })

for p in presets:
    print(f"Preset {p['index']:02d}: {p['name']:<20} | Preamp: {p['preamp']:+5.1f} dB | Bands: {p['bands']}")
