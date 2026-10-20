#!/usr/bin/env python3
"""App Store screenshots with a headline and a phone frame.

Takes the plain screenshots from tool/store_screens.sh (build/store_screens,
1320 x 2868) and puts each in a phone on the app's own colours under a
headline, at the same size App Store Connect asks for (6.9"), in Sepia, Charged and Light.

    python3 tool/store_frames.py            # every theme
    python3 tool/store_frames.py charged    # one theme

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


def frame(theme, name, first, second, sub):
    colors = THEMES[theme]
    shot_path = os.path.join(SHOTS, f'{name}.png' if name in SYSTEM else f'{theme}_{name}.png')
    if not os.path.exists(shot_path):
        return None
    shot = Image.open(shot_path).convert('RGB')

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


def main():
    themes = sys.argv[1:] or list(THEMES)
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
