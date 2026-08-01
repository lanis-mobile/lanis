#!/usr/bin/env python3
"""Interactive Flutter release build script with optional store uploads."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PACKAGE_NAME = "io.github.alessioc42.sph"
DART_DEFINE_CRONET = "--dart-define=cronetHttpNoPlay=true"
PLAY_TRACKS = ("internal", "alpha", "beta", "production")
IPA_NAME = "Lanis.ipa"
AAB_NAME = "app-release.aab"
DEFAULT_ENV_FILES = (ROOT / ".env", ROOT / ".build.env")

APK_MAP = {
    "app-armeabi-v7a-release.apk": "app-armeabi-v7a-release-selfsigned.apk",
    "app-arm64-v8a-release.apk": "app-arm64-v8a-release-selfsigned.apk",
    "app-x86_64-release.apk": "app-x86_64-release-selfsigned.apk",
}


@dataclass
class Config:
    build_android: bool = False
    build_ios: bool = False
    skip_upgrade: bool = False
    output_dir: Path = field(default_factory=lambda: ROOT / "artifacts")
    skip_confirm: bool = False
    upload_ios: bool | None = None
    upload_android: bool | None = None
    play_track: str = "internal"
    asc_api_key_id: str | None = None
    asc_api_issuer_id: str | None = None
    asc_api_key_path: Path | None = None
    play_service_account_json: Path | None = None


def is_darwin() -> bool:
    return platform.system() == "Darwin"


def is_linux() -> bool:
    return platform.system() == "Linux"


def log(msg: str) -> None:
    print(msg, flush=True)


def _parse_env_line(line: str) -> tuple[str, str] | None:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None
    if stripped.startswith("export "):
        stripped = stripped[len("export ") :].lstrip()
    if "=" not in stripped:
        return None
    key, value = stripped.split("=", 1)
    key = key.strip()
    if not key:
        return None
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    return key, value


def load_env_file(path: Path, *, override: bool = False) -> int:
    """Load KEY=VALUE pairs from a .env file into os.environ.

    Existing environment variables are kept unless override=True.
    Returns the number of keys applied.
    """
    if not path.is_file():
        return 0
    applied = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        parsed = _parse_env_line(line)
        if parsed is None:
            continue
        key, value = parsed
        if not override and key in os.environ:
            continue
        os.environ[key] = value
        applied += 1
    return applied


def load_dotenv_files(extra: Path | None = None) -> None:
    """Load secrets from default and optional .env files (no override of real env)."""
    seen: set[Path] = set()
    loaded_names: list[str] = []
    for path in (*DEFAULT_ENV_FILES, extra):
        if path is None:
            continue
        resolved = path.expanduser().resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        count = load_env_file(resolved, override=False)
        if count:
            loaded_names.append(str(path))
    if loaded_names:
        log(f"Loaded secrets from: {', '.join(loaded_names)}")


def run(cmd: list[str], *, cwd: Path | None = None) -> None:
    log(f">>> {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd or ROOT, check=True)


def prompt_bool(message: str, default: bool) -> bool:
    suffix = "[Y/n]" if default else "[y/N]"
    while True:
        raw = input(f"{message} {suffix} ").strip().lower()
        if not raw:
            return default
        if raw in {"y", "yes"}:
            return True
        if raw in {"n", "no"}:
            return False
        print("Please answer y or n.")


def prompt_str(message: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    raw = input(f"{message}{suffix} ").strip()
    return raw or default


def prompt_choice(message: str, choices: tuple[str, ...], default: str) -> str:
    joined = "/".join(choices)
    while True:
        raw = prompt_str(f"{message} ({joined})", default).lower()
        if raw in choices:
            return raw
        print(f"Choose one of: {joined}")


def resolve_path(value: str | None) -> Path | None:
    if not value:
        return None
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = (Path.cwd() / path).resolve()
    return path


def any_cli_action_flags(args: argparse.Namespace) -> bool:
    return any(
        [
            args.android,
            args.ios,
            args.upload_ios,
            args.upload_android,
            args.skip_upgrade,
            args.output_dir is not None,
            args.yes,
            args.play_track is not None,
            args.asc_api_key_id is not None,
            args.asc_api_issuer_id is not None,
            args.asc_api_key_path is not None,
            args.play_service_account_json is not None,
        ]
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Lanis release artifacts and optionally upload to stores.",
    )
    parser.add_argument("--android", action="store_true", help="Build Android AAB and split APKs")
    parser.add_argument("--ios", action="store_true", help="Build iOS IPA (macOS only)")
    parser.add_argument(
        "--skip-upgrade",
        action="store_true",
        help="Skip flutter pub upgrade --major-versions",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Output directory for artifacts (default: artifacts)",
    )
    parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="Skip confirmation prompts",
    )
    parser.add_argument(
        "--upload-ios",
        action="store_true",
        help="Upload IPA to App Store Connect after build",
    )
    parser.add_argument(
        "--upload-android",
        action="store_true",
        help="Upload AAB to Google Play after build",
    )
    parser.add_argument(
        "--play-track",
        choices=PLAY_TRACKS,
        default=None,
        help="Google Play track (default: internal)",
    )
    parser.add_argument(
        "--asc-api-key-id",
        default=None,
        help="App Store Connect API key ID (or ASC_API_KEY_ID)",
    )
    parser.add_argument(
        "--asc-api-issuer-id",
        default=None,
        help="App Store Connect API issuer ID (or ASC_API_ISSUER_ID)",
    )
    parser.add_argument(
        "--asc-api-key-path",
        default=None,
        help="Path to AuthKey_*.p8 (or ASC_API_KEY_PATH)",
    )
    parser.add_argument(
        "--play-service-account-json",
        default=None,
        help="Path to Play service account JSON (or PLAY_SERVICE_ACCOUNT_JSON)",
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Extra .env file to load (also reads .env and .build.env from repo root)",
    )
    return parser.parse_args(argv)


def config_from_cli(args: argparse.Namespace) -> Config:
    build_android = args.android or args.upload_android
    build_ios = args.ios or args.upload_ios
    if not build_android and not build_ios:
        # Non-interactive with no platform flags: keep old OS defaults.
        if is_darwin():
            build_ios = True
        else:
            build_android = True

    return Config(
        build_android=build_android,
        build_ios=build_ios,
        skip_upgrade=args.skip_upgrade,
        output_dir=resolve_path(args.output_dir) or (ROOT / "artifacts"),
        skip_confirm=args.yes,
        upload_ios=True if args.upload_ios else False,
        upload_android=True if args.upload_android else False,
        play_track=args.play_track or "internal",
        asc_api_key_id=args.asc_api_key_id or os.environ.get("ASC_API_KEY_ID"),
        asc_api_issuer_id=args.asc_api_issuer_id or os.environ.get("ASC_API_ISSUER_ID"),
        asc_api_key_path=resolve_path(
            args.asc_api_key_path or os.environ.get("ASC_API_KEY_PATH")
        ),
        play_service_account_json=resolve_path(
            args.play_service_account_json or os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
        ),
    )


def interactive_config() -> Config:
    default_android = not is_darwin()
    default_ios = is_darwin()

    build_android = prompt_bool("Build Android (AAB + split APKs)?", default_android)
    if is_darwin():
        build_ios = prompt_bool("Build iOS (IPA)?", default_ios)
    else:
        build_ios = False
        log("iOS builds are only available on macOS; skipping.")

    if not build_android and not build_ios:
        log("Nothing selected to build.")
        sys.exit(1)

    skip_upgrade = prompt_bool("Skip flutter pub upgrade --major-versions?", False)
    output_dir = resolve_path(prompt_str("Output directory", "artifacts"))
    assert output_dir is not None

    upload_ios: bool | None = None
    upload_android: bool | None = None
    play_track = "internal"
    asc_api_key_id = os.environ.get("ASC_API_KEY_ID")
    asc_api_issuer_id = os.environ.get("ASC_API_ISSUER_ID")
    asc_api_key_path = resolve_path(os.environ.get("ASC_API_KEY_PATH"))
    play_json = resolve_path(os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"))

    if prompt_bool("Configure store uploads now?", False):
        if build_ios and is_darwin():
            upload_ios = prompt_bool("Upload IPA to App Store Connect after build?", False)
            if upload_ios:
                asc_api_key_id = prompt_str("ASC API key ID", asc_api_key_id or "")
                asc_api_issuer_id = prompt_str(
                    "ASC API issuer ID", asc_api_issuer_id or ""
                )
                asc_api_key_path = resolve_path(
                    prompt_str(
                        "Path to AuthKey_*.p8",
                        str(asc_api_key_path) if asc_api_key_path else "",
                    )
                )
        if build_android:
            upload_android = prompt_bool("Upload AAB to Google Play after build?", False)
            if upload_android:
                play_track = prompt_choice("Play track", PLAY_TRACKS, "internal")
                play_json = resolve_path(
                    prompt_str(
                        "Path to Play service account JSON",
                        str(play_json) if play_json else "",
                    )
                )

    return Config(
        build_android=build_android,
        build_ios=build_ios,
        skip_upgrade=skip_upgrade,
        output_dir=output_dir,
        skip_confirm=False,
        upload_ios=upload_ios,
        upload_android=upload_android,
        play_track=play_track,
        asc_api_key_id=asc_api_key_id or None,
        asc_api_issuer_id=asc_api_issuer_id or None,
        asc_api_key_path=asc_api_key_path,
        play_service_account_json=play_json,
    )


def print_summary(cfg: Config) -> None:
    log("")
    log("Build configuration:")
    log(f"  Android:       {'yes' if cfg.build_android else 'no'}")
    log(f"  iOS:           {'yes' if cfg.build_ios else 'no'}")
    log(f"  Skip upgrade:  {'yes' if cfg.skip_upgrade else 'no'}")
    log(f"  Output dir:    {cfg.output_dir}")
    if cfg.upload_ios is True:
        log("  Upload iOS:    yes (App Store Connect)")
    elif cfg.upload_ios is False:
        log("  Upload iOS:    no")
    else:
        log("  Upload iOS:    ask after build")
    if cfg.upload_android is True:
        log(f"  Upload Android: yes (Play track={cfg.play_track})")
    elif cfg.upload_android is False:
        log("  Upload Android: no")
    else:
        log("  Upload Android: ask after build")
    log("")


def validate_config(cfg: Config) -> None:
    if cfg.build_ios and not is_darwin():
        log("Error: iOS builds are only supported on macOS (Darwin)")
        sys.exit(1)
    if not cfg.build_android and not cfg.build_ios:
        log("Error: select at least one of Android or iOS")
        sys.exit(1)
    if platform.system() not in {"Darwin", "Linux"}:
        log(f"Error: unsupported operating system: {platform.system()}")
        sys.exit(1)
    if cfg.play_track not in PLAY_TRACKS:
        log(f"Error: invalid Play track: {cfg.play_track}")
        sys.exit(1)


def prepare_project(cfg: Config) -> None:
    run(["flutter", "clean"])
    run(["flutter", "pub", "get"])
    if cfg.skip_upgrade:
        log(">>> skipping pub upgrade")
    else:
        run(["flutter", "pub", "upgrade", "--major-versions"])
        run(["flutter", "pub", "outdated"])

    if not cfg.skip_confirm:
        input("Press enter to continue...")

    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    run(["dart", "run", "intl_utils:generate"])


def move_artifact(src: Path, dest: Path) -> None:
    if not src.is_file():
        raise FileNotFoundError(f"Expected build artifact missing: {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    shutil.move(str(src), str(dest))
    log(f"Moved {src.name} -> {dest}")


def build_ios(cfg: Config) -> Path:
    log(">>> build IPA")
    run(["flutter", "build", "ipa"])
    dest = cfg.output_dir / IPA_NAME
    move_artifact(ROOT / "build" / "ios" / "ipa" / IPA_NAME, dest)
    return dest


def build_android(cfg: Config) -> Path:
    log(">>> build appbundle")
    run(["flutter", "build", "appbundle", DART_DEFINE_CRONET])
    aab_dest = cfg.output_dir / AAB_NAME
    move_artifact(
        ROOT / "build" / "app" / "outputs" / "bundle" / "release" / AAB_NAME,
        aab_dest,
    )

    log(">>> build apk")
    run(["flutter", "build", "apk", "--split-per-abi", DART_DEFINE_CRONET])
    apk_dir = ROOT / "build" / "app" / "outputs" / "flutter-apk"
    for src_name, dest_name in APK_MAP.items():
        move_artifact(apk_dir / src_name, cfg.output_dir / dest_name)

    if is_linux():
        subprocess.run(["pkill", "-f", ".GradleDaemon."], check=False)

    return aab_dest


def open_output_dir(path: Path) -> None:
    if is_darwin():
        subprocess.run(["open", str(path)], check=False)
    elif is_linux():
        subprocess.run(["xdg-open", str(path)], check=False)


def ensure_asc_key_installed(key_id: str, key_path: Path) -> Path:
    """altool looks for AuthKey_<KEY_ID>.p8 under ~/.appstoreconnect/private_keys."""
    if not key_path.is_file():
        raise FileNotFoundError(f"ASC API key file not found: {key_path}")

    target_dir = Path.home() / ".appstoreconnect" / "private_keys"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"AuthKey_{key_id}.p8"

    if target.resolve() == key_path.resolve():
        return target

    if target.exists() or target.is_symlink():
        target.unlink()
    try:
        target.symlink_to(key_path.resolve())
    except OSError:
        shutil.copy2(key_path, target)
    return target


def resolve_ios_upload_credentials(cfg: Config) -> tuple[str, str, Path]:
    key_id = cfg.asc_api_key_id or os.environ.get("ASC_API_KEY_ID") or ""
    issuer = cfg.asc_api_issuer_id or os.environ.get("ASC_API_ISSUER_ID") or ""
    key_path = cfg.asc_api_key_path or resolve_path(os.environ.get("ASC_API_KEY_PATH"))

    if not key_id:
        key_id = prompt_str("ASC API key ID")
    if not issuer:
        issuer = prompt_str("ASC API issuer ID")
    if key_path is None:
        key_path = resolve_path(prompt_str("Path to AuthKey_*.p8"))

    if not key_id or not issuer or key_path is None:
        raise ValueError("ASC API key ID, issuer ID, and .p8 path are required")
    return key_id, issuer, key_path


def upload_ios(ipa_path: Path, cfg: Config) -> None:
    if not is_darwin():
        raise RuntimeError("iOS upload requires macOS with Xcode (xcrun altool)")
    if not ipa_path.is_file():
        raise FileNotFoundError(f"IPA not found: {ipa_path}")

    key_id, issuer, key_path = resolve_ios_upload_credentials(cfg)
    ensure_asc_key_installed(key_id, key_path)

    log(">>> upload IPA to App Store Connect (altool)")
    run(
        [
            "xcrun",
            "altool",
            "--upload-app",
            "-f",
            str(ipa_path),
            "-t",
            "ios",
            "--apiKey",
            key_id,
            "--apiIssuer",
            issuer,
        ]
    )
    log("IPA uploaded. Processing in App Store Connect may take a few minutes.")


def resolve_play_credentials(cfg: Config) -> Path:
    path = cfg.play_service_account_json or resolve_path(
        os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
    )
    if path is None:
        path = resolve_path(prompt_str("Path to Play service account JSON"))
    if path is None or not path.is_file():
        raise FileNotFoundError(f"Play service account JSON not found: {path}")
    return path


def upload_android(aab_path: Path, cfg: Config) -> None:
    if not aab_path.is_file():
        raise FileNotFoundError(f"AAB not found: {aab_path}")

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError as exc:
        raise RuntimeError(
            "Play upload requires: pip install -r requirements-build.txt"
        ) from exc

    json_path = resolve_play_credentials(cfg)
    track = cfg.play_track
    status = "draft" if track == "production" else "completed"
    log(f">>> upload AAB to Google Play (track={track}, status={status})")

    credentials = service_account.Credentials.from_service_account_file(
        str(json_path),
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    service = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)

    edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    try:
        media = MediaFileUpload(
            str(aab_path),
            mimetype="application/octet-stream",
            resumable=True,
        )
        bundle = (
            service.edits()
            .bundles()
            .upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                media_body=media,
            )
            .execute()
        )
        version_code = bundle["versionCode"]
        log(f"Uploaded versionCode {version_code}")

        service.edits().tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track=track,
            body={
                "releases": [
                    {
                        "versionCodes": [str(version_code)],
                        "status": status,
                    }
                ]
            },
        ).execute()

        service.edits().commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
        log(f"Play edit committed on track '{track}' (status={status}).")
    except Exception:
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        except Exception:
            pass
        raise


def maybe_upload(
    cfg: Config,
    *,
    ipa_path: Path | None,
    aab_path: Path | None,
) -> None:
    do_ios = cfg.upload_ios
    do_android = cfg.upload_android

    if do_ios is None and ipa_path is not None and is_darwin() and sys.stdin.isatty():
        do_ios = prompt_bool("Upload IPA to App Store Connect?", False)
    if do_android is None and aab_path is not None and sys.stdin.isatty():
        do_android = prompt_bool("Upload AAB to Google Play?", False)
        if do_android:
            cfg.play_track = prompt_choice("Play track", PLAY_TRACKS, cfg.play_track)

    if do_ios and ipa_path is not None:
        upload_ios(ipa_path, cfg)
    if do_android and aab_path is not None:
        upload_android(aab_path, cfg)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    load_dotenv_files(resolve_path(args.env_file) if args.env_file else None)
    if any_cli_action_flags(args):
        cfg = config_from_cli(args)
    else:
        cfg = interactive_config()

    validate_config(cfg)
    print_summary(cfg)

    if not cfg.skip_confirm:
        if not prompt_bool("Proceed with build?", True):
            log("Aborted.")
            return 1

    prepare_project(cfg)

    ipa_path: Path | None = None
    aab_path: Path | None = None

    if cfg.build_ios:
        log("Building App Store IPA")
        ipa_path = build_ios(cfg)

    if cfg.build_android:
        log("Building Android APK and AAB files")
        aab_path = build_android(cfg)

    maybe_upload(cfg, ipa_path=ipa_path, aab_path=aab_path)

    if cfg.build_ios or cfg.build_android:
        open_output_dir(cfg.output_dir)

    log("done.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        raise SystemExit(130)
    except subprocess.CalledProcessError as exc:
        print(f"Command failed with exit code {exc.returncode}", file=sys.stderr)
        raise SystemExit(exc.returncode)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
