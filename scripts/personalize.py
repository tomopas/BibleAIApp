"""Personalize Bible AI for your church or organization (White-Label Fork Tool).

This script allows churches and ministries to customize:
  - Bible / App display name (e.g., "Grace Bible")
  - Church / Organization name & tagline
  - Custom welcome message on first launch
  - Church website, contact email, and worship service times/location
  - Custom app icon & church logo across Android, Web/PWA, and Windows
  - Custom church banner image for home header

The default Bible AI configuration and icons can be restored at any time with:
    python scripts/personalize.py --reset

Usage:
  Interactive wizard:
    python scripts/personalize.py

  From a config JSON file:
    python scripts/personalize.py --config church_config.json

  Via command line flags:
    python scripts/personalize.py --name "Grace Bible" --org "Grace Church" --website "https://gracechurch.org"

  Reset back to original Bible AI defaults:
    python scripts/personalize.py --reset
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

DEFAULT_BRANDING: dict[str, str] = {
    "appName": "Bible AI",
    "shortName": "Bible AI",
    "tagline": "Offline-first Bible reader with AI study perspectives and audio",
    "organizationName": "",
    "welcomeTitle": "Welcome to Bible AI",
    "welcomeMessage": "Read offline, save your own study notes, and explore interpretations from several traditions.",
    "websiteUrl": "",
    "contactEmail": "",
    "churchServiceInfo": "",
    "logoAsset": "assets/icon/app_icon.png",
    "bannerAsset": "",
}


def _update_file(path: Path, pattern: str, replacement: str) -> bool:
    """Helper to do regex replacement in a text file preserving line endings."""
    if not path.exists():
        return False
    raw_bytes = path.read_bytes()
    newline = "\r\n" if b"\r\n" in raw_bytes else "\n"
    content = raw_bytes.decode("utf-8")
    new_content, count = re.subn(pattern, replacement, content)
    if count > 0 and new_content != content:
        normalized = new_content.replace("\r\n", "\n").replace("\n", newline)
        path.write_bytes(normalized.encode("utf-8"))
        return True
    return False


def apply_branding_to_codebase(branding: dict[str, Any], dry_run: bool = False) -> list[str]:
    """Updates Android manifest, Web HTML/manifests, and assets/branding.json."""
    changed = []
    app_name = branding.get("appName", "Bible AI")
    short_name = branding.get("shortName") or app_name

    # 1. assets/branding.json
    branding_file = ROOT / "assets" / "branding.json"
    if not dry_run:
        branding_file.parent.mkdir(parents=True, exist_ok=True)
        branding_file.write_text(json.dumps(branding, indent=2) + "\n", encoding="utf-8", newline="\n")
    changed.append("assets/branding.json")

    # 2. Android Manifest app label
    android_manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if android_manifest.exists():
        if not dry_run:
            _update_file(
                android_manifest,
                r'android:label="[^"]*"',
                f'android:label="{app_name}"',
            )
        changed.append("android/app/src/main/AndroidManifest.xml")

    # 3. backend/static/index.html
    backend_html = ROOT / "backend" / "static" / "index.html"
    if backend_html.exists():
        if not dry_run:
            _update_file(
                backend_html,
                r"<title>[^<]*</title>",
                f"<title>{app_name} — Scripture Reader, AI Study Perspectives &amp; Audio</title>",
            )
            _update_file(
                backend_html,
                r'<span class="brand-title">[^<]*</span>',
                f'<span class="brand-title">{app_name}</span>',
            )
            _update_file(
                backend_html,
                r'title="[^"]* Home"',
                f'title="{app_name} Home"',
            )
            _update_file(
                backend_html,
                r'alt="[^"]*"\s+class="brand-logo-img"',
                f'alt="{app_name}" class="brand-logo-img"',
            )
        changed.append("backend/static/index.html")

    # 4. backend/static/manifest.json
    backend_manifest = ROOT / "backend" / "static" / "manifest.json"
    if backend_manifest.exists():
        if not dry_run:
            try:
                m_data = json.loads(backend_manifest.read_text(encoding="utf-8"))
                m_data["name"] = f"{app_name} — Scripture Reader & Study Perspectives"
                m_data["short_name"] = short_name
                backend_manifest.write_text(
                    json.dumps(m_data, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                    newline="\n",
                )
            except Exception as e:
                print(f"Warning updating backend manifest: {e}", file=sys.stderr)
        changed.append("backend/static/manifest.json")

    # 5. web/index.html
    web_html = ROOT / "web" / "index.html"
    if web_html.exists():
        if not dry_run:
            _update_file(
                web_html,
                r"<title>[^<]*</title>",
                f"<title>{app_name}</title>",
            )
            _update_file(
                web_html,
                r'<meta name="apple-mobile-web-app-title" content="[^"]*">',
                f'<meta name="apple-mobile-web-app-title" content="{short_name}">',
            )
        changed.append("web/index.html")

    # 6. web/manifest.json
    web_manifest = ROOT / "web" / "manifest.json"
    if web_manifest.exists():
        if not dry_run:
            try:
                wm_data = json.loads(web_manifest.read_text(encoding="utf-8"))
                wm_data["name"] = app_name
                wm_data["short_name"] = short_name
                web_manifest.write_text(
                    json.dumps(wm_data, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                    newline="\n",
                )
            except Exception as e:
                print(f"Warning updating web manifest: {e}", file=sys.stderr)
        changed.append("web/manifest.json")

    return changed


def process_custom_icon(icon_path: Path, dry_run: bool = False) -> None:
    """Processes a custom church icon or logo and outputs all Android, Web, and desktop sizes."""
    if not icon_path.exists():
        raise FileNotFoundError(f"Icon file not found: {icon_path}")

    print(f"Processing church icon: {icon_path}")
    with Image.open(icon_path) as src_img:
        master = src_img.convert("RGBA")

        # Create padded maskable version (adds 12% padding for adaptive launcher circles)
        w, h = master.size
        dim = max(w, h)
        square = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
        square.paste(master, ((dim - w) // 2, (dim - h) // 2))

        pad = int(dim * 0.12)
        maskable_size = dim + pad * 2
        master_maskable = Image.new("RGBA", (maskable_size, maskable_size), (0, 0, 0, 0))
        master_maskable.paste(square, (pad, pad))

        targets: list[tuple[Path, int, bool]] = [
            (ROOT / "assets" / "icon" / "app_icon.png", 512, False),
            (ROOT / "backend" / "static" / "favicon.png", 64, False),
            (ROOT / "backend" / "static" / "icon-192.png", 192, False),
            (ROOT / "backend" / "static" / "icon-512.png", 512, False),
            (ROOT / "backend" / "static" / "icon-maskable-512.png", 512, True),
            (ROOT / "web" / "favicon.png", 64, False),
            (ROOT / "web" / "icons" / "Icon-192.png", 192, False),
            (ROOT / "web" / "icons" / "Icon-512.png", 512, False),
            (ROOT / "web" / "icons" / "Icon-maskable-192.png", 192, True),
            (ROOT / "web" / "icons" / "Icon-maskable-512.png", 512, True),
            (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi" / "ic_launcher.png", 48, False),
            (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi" / "ic_launcher.png", 72, False),
            (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi" / "ic_launcher.png", 96, False),
            (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi" / "ic_launcher.png", 144, False),
            (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png", 192, False),
        ]

        if not dry_run:
            for path, px, is_mask in targets:
                path.parent.mkdir(parents=True, exist_ok=True)
                img = master_maskable if is_mask else master
                resized = img.resize((px, px), Image.Resampling.LANCZOS)
                resized.save(path, format="PNG", optimize=True)

            win_ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
            if win_ico.parent.exists():
                ico_base = master.resize((256, 256), Image.Resampling.LANCZOS)
                ico_base.save(
                    win_ico,
                    format="ICO",
                    sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
                )

    print("Successfully generated all app and launcher icons.")


def process_custom_banner(banner_path: Path, dry_run: bool = False) -> str:
    """Processes and copies a custom church banner to assets/images/church_banner.png."""
    if not banner_path.exists():
        raise FileNotFoundError(f"Banner file not found: {banner_path}")

    dest = ROOT / "assets" / "images" / "church_banner.png"
    if not dry_run:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(banner_path) as img:
            # Resize wide banner to max width 1200 maintaining aspect ratio
            max_w = 1200
            w, h = img.size
            if w > max_w:
                new_h = int(h * (max_w / w))
                img = img.resize((max_w, new_h), Image.Resampling.LANCZOS)
            img.convert("RGB").save(dest, format="PNG", optimize=True)
    print(f"Church banner saved to {dest.relative_to(ROOT)}")
    return "assets/images/church_banner.png"


def reset_to_defaults(dry_run: bool = False) -> None:
    """Resets all configuration, Android manifests, Web HTML, and icons back to default Bible AI."""
    print("Resetting all settings to standard Bible AI defaults...")

    # 1. Apply default branding
    apply_branding_to_codebase(DEFAULT_BRANDING, dry_run=dry_run)

    # 2. Remove church banner if present
    church_banner = ROOT / "assets" / "images" / "church_banner.png"
    if church_banner.exists() and not dry_run:
        try:
            church_banner.unlink()
            print("Removed custom church banner.")
        except Exception as e:
            print(f"Notice: Could not remove banner: {e}")

    # 3. Regenerate standard Bible AI icons
    if not dry_run:
        try:
            if str(ROOT / "scripts") not in sys.path:
                sys.path.insert(0, str(ROOT / "scripts"))
            import generate_app_icons
            generate_app_icons.main()
            print("Regenerated official Bible AI app icons.")
        except Exception as e:
            print(f"Warning: could not regenerate default icons automatically: {e}")

    print("\nBible AI is now reset to standard defaults.")


def prompt_user_interactive() -> dict[str, Any]:
    """Runs an interactive questionnaire for church admins."""
    print("=" * 60)
    print("🏛️  Bible AI — Church & Fork Personalization Setup")
    print("=" * 60)
    print("Press Enter to keep the default or suggested value.\n")

    def ask(prompt: str, default: str = "") -> str:
        suffix = f" [{default}]" if default else ""
        try:
            val = input(f"{prompt}{suffix}: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nSetup cancelled.")
            sys.exit(0)
        return val if val else default

    app_name = ask("1. Bible / App Name", "Bible AI")
    short_name = ask("2. Short App Name (for mobile header)", app_name)
    org_name = ask("3. Church or Organization Name", "")
    tagline = ask(
        "4. Subtitle or Tagline",
        "Growing in faith and scripture" if org_name else DEFAULT_BRANDING["tagline"],
    )
    welcome_title = ask("5. Welcome Banner Title", f"Welcome to {app_name}")
    welcome_msg = ask(
        "6. Welcome Message",
        f"Read God's Word with {org_name}, study offline, and explore deep scripture insights."
        if org_name
        else DEFAULT_BRANDING["welcomeMessage"],
    )
    website = ask("7. Church Website URL (e.g. https://gracechurch.org)", "")
    email = ask("8. Church Contact Email", "")
    service_info = ask("9. Worship Times / Location (e.g. Sundays 10 AM | Main Hall)", "")
    icon_input = ask("10. Path to custom icon/logo image (leave blank to keep current)", "")
    banner_input = ask("11. Path to custom church banner/photo (leave blank if none)", "")

    data: dict[str, Any] = {
        "appName": app_name,
        "shortName": short_name,
        "tagline": tagline,
        "organizationName": org_name,
        "welcomeTitle": welcome_title,
        "welcomeMessage": welcome_msg,
        "websiteUrl": website,
        "contactEmail": email,
        "churchServiceInfo": service_info,
        "logoAsset": "assets/icon/app_icon.png",
        "bannerAsset": "",
    }
    if icon_input:
        data["iconPath"] = icon_input
    if banner_input:
        data["bannerPath"] = banner_input

    return data


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Personalize Bible AI for your church or ministry fork.",
    )
    parser.add_argument("--config", type=str, help="Path to church_config.json file")
    parser.add_argument("--reset", action="store_true", help="Reset all settings and icons to Bible AI defaults")
    parser.add_argument("--name", type=str, help="Bible / App Name (e.g. 'Grace Bible')")
    parser.add_argument("--short-name", type=str, help="Short app name")
    parser.add_argument("--org", type=str, help="Church or Organization name")
    parser.add_argument("--tagline", type=str, help="App or church tagline")
    parser.add_argument("--welcome-title", type=str, help="Welcome card headline")
    parser.add_argument("--welcome-message", type=str, help="Welcome card description")
    parser.add_argument("--website", type=str, help="Church website URL")
    parser.add_argument("--email", type=str, help="Church contact email")
    parser.add_argument("--service-info", type=str, help="Service times and location")
    parser.add_argument("--icon", type=str, help="Path to custom icon image (PNG/JPG)")
    parser.add_argument("--banner", type=str, help="Path to custom church banner/photo (PNG/JPG)")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing files")

    args = parser.parse_args()

    if args.reset:
        reset_to_defaults(dry_run=args.dry_run)
        return

    # Check whether any explicit flag or config is passed
    has_flags = any([
        args.config,
        args.name,
        args.org,
        args.website,
        args.email,
        args.service_info,
        args.icon,
        args.banner,
    ])

    config_data: dict[str, Any] = {}

    if args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"Error: Config file not found: {config_path}", file=sys.stderr)
            sys.exit(1)
        config_data = json.loads(config_path.read_text(encoding="utf-8"))
    elif not has_flags:
        # No arguments passed: run interactive mode
        config_data = prompt_user_interactive()

    # CLI flag overrides
    if args.name:
        config_data["appName"] = args.name
    if args.short_name:
        config_data["shortName"] = args.short_name
    if args.org:
        config_data["organizationName"] = args.org
    if args.tagline:
        config_data["tagline"] = args.tagline
    if args.welcome_title:
        config_data["welcomeTitle"] = args.welcome_title
    if args.welcome_message:
        config_data["welcomeMessage"] = args.welcome_message
    if args.website:
        config_data["websiteUrl"] = args.website
    if args.email:
        config_data["contactEmail"] = args.email
    if args.service_info:
        config_data["churchServiceInfo"] = args.service_info
    if args.icon:
        config_data["iconPath"] = args.icon
    if args.banner:
        config_data["bannerPath"] = args.banner

    # Ensure required fields have fallbacks
    branding: dict[str, Any] = {**DEFAULT_BRANDING}
    for k, v in config_data.items():
        if k not in ["iconPath", "bannerPath"]:
            branding[k] = v

    if not branding.get("shortName"):
        branding["shortName"] = branding.get("appName", "Bible AI")

    print("\n" + "=" * 60)
    print(f"Applying personalization for: {branding.get('appName')} ({branding.get('organizationName') or 'Personal'})")
    print("=" * 60)

    # Process custom icon if provided
    icon_source = config_data.get("iconPath")
    if icon_source:
        icon_file = Path(icon_source)
        process_custom_icon(icon_file, dry_run=args.dry_run)
        branding["logoAsset"] = "assets/icon/app_icon.png"

    # Process custom banner if provided
    banner_source = config_data.get("bannerPath")
    if banner_source:
        banner_file = Path(banner_source)
        banner_asset = process_custom_banner(banner_file, dry_run=args.dry_run)
        branding["bannerAsset"] = banner_asset

    # Apply configuration to codebase
    updated_files = apply_branding_to_codebase(branding, dry_run=args.dry_run)

    print("\nPersonalization successfully applied to:")
    for f in updated_files:
        print(f"  • {f}")

    print("\nNext steps:")
    print("  1. Run `flutter run` or `flutter build apk` to test your personalized build.")
    print("  2. To revert to official Bible AI defaults anytime, run:")
    print("     python scripts/personalize.py --reset\n")


if __name__ == "__main__":
    main()
