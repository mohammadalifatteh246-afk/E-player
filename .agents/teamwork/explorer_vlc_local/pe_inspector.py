import os
import sys
import struct
import re

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

def parse_pe_exports(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()

    if data[:2] != b'MZ':
        return []
    pe_offset = struct.unpack('<I', data[0x3C:0x40])[0]
    if data[pe_offset:pe_offset+4] != b'PE\0\0':
        return []
    
    magic = struct.unpack('<H', data[pe_offset+0x18:pe_offset+0x1A])[0]
    if magic == 0x10b: # PE32
        export_rva = struct.unpack('<I', data[pe_offset+0x78:pe_offset+0x7C])[0]
        export_size = struct.unpack('<I', data[pe_offset+0x7C:pe_offset+0x80])[0]
        num_sections = struct.unpack('<H', data[pe_offset+0x06:pe_offset+0x08])[0]
        opt_hdr_size = struct.unpack('<H', data[pe_offset+0x14:pe_offset+0x16])[0]
        sec_offset = pe_offset + 0x18 + opt_hdr_size
    elif magic == 0x20b: # PE32+
        export_rva = struct.unpack('<I', data[pe_offset+0x88:pe_offset+0x8C])[0]
        export_size = struct.unpack('<I', data[pe_offset+0x8C:pe_offset+0x90])[0]
        num_sections = struct.unpack('<H', data[pe_offset+0x06:pe_offset+0x08])[0]
        opt_hdr_size = struct.unpack('<H', data[pe_offset+0x14:pe_offset+0x16])[0]
        sec_offset = pe_offset + 0x18 + opt_hdr_size
    else:
        return []

    if export_rva == 0:
        return []

    # Map RVA to file offset
    sections = []
    for i in range(num_sections):
        s_data = data[sec_offset + i*40 : sec_offset + (i+1)*40]
        s_name = s_data[:8].rstrip(b'\0')
        v_size, v_addr, r_size, r_ptr = struct.unpack('<IIII', s_data[8:24])
        sections.append((v_addr, v_size, r_ptr, r_size))

    def rva_to_offset(rva):
        for v_addr, v_size, r_ptr, r_size in sections:
            if v_addr <= rva < v_addr + max(v_size, r_size):
                return r_ptr + (rva - v_addr)
        return None

    exp_off = rva_to_offset(export_rva)
    if not exp_off:
        return []

    num_funcs, num_names, funcs_rva, names_rva, ords_rva = struct.unpack(
        '<IIIII', data[exp_off+20:exp_off+40]
    )

    names_off = rva_to_offset(names_rva)
    if not names_off:
        return []

    exported_names = []
    for i in range(num_names):
        name_rva = struct.unpack('<I', data[names_off + i*4 : names_off + (i+1)*4])[0]
        name_off = rva_to_offset(name_rva)
        if name_off:
            end = data.find(b'\0', name_off)
            exported_names.append(data[name_off:end].decode('latin1', errors='replace'))

    return exported_names

vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"
libvlc = os.path.join(vlc_dir, "libvlc.dll")
libvlccore = os.path.join(vlc_dir, "libvlccore.dll")

print(f"=== libvlc.dll Exports ===")
exports_libvlc = parse_pe_exports(libvlc)
print(f"Total exports in libvlc.dll: {len(exports_libvlc)}")
for name in sorted(exports_libvlc):
    if any(k in name.lower() for k in ["media", "library", "playlist", "folder", "dir", "browse", "discover"]):
        print("  ", name)

print(f"\n=== libvlccore.dll Exports ===")
exports_libvlccore = parse_pe_exports(libvlccore)
print(f"Total exports in libvlccore.dll: {len(exports_libvlccore)}")
for name in sorted(exports_libvlccore):
    if any(k in name.lower() for k in ["media", "library", "playlist", "folder", "dir", "browse", "discover", "item", "preparse"]):
        print("  ", name)
