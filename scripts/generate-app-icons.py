"""Render the existing Android ZOVV vector mark into both platform icon sets."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
size = 1400
image = Image.new('RGB', (size, size), '#151614')
draw = ImageDraw.Draw(image)
for polygon in [((34,36),(109,36),(97,54),(22,54)),
                ((90,50),(111,50),(50,104),(29,104)),
                ((44,86),(118,86),(106,104),(32,104))]:
    draw.polygon([(x*10,y*10) for x,y in polygon], fill='#EAE8E2')
draw.rectangle((1040,1120,1139,1219), fill='#F16B28')
icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((icons/'Contents.json').read_text())['images']:
    if 'filename' not in entry:
        continue
    pixels = round(float(entry['size'].split('x')[0]) * float(entry['scale'].rstrip('x')))
    image.resize((pixels,pixels), Image.Resampling.LANCZOS).save(icons/entry['filename'])
for density,pixels in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    target = ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    image.resize((pixels,pixels), Image.Resampling.LANCZOS).save(target)
print('Rendered ZOVV icons for iOS and Android (opaque RGB).')
