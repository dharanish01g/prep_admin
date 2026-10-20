"""Draws the Tiny Tasks launcher icon: a white checkbox with a check and an
amber reminder dot, on the app's purple gradient."""
import sys
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4            # supersample for smooth edges
N = 1024 * SS
TOP, BOTTOM = (109, 93, 252), (142, 84, 233)   # #6D5DFC -> #8E54E9 (brand)
CHECK = (91, 75, 245)                           # #5B4BF5
AMBER = (253, 176, 34)                          # #FDB022

def gradient():
    g = Image.new('RGB', (N, N))
    d = ImageDraw.Draw(g)
    for y in range(N):
        # diagonal-ish: blend by y plus a little x via two passes is overkill; vertical is fine
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return g

def motif(scale):
    """Transparent layer with the card, check and dot, centred."""
    m = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    s = scale * SS
    cx, cy = N / 2 - 30 * s, N / 2 + 30 * s       # card centre; dot balances it
    half, rad = 230 * s, 96 * s
    # soft shadow under the card
    sh = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [cx - half, cy - half + 22 * s, cx + half, cy + half + 22 * s], rad, fill=(40, 20, 120, 90))
    m = Image.alpha_composite(m, sh.filter(ImageFilter.GaussianBlur(28 * s)))
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([cx - half, cy - half, cx + half, cy + half], rad, fill=(255, 255, 255, 255))
    # check mark, round joints and caps
    w = int(64 * s)
    pts = [(cx - 118 * s, cy + 6 * s), (cx - 34 * s, cy + 90 * s), (cx + 128 * s, cy - 96 * s)]
    d.line(pts, fill=CHECK, width=w, joint='curve')
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=CHECK)
    # reminder dot on the top-right corner, with a white ring to separate it
    dx, dy, r = cx + half - 10 * s, cy - half + 10 * s, 74 * s
    d.ellipse([dx - r - 18 * s, dy - r - 18 * s, dx + r + 18 * s, dy + r + 18 * s], fill=(255, 255, 255, 255))
    d.ellipse([dx - r, dy - r, dx + r, dy + r], fill=AMBER)
    return m

def save(img, name):
    img.resize((1024, 1024), Image.LANCZOS).save(f'{out}/{name}')

bg = gradient()
save(bg, 'background.png')
save(Image.alpha_composite(bg.convert('RGBA'), motif(1.08)).convert('RGB'), 'icon.png')
# Android adaptive foreground: launchers crop to the central ~61%, so shrink.
save(motif(0.8), 'foreground.png')
# Launch screen: same mark, smaller (Android 12+ shows this 1024px image at
# 288dp, so the card is about 80dp).
save(motif(0.5), 'splash.png')
