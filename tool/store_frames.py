#!/usr/bin/env python3
"""App Store screenshots with a headline and a phone frame.

Takes the plain screenshots from tool/store_screens.sh (build/store_screens,
1320 x 2868) and puts each in a phone on the app's own colours under a
headline, at the same size App Store Connect asks for (6.9"), in Sepia, Charged and Light.

    python3 tool/store_frames.py            # every theme
    python3 tool/store_frames.py charged    # one theme
    python3 tool/store_frames.py --ipad     # the iPad set (13", upright)

Pictures land in build/store_frames/<theme>/, and the set to upload, in
order, in build/store_frames/final/ (FINAL below). The words are in SCREENS.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, 'build', 'store_screens')
OUT = os.path.join(ROOT, 'build', 'store_frames')
BOLD = os.path.join(ROOT, 'assets', 'fonts', 'Sora', 'Sora-Bold.ttf')
SEMI = os.path.join(ROOT, 'assets', 'fonts', 'Sora', 'Sora-SemiBold.ttf')

W, H = 1320, 2868

# The iPad set: 13" (what App Store Connect asks for), upright, from
# tool/store_screens.sh "Store iPad Pro 13-inch" (ipad_<theme>_<name>.png)
IPAD_W, IPAD_H = 2064, 2752

# Each screenshot's words: the headline's first line, its second (in the
# accent colour), and a line under it.
SCREENS = [
    ('01_habits', 'Momentum,', 'not perfection', 'Every habit at a glance, with a score that forgives a bad day'),
    ('02_habit_page', 'Small steps', 'add up', 'Log in a tap. Watch the streak, the trend and the month fill in'),
    ('03_never_miss_twice', 'Miss once.', 'Never twice.', 'One miss keeps the streak. Freezes cover the days you need'),
    ('04_two_minute', 'Hard day?', '2 minutes counts', 'Every habit has a tiny version that still keeps it going'),
    ('05_insights', 'See your', 'momentum grow', 'A heatmap of every day, and the habits you\'ve already formed'),
    ('06_calendar', 'Every day,', 'at a glance', 'Fill in a day you missed logging, or look back at a good month'),
    ('07_inspire', 'Words to', 'keep you going', 'A quote a day from the Stoics, classic writers and Scripture'),
    ('08_achievements', 'Celebrate', 'the milestones', 'Real achievements, and a few silly ones'),
    # Captured from SpringBoard by tool/widget_screens.sh, the same in every look
    ('lock_screen', 'Right on your', 'lock screen',
     'Momentum, a streak and today\'s progress. Log without opening the app'),
    ('home_widgets', 'Log it from', 'home screen', 'Tap + on a widget. Streaks and momentum keep up'),
]

# Screenshots of the phone's own screens rather than the app: one picture,
# framed in whichever look the set asks for.
SYSTEM = {'lock_screen', 'home_widgets'}

THEMES = {
    # The app's palettes (lib/core/theme/app_palette.dart)
    'sepia': dict(bg=(243, 235, 221), glow=(232, 160, 60), ink=(30, 26, 22), accent=(168, 90, 14), sub=(110, 96, 82),
                  edge=(70, 70, 76)),
    'light': dict(bg=(244, 245, 247), glow=(240, 170, 70), ink=(20, 22, 26), accent=(194, 106, 8), sub=(100, 104, 112),
                  edge=(70, 70, 76)),
    'charged': dict(bg=(14, 16, 19), glow=(255, 150, 20), ink=(244, 244, 246), accent=(255, 176, 32), sub=(160, 164, 172),
                    edge=(120, 122, 130)),
}


# The set that goes on the App Store, in order, with the look each is framed
# in: Sepia leads, the lock screen and home screen come 4th and 5th, then all
# three looks take turns (Paul's choices, 2026-10-20).
FINAL = [
    ('01_habits', 'sepia'),
    ('02_habit_page', 'sepia'),
    ('03_never_miss_twice', 'charged'),
    ('lock_screen', 'sepia'),
    ('home_widgets', 'light'),
    ('04_two_minute', 'charged'),
    ('05_insights', 'sepia'),
    ('06_calendar', 'light'),
    ('07_inspire', 'charged'),
    ('08_achievements', 'sepia'),
]


# The iPad set, in order: the app's own screens (no lock or home screen)
FINAL_IPAD = [entry for entry in FINAL if entry[0] not in SYSTEM]


def rounded_mask(size, radius):
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def phone(shot, width, edge):
    """The screenshot in a black phone with the Dynamic Island; [edge] is
    its metal rim (lighter on a dark background)."""
    bezel = round(width * 0.028)
    screen_w = width - 2 * bezel
    screen_h = round(shot.height * screen_w / shot.width)
    screen = shot.resize((screen_w, screen_h), Image.LANCZOS)
    radius = round(screen_w * 0.135)
    body = Image.new('RGBA', (width, screen_h + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius + bezel, fill=(12, 12, 14, 255))
    # A thin metal edge
    d.rounded_rectangle([3, 3, body.width - 4, body.height - 4], radius=radius + bezel - 3,
                        outline=edge + (255,), width=5)
    body.paste(screen, (bezel, bezel), rounded_mask(screen.size, radius))
    island_w, island_h = round(screen_w * 0.31), round(screen_w * 0.092)
    top = bezel + round(screen_w * 0.027)
    d.rounded_rectangle([(width - island_w) // 2, top, (width + island_w) // 2, top + island_h],
                        radius=island_h // 2, fill=(0, 0, 0, 255))
    return body


def ipad(shot, width, edge):
    """The screenshot in a black iPad: an even bezel, rounded corners, the
    front camera in the bezel."""
    bezel = round(width * 0.022)
    screen_w = width - 2 * bezel
    screen_h = round(shot.height * screen_w / shot.width)
    screen = shot.resize((screen_w, screen_h), Image.LANCZOS)
    radius = round(screen_w * 0.025)
    body = Image.new('RGBA', (width, screen_h + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius + bezel, fill=(12, 12, 14, 255))
    d.rounded_rectangle([3, 3, body.width - 4, body.height - 4], radius=radius + bezel - 3,
                        outline=edge + (255,), width=5)
    body.paste(screen, (bezel, bezel), rounded_mask(screen.size, radius))
    # Upright, the camera is in the top bezel
    r = max(4, bezel // 5)
    d.ellipse([width // 2 - r, bezel // 2 - r, width // 2 + r, bezel // 2 + r], fill=(30, 30, 34, 255))
    return body


def wrap(draw, text, font, max_width):
    words, lines, line = text.split(), [], ''
    for word in words:
        trial = f'{line} {word}'.strip()
        if draw.textlength(trial, font=font) <= max_width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def frame(theme, name, first, second, sub, tablet=False):
    colors = THEMES[theme]
    if tablet:
        shot_path = os.path.join(SHOTS, f'ipad_{theme}_{name}.png')
    else:
        shot_path = os.path.join(SHOTS, f'{name}.png' if name in SYSTEM else f'{theme}_{name}.png')
    if not os.path.exists(shot_path):
        return None
    shot = Image.open(shot_path).convert('RGB')
    if tablet:
        return frame_ipad(colors, shot, first, second, sub)

    canvas = Image.new('RGB', (W, H), colors['bg'])
    # A soft amber glow behind the phone
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.02, H * 0.38, W * 0.98, H * 0.80], fill=colors['glow'] + (130,))
    canvas.paste(glow.filter(ImageFilter.GaussianBlur(160)), (0, 0), glow.filter(ImageFilter.GaussianBlur(160)))

    d = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(BOLD, 128)
    small = ImageFont.truetype(SEMI, 50)
    y = 190
    for text, color in ((first, colors['ink']), (second, colors['accent'])):
        for line in wrap(d, text, title, W - 160):
            d.text((W / 2, y), line, font=title, fill=color, anchor='mt')
            y += 150
    y += 26
    for line in wrap(d, sub, small, W - 240):
        d.text((W / 2, y), line, font=small, fill=colors['sub'], anchor='mt')
        y += 68

    # Big, running off the bottom: the top of the screen is what matters
    body = phone(shot, 1060, colors['edge'])
    top = y + 80
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(W - body.width) / 2 + 10, top + 40, (W + body.width) / 2 - 10, top + body.height + 30],
        radius=150, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(body, ((W - body.width) // 2, top), body)
    return canvas


def frame_ipad(colors, shot, first, second, sub):
    """The iPad set's layout, upright: the headline on one line (its second
    part in the accent colour), the line under it, and the iPad below,
    running off the bottom."""
    canvas = Image.new('RGB', (IPAD_W, IPAD_H), colors['bg'])
    glow = Image.new('RGBA', (IPAD_W, IPAD_H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([IPAD_W * 0.08, IPAD_H * 0.30, IPAD_W * 0.92, IPAD_H * 1.05], fill=colors['glow'] + (120,))
    blurred = glow.filter(ImageFilter.GaussianBlur(200))
    canvas.paste(blurred, (0, 0), blurred)

    d = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(BOLD, 112)
    small = ImageFont.truetype(SEMI, 52)
    whole = f'{first} {second}'
    x = (IPAD_W - d.textlength(whole, font=title)) / 2
    y = 120
    d.text((x, y), first + ' ', font=title, fill=colors['ink'])
    d.text((x + d.textlength(first + ' ', font=title), y), second, font=title, fill=colors['accent'])
    y += 168
    for line in wrap(d, sub, small, IPAD_W - 400):
        d.text((IPAD_W / 2, y), line, font=small, fill=colors['sub'], anchor='mt')
        y += 70

    body = ipad(shot, 1760, colors['edge'])
    top = y + 70
    shadow = Image.new('RGBA', (IPAD_W, IPAD_H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(IPAD_W - body.width) / 2 + 10, top + 40, (IPAD_W + body.width) / 2 - 10, top + body.height + 30],
        radius=90, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(body, ((IPAD_W - body.width) // 2, top), body)
    return canvas


def main_ipad(themes):
    final = os.path.join(OUT, 'final_ipad')
    os.makedirs(final, exist_ok=True)
    words = {name: (first, second, sub) for name, first, second, sub in SCREENS}
    for old in os.listdir(final):
        os.remove(os.path.join(final, old))
    for i, (name, theme) in enumerate(FINAL_IPAD):
        picture = frame(theme, name, *words[name], tablet=True)
        if picture is not None:
            path = os.path.join(final, f'{i + 1:02d}_{name[3:]}_{theme}.png')
            picture.save(path)
            print(path)
    for theme in themes:
        os.makedirs(os.path.join(OUT, f'ipad_{theme}'), exist_ok=True)
        for name, first, second, sub in SCREENS:
            if name in SYSTEM:
                continue
            picture = frame(theme, name, first, second, sub, tablet=True)
            if picture is not None:
                path = os.path.join(OUT, f'ipad_{theme}', f'{name}.png')
                picture.save(path)
                print(path)


def main():
    args = sys.argv[1:]
    if '--ipad' in args:
        main_ipad([a for a in args if a != '--ipad'] or list(THEMES))
        return
    themes = args or list(THEMES)
    final = os.path.join(OUT, 'final')
    os.makedirs(final, exist_ok=True)
    words = {name: (first, second, sub) for name, first, second, sub in SCREENS}
    for old in os.listdir(final):
        os.remove(os.path.join(final, old))
    for i, (name, theme) in enumerate(FINAL):
        picture = frame(theme, name, *words[name])
        if picture is not None:
            label = name[3:] if name[:2].isdigit() else name
            path = os.path.join(final, f'{i + 1:02d}_{label}_{theme}.png')
            picture.save(path)
            print(path)
    for theme in themes:
        os.makedirs(os.path.join(OUT, theme), exist_ok=True)
        for name, first, second, sub in SCREENS:
            if name in SYSTEM:
                continue
            picture = frame(theme, name, first, second, sub)
            if picture is None:
                continue
            path = os.path.join(OUT, theme, f'{name}.png')
            picture.save(path)
            print(path)


if __name__ == '__main__':
    main()
