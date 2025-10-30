#!python3

"""
Usage:
build.py [web|mac|all] [public|test|all] [--deploy]
"""

import argparse
from datetime import date
from itertools import product
import os
import subprocess
import sys
from typing import Literal
import yaml
from tempfile import TemporaryDirectory

TARGETS: list[Literal["web", "mac"]] = []
ENVS: list[Literal["public", "test"]] = []
DEPLOY: bool = False
NIGHTLY: str = ""

BOLD = "\033[1m"
RESET = "\033[0m"
GREEN = "\033[32m"
YELLOW = "\033[33m"

try:
    config: dict = yaml.safe_load(open("build_config.yaml"))
except FileNotFoundError:
    print("No build_config.yaml found, unable to deploy")
    config = {}


def print_highlight(message: str):
    print(f"{BOLD}{YELLOW}==== {message} ===={RESET}")


def run_command(*command: str, **kwargs):
    joined = " ".join(command)
    print(f"{BOLD}{GREEN}${RESET} {BOLD}{joined}{RESET}")
    return subprocess.run(command, check=True, **kwargs)


def send_file(path: str, destination: str):
    run_command(
        "rsync",
        "-azq",
        path,
        destination,
    )


def write_remote_file(filename: str, destination: str, content: str | bytes):
    if isinstance(content, str):
        content = content.encode()
    with TemporaryDirectory() as tempDir:
        tempPath = os.path.join(tempDir, filename)
        with open(tempPath, "wb") as f:
            f.write(content)
        send_file(tempPath, destination)


def parse_args():
    global TARGETS, ENVS, DEPLOY, NIGHTLY

    parser = argparse.ArgumentParser(
        prog="build.py",
        description="Build helper. Parses target, environment and deploy flag.",
        add_help=True,
    )

    parser.add_argument(
        "target",
        nargs="?",
        default="all",
        choices=["web", "mac", "all"],
        help="Build target: web, mac, or all (default: all)",
    )
    parser.add_argument(
        "environment",
        nargs="?",
        default="all",
        choices=["public", "test", "all"],
        help="Build environment: public, test, or all (default: all)",
    )
    parser.add_argument(
        "--deploy",
        action="store_true",
        help="If set, indicates deployment should be performed after build.",
    )
    parser.add_argument(
        "--nightly",
        action="store_true",
        help="Add nightly flag",
    )

    args = parser.parse_args()

    if args.target == "all":
        TARGETS = ["web", "mac"]
    else:
        TARGETS = [args.target]

    if args.environment == "all":
        ENVS = ["public", "test"]
    else:
        ENVS = [args.environment]

    DEPLOY = bool(args.deploy)

    if args.nightly:
        NIGHTLY = "-nightly"


def pack_directory_to_zip(src_dir: str, dest_zip_path: str) -> None:
    """Pack a directory into a zip at target location using DEFLATE."""
    src_dir = os.path.abspath(src_dir)
    dest_zip_path = os.path.abspath(dest_zip_path)

    # Ensure destination directory exists
    parent = os.path.dirname(dest_zip_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    # Remove existing archive to avoid incremental update behavior of `zip`
    if os.path.exists(dest_zip_path):
        os.remove(dest_zip_path)

    root_name = os.path.basename(os.path.normpath(src_dir))
    cwd = os.path.dirname(src_dir)

    # Use system `zip` for speed, recursively adding the root directory.
    # Preserve symlinks (like Finder's Compress) and exclude macOS metadata files.
    run_command(
        "zip",
        "-r",  # recurse into directories
        "-q",  # quiet output
        "-y",  # store symlinks as links (do not dereference)
        "-6",  # compression level
        dest_zip_path,
        root_name,
        "-x",  # exclude the following patterns
        "*.DS_Store",  # macOS Finder metadata files (top-level)
        "*/.DS_Store",  # macOS Finder metadata files (nested)
        "._*",  # AppleDouble resource forks (top-level)
        "*/._*",  # AppleDouble resource forks (nested)
        cwd=cwd,
    )


def format_dart_flags(flags: dict[str, str]):
    return (f"--dart-define={k}={v}" for k, v in flags.items())


def format_rsync_exclude(exclusion: list[str]):
    for name in exclusion:
        yield "--exclude"
        yield name


if __name__ == "__main__":
    parse_args()

    date_str = date.today().strftime("%Y.%m.%d")

    for target, env in product(TARGETS, ENVS):
        version = f"dataview-{target}-{env}-{date_str}{NIGHTLY}"
        print_highlight(f"building {version}")
        env_args = {"BUILD_DATE": date_str, "VERSION_NAME": version} | config[
            "dart_define"
        ][env]
        if env == "test":
            env_args["TEST_FEATURES"] = "true"
        match target:
            case "mac":
                if sys.platform != "darwin":
                    print_highlight("Not on macOS platform, skipping build")
                    break
                run_command(
                    "flutter",
                    "build",
                    "macos",
                    "--release",
                    *format_dart_flags(env_args),
                )
                zipName = f"build/{version}.zip"
                pack_directory_to_zip(
                    "build/macos/Build/Products/Release/DataView.app",
                    zipName,
                )
                if DEPLOY:
                    print_highlight(f"sending public files")
                    send_file(zipName, config["public_dir"][env])
                    if not NIGHTLY:
                        write_remote_file("latest", config["public_dir"][env], date_str)
            case "web":
                base = config["base"][env]
                if base != "/":
                    base = f"/{base.strip("/")}/"
                run_command(
                    "flutter",
                    "build",
                    "web",
                    "--release",
                    "--wasm",
                    "--source-maps",
                    *format_dart_flags(env_args),
                    "--base-href",
                    base,
                )
                zipName = f"build/{version}.zip"
                pack_directory_to_zip(
                    "build/web",
                    zipName,
                )
                if DEPLOY:
                    print_highlight(f"deploying {version}")
                    run_command(
                        "rsync",
                        "-azqP",
                        "--delete",
                        "--exclude",
                        "**/.DS_Store",
                        "--exclude",
                        "**/._*",
                        "--exclude",
                        "/public",
                        "build/web/",
                        config["deploy_path"][env],
                    )
                    print_highlight(f"sending public files")
                    send_file(zipName, config["public_dir"][env])
                    if not NIGHTLY:
                        write_remote_file("latest", config["public_dir"][env], date_str)
