#!/usr/bin/env python3
"""Makes Momentum's app icons from the sources in assets/branding.

Each source is a rounded icon on black (as drawn). This crops it to the
icon, fills the black corners with the icon's own edge colours (iOS and
Android cut their own corners), and writes:

  - iOS: single-size 1024 icon sets in ios/Runner/Assets.xcassets. AppIcon
    (the primary) follows the system: light in light mode, dark in dark mode.
    Every icon also has a fixed set, AppIcon-<Name>, offered in Settings.
  - Android: adaptive launcher icons (mipmap-anydpi-v26), so each launcher
    masks them to its own shape: the icon on the foreground layer, small
    enough that the logo sits in the 66dp safe zone, its edge colour behind,
    and a monochrome logo for themed icons (Android 13+). Plain mipmaps at
    five densities too, for launchers that don't use adaptive icons.
  - Previews for Settings → App icon, in assets/branding/icons.
  - Full-bleed 1024 masters, assets/branding/app_icon_<id>.png, to look at.

Adding an icon: a source PNG, a line in ICONS, an entry in
lib/core/branding/app_icons.dart, an <activity-alias> in AndroidManifest.xml
and its name in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES
(test/unit/core/branding/app_icons_test.dart checks they agree).

Run from the project root: python3 tool/make_app_icons.py
"""

import json
import os

import numpy as np
from PIL import Image, ImageFilter

BRANDING = 'assets/branding'
XCASSETS = 'ios/Runner/Assets.xcassets'
ANDROID_RES = 'android/app/src/main/res'

# id, source, iOS set, Android mipmap name
ICONS = [
    ('charged', 'app_icon_source.png', 'AppIcon-Charged', 'ic_launcher'),
    ('light', 'app_icon_source_light.png', 'AppIcon-Light', 'ic_launcher_light'),
]

# The primary icon: light in light mode, dark in dark mode (iOS 18+)
PRIMARY_LIGHT = 'light'
PRIMARY_DARK = 'charged'

ANDROID_SIZES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
PREVIEW_SIZE = 180

# Adaptive icons: a 108dp canvas, of which launchers show the middle 72dp and
# keep the middle 66dp whatever their mask. The icon is drawn ICON_DP across,
# which puts its logo (about 72% of it) inside the safe zone
ADAPTIVE_DP = 108
ICON_DP = 78
ADAPTIVE_SCALES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def _push_pull_fill(rgb, known):
    """Fills unknown pixels from the nearest known ones, smoothly."""
    if known.all() or rgb.shape[0] <= 1 or rgb.shape[1] <= 1:
        return rgb
    weight = known.astype(np.float64)
    h, w = known.shape
    h2, w2 = (h + 1) // 2, (w + 1) // 2
    # Pad to even sizes, then average 2×2 blocks, weighted by what's known
    pad = ((0, h2 * 2 - h), (0, w2 * 2 - w))
    wp = np.pad(weight, pad)
    cp = np.pad(rgb * weight[..., None], pad + ((0, 0),))
    wsum = wp.reshape(h2, 2, w2, 2).sum(axis=(1, 3))
    csum = cp.reshape(h2, 2, w2, 2, 3).sum(axis=(1, 3))
    small_known = wsum > 0
    small = np.zeros((h2, w2, 3))
    small[small_known] = csum[small_known] / wsum[small_known][:, None]
    small = _push_pull_fill(small, small_known)
    up = small.repeat(2, axis=0).repeat(2, axis=1)[:h, :w]
    out = rgb.copy()
    out[~known] = up[~known]
    return out


def _to_image(rgb):
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))


def _grow(mask):
    """The mask spread by one pixel up, down, left and right."""
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def full_bleed(path):
    """The icon cropped from its black surround, corners filled in."""
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    dark = rgb.sum(axis=2) <= 30
    # The surround: black reaching in from the edges (dark parts of the icon
    # itself don't touch the edge, so they stay)
    outside = np.zeros_like(dark)
    outside[0, :], outside[-1, :], outside[:, 0], outside[:, -1] = dark[0, :], dark[-1, :], dark[:, 0], dark[:, -1]
    while True:
        grown = _grow(outside) & dark
        if (grown == outside).all():
            break
        outside = grown
    # Step in past the glossy rim and the soft edge
    for _ in range(10):
        outside = _grow(outside)
    inside = ~outside
    rows = np.where(inside.any(axis=1))[0]
    cols = np.where(inside.any(axis=0))[0]
    top, bottom, left, right = rows[0], rows[-1] + 1, cols[0], cols[-1] + 1
    crop = rgb[top:bottom, left:right]
    known = inside[top:bottom, left:right]
    filled = _push_pull_fill(crop, known)
    # Soften the fill, which comes out blocky; the icon itself is untouched
    soft = np.asarray(_to_image(filled).filter(ImageFilter.GaussianBlur(24))).astype(np.float64)
    filled[~known] = soft[~known]
    image = _to_image(filled)
    return image.resize((1024, 1024), Image.LANCZOS)


def _edge_colour(image):
    rgb = np.asarray(image.convert('RGB')).astype(np.float64)
    band = max(1, rgb.shape[0] // 25)
    edges = np.concatenate([rgb[:band].reshape(-1, 3), rgb[-band:].reshape(-1, 3),
                            rgb[:, :band].reshape(-1, 3), rgb[:, -band:].reshape(-1, 3)])
    return np.median(edges, axis=0)


def adaptive_foreground(image, size):
    """The icon in the middle of the canvas, its edges carried out to the
    sides so no seam shows whatever the launcher's mask or motion."""
    inner = round(size * ICON_DP / ADAPTIVE_DP)
    offset = (size - inner) // 2
    canvas = np.zeros((size, size, 3))
    known = np.zeros((size, size), dtype=bool)
    canvas[offset:offset + inner, offset:offset + inner] = np.asarray(
        image.resize((inner, inner), Image.LANCZOS)).astype(np.float64)
    known[offset:offset + inner, offset:offset + inner] = True
    filled = _push_pull_fill(canvas, known)
    soft = np.asarray(_to_image(filled).filter(ImageFilter.GaussianBlur(size / 12))).astype(np.float64)
    filled[~known] = soft[~known]
    return _to_image(filled)


def logo_alpha(image):
    """Where the icon differs from its background: its logo, 0 to 1."""
    rgb = np.asarray(image.convert('RGB')).astype(np.float64)
    distance = np.sqrt(((rgb - _edge_colour(image)) ** 2).sum(axis=2))
    strongest = np.percentile(distance, 99)
    # Glows and soft shadows stay out; the logo's strokes come through solid
    return np.clip((distance - 0.35 * strongest) / (0.25 * strongest), 0, 1)


def adaptive_monochrome(alpha, size):
    """The logo alone, white on clear: Android tints it for themed icons."""
    inner = round(size * ICON_DP / ADAPTIVE_DP)
    offset = (size - inner) // 2
    mask = Image.fromarray((alpha * 255).astype(np.uint8)).resize((inner, inner), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    out.paste(Image.new('RGBA', (inner, inner), (255, 255, 255, 255)), (offset, offset), mask)
    return out


def write_adaptive_icon(image, logo, mipmap):
    for density, scale in ADAPTIVE_SCALES.items():
        size = round(ADAPTIVE_DP * scale)
        folder = os.path.join(ANDROID_RES, f'mipmap-{density}')
        adaptive_foreground(image, size).save(os.path.join(folder, f'{mipmap}_foreground.png'))
        adaptive_monochrome(logo, size).save(os.path.join(folder, f'{mipmap}_monochrome.png'))
    folder = os.path.join(ANDROID_RES, 'mipmap-anydpi-v26')
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f'{mipmap}.xml'), 'w') as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Made by tool/make_app_icons.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/{mipmap}_background"/>
    <foreground android:drawable="@mipmap/{mipmap}_foreground"/>
    <monochrome android:drawable="@mipmap/{mipmap}_monochrome"/>
</adaptive-icon>
''')


def write_adaptive_colours(colours):
    lines = ''.join(f'    <color name="{mipmap}_background">#{r:02X}{g:02X}{b:02X}</color>\n'
                    for mipmap, (r, g, b) in colours.items())
    with open(os.path.join(ANDROID_RES, 'values', 'ic_launcher_colors.xml'), 'w') as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Behind each adaptive launcher icon; made by tool/make_app_icons.py -->
<resources>
{lines}</resources>
''')


def write_appiconset(name, any_image, dark_image):
    folder = os.path.join(XCASSETS, f'{name}.appiconset')
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith('.png'):
            os.remove(os.path.join(folder, f))
    images = [{'filename': 'icon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}]
    any_image.save(os.path.join(folder, 'icon.png'))
    images.append({
        'appearances': [{'appearance': 'luminosity', 'value': 'dark'}],
        'filename': 'icon-dark.png',
        'idiom': 'universal',
        'platform': 'ios',
        'size': '1024x1024',
    })
    dark_image.save(os.path.join(folder, 'icon-dark.png'))
    with open(os.path.join(folder, 'Contents.json'), 'w') as f:
        json.dump({'images': images, 'info': {'author': 'xcode', 'version': 1}}, f, indent=2)
        f.write('\n')


def main():
    icons = {icon_id: full_bleed(os.path.join(BRANDING, source)) for icon_id, source, _, _ in ICONS}
    # Every icon is the same logo in different colours. Each one's colours
    # hide part of it (dark blue on navy, yellow on cream), so the themed icon
    # takes the logo from all of them together
    logo = np.maximum.reduce([logo_alpha(image) for image in icons.values()])
    colours = {}
    os.makedirs(os.path.join(BRANDING, 'icons'), exist_ok=True)
    for icon_id, _, ios_set, mipmap in ICONS:
        image = icons[icon_id]
        image.save(os.path.join(BRANDING, f'app_icon_{icon_id}.png'))
        # A fixed choice stays put in dark mode, too
        write_appiconset(ios_set, image, image)
        for density, size in ANDROID_SIZES.items():
            image.resize((size, size), Image.LANCZOS).save(
                os.path.join(ANDROID_RES, f'mipmap-{density}', f'{mipmap}.png'))
        write_adaptive_icon(image, logo, mipmap)
        colours[mipmap] = tuple(int(round(c)) for c in _edge_colour(image))
        image.resize((PREVIEW_SIZE, PREVIEW_SIZE), Image.LANCZOS).save(
            os.path.join(BRANDING, 'icons', f'{icon_id}.png'))
        print(f'{icon_id}: {ios_set}, {mipmap}')
    write_adaptive_colours(colours)
    write_appiconset('AppIcon', icons[PRIMARY_LIGHT], icons[PRIMARY_DARK])
    print(f'AppIcon: {PRIMARY_LIGHT}, {PRIMARY_DARK} in dark mode')


if __name__ == '__main__':
    main()
