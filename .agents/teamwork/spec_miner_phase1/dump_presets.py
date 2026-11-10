import struct

path = r'C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll'
with open(path, 'rb') as f:
    data = f.read()

# Base offset: 0xA080
# 18 presets, each 64 bytes
for i in range(18):
    off = 0xA080 + i * 64
    words = [struct.unpack_from('<I', data, off + j*4)[0] for j in range(16)]
    floats = [struct.unpack_from('<f', data, off + j*4)[0] for j in range(16)]
    
    # Check word 0 string
    s_val = ''
    w0 = words[0]
    if 0x67A8C000 <= w0 <= 0x67A8D000:
        s_off = w0 - 0x67A80000 - 0xC000 + 0x9C00
        end = data.find(b'\x00', s_off)
        s_val = data[s_off:end].decode('latin1')
    
    print(f'Preset {i:02d}: NamePtr=0x{w0:08X} ("{s_val}") | word1={words[1]}')
    # Let's print all 16 words/floats
    flt_strs = [f'{flt:6.1f}' for flt in floats]
    print('  Floats:', flt_strs)
