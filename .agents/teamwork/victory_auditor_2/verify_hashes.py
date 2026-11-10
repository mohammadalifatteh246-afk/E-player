import os
import hashlib

vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"
files_to_check = [
    ("vlc.exe", 1037760, "499d578564d27529bc08ef9ccb4c5043e25a49d21d2d41fb2176cc3563e8f0d7"),
    ("vlc-cache-gen.exe", 142272, "9f371eb0914f17d685e8ee53bf58794cf794a68a86b1da2a2929360fc57053f2"),
    ("libvlc.dll", 184768, "0eac5ccd4c57a52318d4872d54921a226bb1ec2663edbfe20a0fb4c930bd9444"),
    ("libvlccore.dll", 3133896, "92fee94eaef57ed6ae806d213963eb78c911f37ba689cbb1a90ca4a0123ca5e1"),
    ("axvlc.dll", 1351616, "07abbc2c7fd613602b98aa9b4d9060846fc9d917bd529531d79443d8f3f9226c"),
    ("uninstall.exe", 265014, "27d7b97800f34851d6fae6e3fcc4d3c09fdb50801c99d3b2ea09bf7d698a1938"),
]

print("=== Checking VLC Binaries Hashes and Sizes ===")
all_match = True
for name, exp_size, exp_hash in files_to_check:
    path = os.path.join(vlc_dir, name)
    if not os.path.exists(path):
        print(f"FAIL: {name} does not exist")
        all_match = False
        continue
    actual_size = os.path.getsize(path)
    with open(path, "rb") as f:
        actual_hash = hashlib.sha256(f.read()).hexdigest()
    
    size_ok = (actual_size == exp_size)
    hash_ok = (actual_hash == exp_hash)
    if not (size_ok and hash_ok):
        all_match = False
    print(f"{name}: size={actual_size} (match={size_ok}), sha256={actual_hash[:16]}... (match={hash_ok})")

print("All hashes and sizes match:", all_match)

plugins_dat = os.path.join(vlc_dir, "plugins", "plugins.dat")
if os.path.exists(plugins_dat):
    print("plugins.dat size:", os.path.getsize(plugins_dat))
