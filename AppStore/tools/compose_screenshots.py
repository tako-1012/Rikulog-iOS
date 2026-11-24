"""App Store 用スクリーンショット（6.9インチ 1320x2868）を合成する。

usage: python3 -I compose_screenshots.py <work_dir> [en|ja]
  <work_dir>/shots/<screen>.png を読み、<work_dir>/store/<screen>.png に書き出す
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = sys.argv[1]
LANG = sys.argv[2] if len(sys.argv) > 2 else "en"
W, H = 1320, 2868
FONT = "/System/Library/Fonts/SFNS.ttf"
JA_FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
JA_FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

SLIDES_JA = [
    ("pb", "自己ベストをお祝い", "記録を入れるだけで\n自己ベスト更新を自動でお知らせ"),
    ("records", "全レース、全ラップを記録", "トラック・ロード・跳躍・投擲を\nひとつのアプリで"),
    ("profile", "走力をVDOTで見える化", "実際のレース結果から\n走力と練習ペースを算出"),
    ("calculator", "目標ペースを一瞬で", "距離・タイム・ペースを相互計算\nラップごとの通過タイムも"),
    ("share", "記録をカードでシェア", "SNS映えする記録カードを\nワンタップで作成"),
    ("treadmill", "トレッドミル換算", "km/h と /km を\nワンタップで切り替え"),
]

SLIDES = [
    ("pb", "Celebrate every PR", "Instant personal best tracking\nfor every event"),
    ("records", "Every race. Every split.", "Track, road, jumps and throws\nin one clean log"),
    ("profile", "Know your VDOT", "Fitness score and training paces\nfrom your real races"),
    ("calculator", "Pace it perfectly", "Solve for distance, time or pace\nwith lap-by-lap splits"),
    ("share", "Share your result", "Beautiful race cards\nfor social media"),
    ("treadmill", "Treadmill converter", "Switch between km/h and min/km\nin one tap"),
]

TOP = (37, 110, 255)
BOTTOM = (10, 52, 170)


def font(size, weight):
    if LANG == "ja":
        path = JA_FONT_BOLD if weight == "Bold" else JA_FONT_REGULAR
        return ImageFont.truetype(path, size)
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient():
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    return bg


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *im.size), radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def centered(draw, y, text, f, fill, spacing):
    lines = text.split("\n")
    for line in lines:
        w = draw.textlength(line, font=f)
        draw.text(((W - w) / 2, y), line, font=f, fill=fill)
        y += f.size + spacing
    return y


base = gradient()
title_font = font(108 if LANG == "ja" else 118, "Bold")
sub_font = font(54 if LANG == "ja" else 58, "Medium")

for name, title, subtitle in (SLIDES_JA if LANG == "ja" else SLIDES):
    canvas = base.copy().convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # 長い見出しは左右に余白が残るよう文字を縮める
    tf = title_font
    while draw.textlength(title, font=tf) > W - 160 and tf.size > 70:
        tf = font(tf.size - 4, "Bold")
    y = centered(draw, 200, title, tf, (255, 255, 255), 20)
    centered(draw, y + 30, subtitle, sub_font, (220, 232, 255), 18)

    shot = Image.open(f"{S}/shots/{name}.png").convert("RGB")
    sw = 1010
    sh = int(shot.height * sw / shot.width)
    shot = rounded(shot.resize((sw, sh), Image.LANCZOS), 96)

    sx, sy = (W - sw) // 2, 640
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (sx, sy + 24, sx + sw, sy + sh + 24), radius=96, fill=(0, 0, 0, 110)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    # 端末の縁取り
    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (sx - 14, sy - 14, sx + sw + 14, sy + sh + 14), radius=110, fill=(18, 18, 22, 255)
    )
    canvas = Image.alpha_composite(canvas, frame)
    canvas.alpha_composite(shot, (sx, sy))

    canvas.convert("RGB").save(f"{S}/store/{name}.png")
    print("saved", name)
