"""App Store 用スクリーンショット（6.9インチ 1320x2868）を合成する。

usage: python3 -I compose_screenshots.py <work_dir> [en|ja]
  <work_dir>/shots/<screen>.png を読み、<work_dir>/store/<screen>.png に書き出す
"""
import sys
from PIL import Image, ImageDraw, ImageFont

S = sys.argv[1]
LANG = sys.argv[2] if len(sys.argv) > 2 else "en"
W, H = 1320, 2868

SF = "/System/Library/Fonts/SFNS.ttf"
JA_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
JA_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

BG = (14, 16, 21)
LANE = (30, 34, 43)
INDEX = (24, 28, 36)
WHITE = (245, 246, 248)
MUTED = (150, 158, 172)
ACCENT = (61, 133, 255)
MARGIN = 96

# (画面, ラベル, 見出し, 強調する語, 説明)
SLIDES = {
    "en": [
        ("pb", "PERSONAL BEST", "CELEBRATE\nEVERY PR", "PR", "Instant PB tracking for every event"),
        ("records", "RACE LOG", "EVERY RACE.\nEVERY SPLIT.", "SPLIT.", "Track, road, jumps and throws in one log"),
        ("profile", "VDOT", "KNOW YOUR\nVDOT", "VDOT", "Fitness score and training paces from real races"),
        ("calculator", "PACE CALCULATOR", "PACE IT\nPERFECTLY", "PERFECTLY", "Distance, time or pace - with lap splits"),
        ("share", "SHARE", "SHARE THE\nMOMENT", "MOMENT", "Race cards made for social media"),
        ("treadmill", "TREADMILL", "TREADMILL\nTO TRACK", "TO TRACK", "Convert km/h and min/km in one tap"),
    ],
    "ja": [
        ("pb", "PERSONAL BEST", "自己ベストを、\n祝おう。", "祝おう。", "記録を入れるだけで、更新を自動でお知らせ"),
        ("records", "RACE LOG", "全レース、\n全ラップ。", "全ラップ。", "トラック・ロード・跳躍・投擲をひとつに"),
        ("profile", "VDOT", "走力を、\nVDOTで。", "VDOTで。", "レース結果から走力と練習ペースを算出"),
        ("calculator", "PACE CALCULATOR", "目標ペースを、\n一瞬で。", "一瞬で。", "距離・タイム・ペースを相互計算"),
        ("share", "SHARE", "その記録、\nシェアしよう。", "シェアしよう。", "SNS映えする記録カードをワンタップで"),
        ("treadmill", "TREADMILL", "トレッドミルも、\nワンタップ。", "ワンタップ。", "km/h と /km をすぐに換算"),
    ],
}


def sf(size, style):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(style)
    return f


def headline_font(size):
    if LANG == "ja":
        return ImageFont.truetype(JA_BOLD, size)
    return sf(size, "Compressed Black")


def body_font(size):
    if LANG == "ja":
        return ImageFont.truetype(JA_REGULAR, size)
    return sf(size, "Medium")


def background(index):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # 大きな通し番号（背景の飾り）
    num = f"{index:02d}"
    nf = sf(900, "Compressed Black")
    nw = d.textlength(num, font=nf)
    d.text((W - nw + 40, 980), num, font=nf, fill=INDEX)
    # トラックのレーンを思わせる斜線
    for i in range(4):
        off = i * 150
        d.line([(-200, 2250 + off), (W + 200, 1450 + off)], fill=LANE, width=5)
    return im


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius=radius, fill=255)
    return mask


def draw_headline(d, text, accent, y):
    size = 230 if LANG == "en" else 132
    lines = text.split("\n")
    f = headline_font(size)
    while max(d.textlength(l, font=f) for l in lines) > W - MARGIN * 2 and size > 60:
        size -= 6
        f = headline_font(size)
    leading = int(size * (0.92 if LANG == "en" else 1.18))
    for line in lines:
        x = MARGIN
        if accent and accent in line:
            head, tail = line.split(accent, 1)
            for part, color in ((head, WHITE), (accent, ACCENT), (tail, WHITE)):
                if part:
                    d.text((x, y), part, font=f, fill=color)
                    x += d.textlength(part, font=f)
        else:
            d.text((x, y), line, font=f, fill=WHITE)
        y += leading
    return y


def compose(index, screen, label, title, accent, sub):
    canvas = background(index)
    d = ImageDraw.Draw(canvas)

    # ラベル（例: 01 — PERSONAL BEST）
    lf = sf(40, "Semibold")
    d.text((MARGIN, 170), f"{index:02d}  —  {label}", font=lf, fill=ACCENT)

    y = draw_headline(d, title, accent, 250)
    d.text((MARGIN, y + 36), sub, font=body_font(50 if LANG == "en" else 44), fill=MUTED)

    # 端末（下端は画面外にはみ出させる）
    shot = Image.open(f"{S}/shots/{screen}.png").convert("RGB")
    sw = 1000
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    bezel = 16
    sx = (W - sw) // 2
    sy = max(y + 200, 900)

    frame = Image.new("RGBA", (sw + bezel * 2, sh + bezel * 2), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((0, 0, sw + bezel * 2 - 1, sh + bezel * 2 - 1), radius=128, fill=(4, 5, 8, 255),
                         outline=(58, 63, 74, 255), width=3)
    frame.paste(shot, (bezel, bezel), rounded_mask((sw, sh), 112))
    canvas.paste(frame, (sx - bezel, sy - bezel), frame)

    canvas.save(f"{S}/store/{screen}.png")
    print("saved", screen)


for i, slide in enumerate(SLIDES[LANG], 1):
    compose(i, *slide)
