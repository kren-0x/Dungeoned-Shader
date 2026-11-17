#!/usr/bin/env python3
"""
Dungeoned-Shader Resource Pack Generator
Packages compiled shaders into Minecraft Bedrock resource packs (.mcpack and folder)
for Windows, Android, and iOS with newb fog detection and auto-versioning.
"""

import os
import sys
import json
import uuid
import shutil
import zipfile
import argparse

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(ROOT_DIR, "build")
ASSETS_DIR = os.path.join(ROOT_DIR, "assets")
MATERIALS_DIR = os.path.join(ROOT_DIR, "materials")
TOOLS_DIR = os.path.join(ROOT_DIR, "tools")
VERSION_FILE = os.path.join(ROOT_DIR, "version.json")

SUPPORTED_PLATFORMS = ["windows", "android", "ios"]

UUID_NAMESPACE = uuid.UUID("1b80c57d-bb16-402b-85a0-69bdfab5dbcf")


def get_version(args_version=None, bump_patch=False):
    version = [1, 0, 0]
    if os.path.exists(VERSION_FILE):
        try:
            with open(VERSION_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and "version" in data:
                    version = data["version"]
                elif isinstance(data, list) and len(data) >= 2:
                    version = [int(x) for x in data[:3]]
                    while len(version) < 3:
                        version.append(0)
        except Exception:
            version = [1, 0, 0]

    if args_version:
        parts = [int(p) for p in args_version.replace("v", "").split(".") if p.isdigit()]
        while len(parts) < 3:
            parts.append(0)
        version = parts[:3]
    elif bump_patch:
        version[2] += 1

    try:
        with open(VERSION_FILE, "w", encoding="utf-8") as f:
            json.dump({"version": version}, f, indent=2)
    except Exception:
        pass

    return version


def ensure_asset_fogs():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    biomes_dir = os.path.join(ASSETS_DIR, "biomes")
    fogs_dir = os.path.join(ASSETS_DIR, "fogs")
    os.makedirs(biomes_dir, exist_ok=True)
    os.makedirs(fogs_dir, exist_ok=True)

    client_biomes_path = os.path.join(ASSETS_DIR, "biomes_client.json")
    if not os.path.exists(client_biomes_path):
        client_biomes_data = {
            "biomes": {
                "default": {
                    "water_surface_transparency": 0.65
                },
                "swampland": {
                    "water_surface_transparency": 0.94
                },
                "swampland_mutated": {
                    "water_surface_transparency": 0.94
                },
                "the_end": {
                    "fog_identifier": "dungeoned:fog_end"
                }
            }
        }
        with open(client_biomes_path, "w", encoding="utf-8") as f:
            json.dump(client_biomes_data, f, indent=2)

    the_end_biome_path = os.path.join(biomes_dir, "the_end.client_biome.json")
    if not os.path.exists(the_end_biome_path):
        the_end_biome_data = {
            "format_version": "1.21.40",
            "minecraft:client_biome": {
                "description": {
                    "identifier": "the_end"
                },
                "components": {
                    "minecraft:fog_appearance": {
                        "fog_identifier": "dungeoned:fog_end"
                    }
                }
            }
        }
        with open(the_end_biome_path, "w", encoding="utf-8") as f:
            json.dump(the_end_biome_data, f, indent=2)

    the_end_fog_path = os.path.join(fogs_dir, "the_end_fog_setting.json")
    if not os.path.exists(the_end_fog_path):
        the_end_fog_data = {
            "format_version": "1.16.100",
            "minecraft:fog_settings": {
                "description": {
                    "identifier": "dungeoned:fog_end"
                },
                "distance": {
                    "air": {
                        "fog_start": 0.92,
                        "fog_end": 1.0,
                        "fog_color": "#400040",
                        "render_distance_type": "render"
                    },
                    "water": {
                        "fog_start": 0.0,
                        "fog_end": 15.0,
                        "fog_color": "#62529e",
                        "render_distance_type": "fixed"
                    }
                }
            }
        }
        with open(the_end_fog_path, "w", encoding="utf-8") as f:
            json.dump(the_end_fog_data, f, indent=2)



def get_required_materials():
    if not os.path.isdir(MATERIALS_DIR):
        return []
    return [
        d for d in sorted(os.listdir(MATERIALS_DIR))
        if os.path.isdir(os.path.join(MATERIALS_DIR, d)) and not d.startswith((".", "_"))
    ]


def ensure_compiled_materials(target_platform, force_rebuild=False):
    built_dir = os.path.join(BUILD_DIR, target_platform)
    req_mats = get_required_materials()

    missing = []
    if not force_rebuild and os.path.isdir(built_dir):
        for m in req_mats:
            bin_file = os.path.join(built_dir, f"{m}.material.bin")
            if not os.path.exists(bin_file):
                missing.append(m)
    else:
        missing = req_mats

    if missing or force_rebuild:
        print(f" [Pack] Compiling {len(missing)} missing material(s) for {target_platform}...")
        sys.path.insert(0, TOOLS_DIR)
        import build as shader_builder
        success = shader_builder.build_materials(target_platform, jobs=1, force=force_rebuild)
        if not success:
            raise RuntimeError(f"Failed to build materials for {target_platform}")

    return built_dir


def create_manifest(target_platform, version):
    header_uuid = str(uuid.uuid5(UUID_NAMESPACE, f"header-{target_platform}"))
    module_uuid = str(uuid.uuid5(UUID_NAMESPACE, f"module-{target_platform}"))

    ver_str = f"{version[0]}.{version[1]}"
    if version[2] > 0:
        ver_str += f".{version[2]}"

    plat_title = target_platform.capitalize()
    if target_platform == "ios":
        plat_title = "iOS"

    manifest = {
        "format_version": 2,
        "header": {
            "name": f"Dungeoned Shader {plat_title}",
            "description": f"Dungeoned Shader v{ver_str} for {plat_title}. Created by Ken Radithya.",
            "uuid": header_uuid,
            "version": version,
            "min_engine_version": [1, 20, 0]
        },
        "modules": [
            {
                "type": "resources",
                "uuid": module_uuid,
                "version": version
            }
        ],
        "metadata": {
            "authors": [
                "Ken Radithya"
            ]
        }
    }
    return manifest


def pack_platform(target_platform, version, force_rebuild=False, make_mcpack=True):
    ensure_asset_fogs()
    built_dir = ensure_compiled_materials(target_platform, force_rebuild=force_rebuild)

    pack_dir_name = f"pack-{target_platform}"
    pack_dir = os.path.join(ROOT_DIR, pack_dir_name)

    if os.path.exists(pack_dir):
        shutil.rmtree(pack_dir)
    os.makedirs(pack_dir, exist_ok=True)

    dest_mats_dir = os.path.join(pack_dir, "renderer", "materials")
    os.makedirs(dest_mats_dir, exist_ok=True)

    req_mats = get_required_materials()
    copied_count = 0
    for m in req_mats:
        bin_src = os.path.join(built_dir, f"{m}.material.bin")
        if os.path.exists(bin_src):
            shutil.copyfile(bin_src, os.path.join(dest_mats_dir, f"{m}.material.bin"))
            copied_count += 1
        else:
            print(f" Warning: missing {m}.material.bin in {built_dir}")

    for root, dirs, files in os.walk(ASSETS_DIR):
        rel = os.path.relpath(root, ASSETS_DIR)
        target_root = pack_dir if rel == "." else os.path.join(pack_dir, rel)
        os.makedirs(target_root, exist_ok=True)
        for f in files:
            shutil.copyfile(os.path.join(root, f), os.path.join(target_root, f))

    manifest_data = create_manifest(target_platform, version)
    manifest_path = os.path.join(pack_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest_data, f, indent=2)

    ver_str = f"{version[0]}.{version[1]}"
    if version[2] > 0:
        ver_str += f".{version[2]}"

    print(f"\n [Pack] Successfully created folder: {pack_dir_name}/")
    print(f"        Materials: {copied_count} in {pack_dir_name}/renderer/materials/")
    print(f"        Fog detection: dungeoned:fog_end configured in biomes & fogs")
    print(f"        Version: {ver_str} ({version})")

    if make_mcpack:
        mcpack_name = f"{pack_dir_name}-v{ver_str}.mcpack"
        mcpack_path = os.path.join(ROOT_DIR, mcpack_name)
        if os.path.exists(mcpack_path):
            os.remove(mcpack_path)

        with zipfile.ZipFile(mcpack_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(pack_dir):
                for f in files:
                    full_p = os.path.join(root, f)
                    arc_p = os.path.relpath(full_p, pack_dir)
                    zf.write(full_p, arc_p)

        print(f"        Package: {mcpack_name}")

    return pack_dir


def main():
    parser = argparse.ArgumentParser(description="Package Dungeoned Shader for Windows, Android, and iOS")
    parser.add_argument("platform", nargs="?", default=None, help="Target platform: windows, android, ios, or all")
    parser.add_argument("-v", "--version", default=None, help="Set version string (e.g. 1.0 or 1.0.1)")
    parser.add_argument("-b", "--bump", action="store_true", help="Auto-bump patch version")
    parser.add_argument("-r", "--rebuild", action="store_true", help="Force rebuild of materials")
    parser.add_argument("--no-zip", action="store_true", help="Do not create .mcpack zip file")

    args = parser.parse_args()

    version = get_version(args.version, bump_patch=args.bump)

    target = args.platform
    if not target:
        print("\n === Dungeoned Shader Pack Builder ===")
        print(" [1] windows")
        print(" [2] android")
        print(" [3] ios")
        print(" [4] all (windows, android, ios)")
        print(f" Current Version: {version[0]}.{version[1]}.{version[2]}")
        try:
            choice = input("\n Select platform [1]: ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print()
            return

        choice_map = {
            "": "windows",
            "1": "windows",
            "2": "android",
            "3": "ios",
            "4": "all",
            "w": "windows",
            "windows": "windows",
            "a": "android",
            "android": "android",
            "i": "ios",
            "ios": "ios",
            "all": "all"
        }
        target = choice_map.get(choice, "windows")

    targets = SUPPORTED_PLATFORMS if target in ("all", "all-plat", "*") else [target.lower()]

    for plat in targets:
        if plat not in SUPPORTED_PLATFORMS:
            print(f" Error: Unsupported platform '{plat}'. Only windows, android, and ios are supported.")
            sys.exit(1)
        pack_platform(plat, version, force_rebuild=args.rebuild, make_mcpack=not args.no_zip)

    print("\n [Pack] All requested packages generated successfully.")


if __name__ == "__main__":
    main()
