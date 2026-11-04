import os
import sys
import struct

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

def parse_pe_imports(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()

    if data[:2] != b'MZ':
        return {}
    pe_offset = struct.unpack('<I', data[0x3C:0x40])[0]
    if data[pe_offset:pe_offset+4] != b'PE\0\0':
        return {}
    
    magic = struct.unpack('<H', data[pe_offset+0x18:pe_offset+0x1A])[0]
    if magic == 0x10b: # PE32
        import_rva = struct.unpack('<I', data[pe_offset+0x80:pe_offset+0x84])[0]
        num_sections = struct.unpack('<H', data[pe_offset+0x06:pe_offset+0x08])[0]
        opt_hdr_size = struct.unpack('<H', data[pe_offset+0x14:pe_offset+0x16])[0]
        sec_offset = pe_offset + 0x18 + opt_hdr_size
    elif magic == 0x20b: # PE32+
        import_rva = struct.unpack('<I', data[pe_offset+0x90:pe_offset+0x94])[0]
        num_sections = struct.unpack('<H', data[pe_offset+0x06:pe_offset+0x08])[0]
        opt_hdr_size = struct.unpack('<H', data[pe_offset+0x14:pe_offset+0x16])[0]
        sec_offset = pe_offset + 0x18 + opt_hdr_size
    else:
        return {}

    if import_rva == 0:
        return {}

    sections = []
    for i in range(num_sections):
        s_data = data[sec_offset + i*40 : sec_offset + (i+1)*40]
        v_size, v_addr, r_size, r_ptr = struct.unpack('<IIII', s_data[8:24])
        sections.append((v_addr, v_size, r_ptr, r_size))

    def rva_to_offset(rva):
        for v_addr, v_size, r_ptr, r_size in sections:
            if v_addr <= rva < v_addr + max(v_size, r_size):
                return r_ptr + (rva - v_addr)
        return None

    imp_off = rva_to_offset(import_rva)
    if not imp_off:
        return {}

    imports = {}
    curr_desc = imp_off
    while True:
        orig_first_thunk, timedate, forwarder, name_rva, first_thunk = struct.unpack('<IIIII', data[curr_desc:curr_desc+20])
        if name_rva == 0 and first_thunk == 0:
            break
        dll_name_off = rva_to_offset(name_rva)
        if dll_name_off:
            dll_name = data[dll_name_off:data.find(b'\0', dll_name_off)].decode('latin1', errors='replace')
        else:
            dll_name = f"unknown_{name_rva}"

        funcs = []
        thunk_rva = orig_first_thunk if orig_first_thunk != 0 else first_thunk
        thunk_off = rva_to_offset(thunk_rva)
        if thunk_off:
            idx = 0
            while True:
                if magic == 0x10b:
                    val = struct.unpack('<I', data[thunk_off + idx*4 : thunk_off + (idx+1)*4])[0]
                    idx += 1
                    if val == 0:
                        break
                    if val & 0x80000000: # ordinal
                        funcs.append(f"Ordinal_{val & 0xFFFF}")
                    else:
                        ibn_off = rva_to_offset(val)
                        if ibn_off:
                            fname = data[ibn_off+2:data.find(b'\0', ibn_off+2)].decode('latin1', errors='replace')
                            funcs.append(fname)
                else:
                    val = struct.unpack('<Q', data[thunk_off + idx*8 : thunk_off + (idx+1)*8])[0]
                    idx += 1
                    if val == 0:
                        break
                    if val & 0x8000000000000000:
                        funcs.append(f"Ordinal_{val & 0xFFFF}")
                    else:
                        ibn_off = rva_to_offset(val)
                        if ibn_off:
                            fname = data[ibn_off+2:data.find(b'\0', ibn_off+2)].decode('latin1', errors='replace')
                            funcs.append(fname)
        imports[dll_name] = funcs
        curr_desc += 20

    return imports

vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"
targets = [
    os.path.join(vlc_dir, "libvlccore.dll"),
    os.path.join(vlc_dir, "libvlc.dll"),
    os.path.join(vlc_dir, "plugins", "access", "libfilesystem_plugin.dll"),
    os.path.join(vlc_dir, "plugins", "services_discovery", "libmediadirs_plugin.dll"),
    os.path.join(vlc_dir, "plugins", "gui", "libqt_plugin.dll"),
]

for t in targets:
    print(f"\n==========================================")
    print(f"FILE: {t}")
    if not os.path.exists(t):
        print("File does not exist")
        continue
    imports = parse_pe_imports(t)
    print(f"Imported DLLs ({len(imports)}): {list(imports.keys())}")
    for dll, funcs in imports.items():
        rel = [f for f in funcs if any(k in f.lower() for k in ["find", "dir", "file", "path", "notify", "change", "watch", "shell", "folder"])]
        if rel:
            print(f"  DLL: {dll} -> {rel}")
