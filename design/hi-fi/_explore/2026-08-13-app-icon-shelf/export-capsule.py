#!/usr/bin/env python3
"""从 04 Capsule 主稿导出品牌 / iOS / 网站所需尺寸并落盘。"""

from pathlib import Path
from PIL import Image
import shutil

ROOT = Path("/Users/yihang/Documents/Projects/Routeva")
BATCH = ROOT / "design/hi-fi/_explore/2026-08-13-app-icon-shelf"
MASTER_PNG = BATCH / "assets/04-capsule.png"
MASTER_SVG = BATCH / "assets/04-capsule.svg"

master = Image.open(MASTER_PNG).convert("RGB")
if master.size != (1024, 1024):
    raise SystemExit(f"master must be 1024 RGB, got {master.size} {master.mode}")


def png(size: int, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    img = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
    img.convert("RGB").save(dest, "PNG", optimize=True)


def jpg(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    master.save(dest, "JPEG", quality=92, optimize=True, subsampling=0)


# --- 品牌真源 ---
brand = ROOT / "design/brand/app-icon"
png(1024, brand / "AppIcon-1024.png")
jpg(brand / "AppIcon-1024.jpg")
png(180, brand / "AppIcon-180.png")
png(120, brand / "AppIcon-120.png")
png(60, brand / "AppIcon-60.png")
shutil.copyfile(MASTER_SVG, brand / "AppIcon.svg")

# --- 探索归档 ---
approved = BATCH / "approved"
png(1024, approved / "AppIcon-1024.png")
jpg(approved / "AppIcon-1024.jpg")
shutil.copyfile(MASTER_SVG, approved / "AppIcon.svg")

# --- iOS ---
ios = ROOT / "app/ios/Sources/RoutevaApp/Assets.xcassets/AppIcon.appiconset"
png(1024, ios / "AppIcon-1024.png")
png(180, ios / "AppIcon-180.png")
png(120, ios / "AppIcon-120.png")

# --- App Store 副本 ---
png(1024, ROOT / "gtm/stores/app_store/icon/AppIcon-1024.png")

# --- 网站 ---
web_icons = ROOT / "website/public/icons"
png(1024, web_icons / "app-icon-1024.png")
png(512, web_icons / "icon-512.png")
png(192, web_icons / "icon-192.png")
png(180, web_icons / "apple-touch-icon.png")
png(120, web_icons / "icon-120.png")
png(60, web_icons / "icon-60.png")
png(48, web_icons / "icon-48.png")
shutil.copyfile(MASTER_SVG, web_icons / "app-icon.svg")

web = ROOT / "website/public"
png(32, web / "favicon-32.png")
png(16, web / "favicon-16.png")
master.save(
    web / "favicon.ico",
    format="ICO",
    sizes=[(16, 16), (32, 32), (48, 48)],
)

print("ok")
for p in [
    brand / "AppIcon-1024.png",
    ios / "AppIcon-1024.png",
    web_icons / "icon-192.png",
    web / "favicon.ico",
]:
    im = Image.open(p)
    print(f"  {p.relative_to(ROOT)}  {im.size} {im.mode}")
