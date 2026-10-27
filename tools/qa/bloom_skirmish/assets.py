#!/usr/bin/env python3
"""Independent audio-byte, attribution, and module-resource boundary verification."""
from array import array
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys
from urllib.parse import unquote, urlsplit
import wave

root = Path(__file__).resolve().parents[3]
module = root / "godot/modules/bloom_skirmish"
manifest = json.loads((module / "audio/audio_manifest.json").read_text())
checks = 0

def check(condition, message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)

files = manifest["files"]
check(set(files) == {p.name for p in (module / "audio").glob("*.wav")}, "WAV set matches manifest")
check({"music_loop.wav", "shoot.wav", "hit.wav", "pod.wav", "bloom.wav", "dash.wav", "defeat.wav", "victory.wav", "ui_click.wav", "countdown.wav", "round_start.wav"} <= set(files), "Every runtime music/SFX path exists")
hashes = set()
for filename, info in files.items():
    path = module / "audio" / filename
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    check(digest == info["sha256"], f"{filename}: byte hash")
    hashes.add(digest)
    with wave.open(str(path), "rb") as stream:
        check(stream.getsampwidth() == 2 and stream.getcomptype() == "NONE", f"{filename}: uncompressed PCM16")
        check(stream.getframerate() == 44100, f"{filename}: 44.1kHz")
        channels = stream.getnchannels()
        check(channels == info["channels"] and channels in (1, 2), f"{filename}: channel count")
        duration = stream.getnframes() / stream.getframerate()
        check(abs(duration - info["duration_seconds"]) < 0.00001, f"{filename}: measured duration")
        samples = array("h", stream.readframes(stream.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
    peak = max(abs(value) for value in samples)
    check(peak > 0 and peak < 32767, f"{filename}: audible nonempty samples, no clipping")
    peak_dbfs = 20 * math.log10(peak / 32768)
    check(abs(peak_dbfs - info["peak_dbfs"]) < 0.02, f"{filename}: measured peak")
    if info.get("loop"):
        seam = max(abs(samples[channel] - samples[-channels + channel]) / 32768 for channel in range(channels))
        check(seam < 0.02, f"{filename}: bounded raw waveform loop seam")
check(len(hashes) == len(files), "Audio cues are not duplicate bytes")
for path in module.rglob("*"):
    if path.is_file() and path.suffix in {".gd", ".tscn", ".tres", ".gdshader"}:
        for ref in re.findall(r'res://[^"\s\)]+', path.read_text()):
            check(ref.startswith("res://modules/bloom_skirmish/"), f"{path.name}: no host or other-game resource dependency: {ref}")
for filename in ["ui/OFL.txt", "ui/SOURCE.txt", "art/README.md", "audio/README.md"]:
    check((module / filename).is_file(), f"Attribution/source record exists: {filename}")

# Imported artwork must retain the module's extraction boundary too. Textual
# res:// scanning cannot find an external glTF buffer or image hidden in a GLB.
for path in sorted(module.rglob("*.glb")):
    binary = path.read_bytes()
    check(len(binary) >= 20, f"{path.name}: nonempty GLB header")
    magic, version, length = struct.unpack_from("<III", binary)
    check(magic == 0x46546C67 and version == 2 and length == len(binary), f"{path.name}: complete GLB 2 container")
    chunks = []
    cursor = 12
    while cursor < len(binary):
        check(cursor + 8 <= len(binary), f"{path.name}: complete chunk header")
        chunk_size, chunk_type = struct.unpack_from("<II", binary, cursor)
        cursor += 8
        check(chunk_size % 4 == 0 and cursor + chunk_size <= len(binary), f"{path.name}: aligned bounded chunk")
        chunks.append((chunk_type, binary[cursor:cursor + chunk_size]))
        cursor += chunk_size
    check(chunks and chunks[0][0] == 0x4E4F534A, f"{path.name}: first chunk is glTF JSON")
    document = json.loads(chunks[0][1])
    check(document.get("asset", {}).get("version") == "2.0", f"{path.name}: glTF 2 asset metadata")
    check(bool(document.get("meshes")), f"{path.name}: actual imported mesh content")
    for resource in document.get("buffers", []) + document.get("images", []):
        uri = resource.get("uri")
        if uri is None or uri.startswith("data:"):
            continue
        parsed = urlsplit(uri)
        check(not parsed.scheme and not parsed.netloc and not parsed.query and not parsed.fragment, f"{path.name}: no network or absolute URI dependency")
        decoded = unquote(parsed.path)
        check(not Path(decoded).is_absolute() and "\\" not in decoded, f"{path.name}: portable relative dependency")
        dependency = (path.parent / decoded).resolve()
        check(dependency.is_relative_to(module.resolve()) and dependency.is_file(), f"{path.name}: GLB dependency stays inside extracted module")
print(f"BLOOM INDEPENDENT ASSETS: {checks} checks PASS; {len(files)} verified WAVs, no clipped samples; no listening or GPU-performance claim")
