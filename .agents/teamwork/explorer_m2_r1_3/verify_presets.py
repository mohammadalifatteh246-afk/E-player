import struct

path = r'C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll'
with open(path, 'rb') as f:
    data = f.read()

target_indices = {
    'Full Bass': 4,
    'Full Bass & Treble': 5,
    'Full Treble': 6,
    'Headphones': 7,
    'Large Hall': 8,
    'Live': 9,
    'Party': 10,
    'Reggae': 12,
    'Ska': 14,
    'Soft': 15,
    'Soft Rock': 16
}

for name, idx in target_indices.items():
    off = 0xA080 + idx * 64
    vlc_name = data[off:off+20].split(b'\x00')[0].decode('latin1')
    preamp_bytes = data[off+20:off+24]
    preamp = struct.unpack('<f', preamp_bytes)[0]
    bands_bytes = [data[off+24+j*4 : off+24+(j+1)*4] for j in range(10)]
    bands = [struct.unpack('<f', b)[0] for b in bands_bytes]
    print(f'=== {name} (VLC raw name: "{vlc_name}", index: {idx}) ===')
    print(f'  Preamp: {preamp:.1f} dB (bytes: {preamp_bytes.hex()})')
    print('  Bands (dB):', [round(b, 1) for b in bands])
    print('  Bands (raw float):', [round(b, 6) for b in bands])
    print('  Bands (hex):', [b.hex() for b in bands_bytes])
