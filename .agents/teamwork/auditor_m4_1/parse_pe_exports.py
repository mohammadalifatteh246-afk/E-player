import struct
import sys

def parse_pe_exports(pe_path):
    with open(pe_path, 'rb') as f:
        data = f.read()

    # DOS Header
    if data[:2] != b'MZ':
        raise ValueError("Not a PE file (missing MZ)")
    e_lfanew = struct.unpack_from('<I', data, 0x3C)[0]

    # PE Signature
    if data[e_lfanew:e_lfanew+4] != b'PE\0\0':
        raise ValueError("Not a PE file (missing PE)")

    machine = struct.unpack_from('<H', data, e_lfanew + 4)[0]
    num_sections = struct.unpack_from('<H', data, e_lfanew + 6)[0]
    opt_header_size = struct.unpack_from('<H', data, e_lfanew + 20)[0]
    opt_magic = struct.unpack_from('<H', data, e_lfanew + 24)[0]

    opt_header_offset = e_lfanew + 24
    if opt_magic == 0x10b: # PE32
        export_rva = struct.unpack_from('<I', data, opt_header_offset + 96)[0]
        export_size = struct.unpack_from('<I', data, opt_header_offset + 100)[0]
    elif opt_magic == 0x20b: # PE32+
        export_rva = struct.unpack_from('<I', data, opt_header_offset + 112)[0]
        export_size = struct.unpack_from('<I', data, opt_header_offset + 116)[0]
    else:
        raise ValueError(f"Unknown magic: {hex(opt_magic)}")

    if export_rva == 0 or export_size == 0:
        return 0, []

    # Section Headers
    section_offset = opt_header_offset + opt_header_size
    sections = []
    for i in range(num_sections):
        sec = data[section_offset + i*40 : section_offset + (i+1)*40]
        name = sec[:8].rstrip(b'\0').decode('latin1', errors='ignore')
        vsize = struct.unpack_from('<I', sec, 8)[0]
        rva = struct.unpack_from('<I', sec, 12)[0]
        raw_size = struct.unpack_from('<I', sec, 16)[0]
        raw_offset = struct.unpack_from('<I', sec, 20)[0]
        sections.append((name, rva, vsize, raw_offset, raw_size))

    def rva_to_offset(rva):
        for name, sec_rva, sec_vsize, raw_offset, raw_size in sections:
            if sec_rva <= rva < sec_rva + max(sec_vsize, raw_size):
                return raw_offset + (rva - sec_rva)
        return None

    exp_offset = rva_to_offset(export_rva)
    if exp_offset is None:
        raise ValueError("Cannot resolve export table RVA")

    num_funcs = struct.unpack_from('<I', data, exp_offset + 20)[0]
    num_names = struct.unpack_from('<I', data, exp_offset + 24)[0]
    names_rva = struct.unpack_from('<I', data, exp_offset + 32)[0]

    names_offset = rva_to_offset(names_rva)
    names = []
    if names_offset:
        for i in range(num_names):
            name_rva = struct.unpack_from('<I', data, names_offset + i*4)[0]
            str_off = rva_to_offset(name_rva)
            if str_off:
                end = data.find(b'\0', str_off)
                names.append(data[str_off:end].decode('latin1', errors='ignore'))

    return num_funcs, num_names, names

for path in [r"C:\Program Files (x86)\VideoLAN\VLC\libvlccore.dll", r"C:\Program Files (x86)\VideoLAN\VLC\libvlc.dll"]:
    n_funcs, n_names, names = parse_pe_exports(path)
    print(f"File: {path}")
    print(f"  Exported functions (count): {n_funcs}")
    print(f"  Exported names (count): {n_names}")
    print(f"  First 5 names: {names[:5]}")
    print(f"  Last 5 names: {names[-5:]}")
