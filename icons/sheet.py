import sys, os, math
from PIL import Image, ImageDraw
src = sys.argv[1]; out = sys.argv[2]
names = sorted(f for f in os.listdir(src) if f.endswith(".png"))
cell = 160; cols = 8
rows = math.ceil(len(names) / cols)
sheet = Image.new("RGBA", (cols * cell, rows * (cell + 18)), (58, 66, 92, 255))
d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    im = Image.open(os.path.join(src, n)).convert("RGBA").resize((cell - 16, cell - 16), Image.LANCZOS)
    x, y = (i % cols) * cell, (i // cols) * (cell + 18)
    # checker-ish card so outline and alpha are visible
    d.rounded_rectangle((x + 4, y + 4, x + cell - 4, y + cell - 4), 14, fill=(92, 104, 140, 255))
    sheet.alpha_composite(im, (x + 8, y + 8))
    d.text((x + 8, y + cell), n[:-4], fill=(255, 255, 255, 255))
sheet.save(out)
print(len(names), "icons")
