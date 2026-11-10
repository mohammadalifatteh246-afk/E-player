import struct
import os

def count_pe_exports(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    # DOS Header
    if data[:2] != b'MZ':
        return None
    e_lfanew = struct.unpack_from('<I', data, 0x3C)[0]
    
    # PE Header
    if data[e_lfanew:e_lfanew+4] != b'PE\x00\x00':
        return None
    
    magic = struct.unpack_from('<H', data, e_lfanew + 24)[0]
    if magic == 0x10b: # PE32
        export_rva = struct.unpack_from('<I', data, e_lfanew + 24 + 96)[0]
    elif magic == 0x20b: # PE32+
        export_rva = struct.unpack_from('<I', data, e_lfanew + 24 + 112)[0]
    else:
        return None
    
    if export_rva == 0:
        return 0
    
    # Section headers
    num_sections = struct.unpack_from('<H', data, e_lfanew + 6)[0]
    opt_header_size = struct.unpack_from('<H', data, e_lfanew + 20)[0]
    section_start = e_lfanew + 24 + opt_header_size
    
    export_offset = None
    for i in range(num_sections):
        sec = section_start + i * 40
        v_addr = struct.unpack_from('<I', data, sec + 12)[0]
        v_size = struct.unpack_from('<I', data, sec + 8)[0]
        raw_offset = struct.unpack_from('<I', data, sec + 20)[0]
        if v_addr <= export_rva < v_addr + v_size:
            export_offset = raw_offset + (export_rva - v_addr)
            break
            
    if export_offset is None:
        return 0
        
    num_names = struct.unpack_from('<I', data, export_offset + 24)[0]
    return num_names

vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"
libvlc = os.path.join(vlc_dir, "libvlc.dll")
libvlccore = os.path.join(vlc_dir, "libvlccore.dll")

print("libvlc.dll exports:", count_pe_exports(libvlc))
print("libvlccore.dll exports:", count_pe_exports(libvlccore))
