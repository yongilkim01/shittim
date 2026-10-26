#!/usr/bin/env python3
"""Rebuild the original HUD symbol font. Development only: requires fonttools."""
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen


def glyph(contours):
    pen = TTGlyphPen(None)
    for points, hole in contours:
        area = sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1]))
        if (area > 0) != hole: points = list(reversed(points))
        pen.moveTo(points[0])
        for point in points[1:]: pen.lineTo(point)
        pen.closePath()
    return pen.glyph()


def build():
    names = ['.notdef', 'minimize', 'maximize', 'close']
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({0x10FF00:'minimize', 0x10FF01:'maximize', 0x10FF02:'close'})
    fb.setupGlyf({
        '.notdef': glyph([]),
        'minimize': glyph([([(50,445),(950,445),(950,555),(50,555)],False)]),
        'maximize': glyph([([(50,50),(950,50),(950,950),(50,950)],False),
                           ([(160,160),(840,160),(840,840),(160,840)],True)]),
        'close': glyph([([(50,128),(128,50),(950,872),(872,950)],False),
                        ([(50,872),(128,950),(950,128),(872,50)],False)]),
    })
    fb.setupHorizontalMetrics({name:(1000,50 if name!='.notdef' else 0) for name in names})
    fb.setupHorizontalHeader(ascent=1000,descent=0)
    fb.setupNameTable({'familyName':'Shittim HUD Controls','styleName':'Regular',
        'uniqueFontIdentifier':'ShittimHUDControls-Regular-1.0','fullName':'Shittim HUD Controls Regular',
        'psName':'ShittimHUDControls-Regular','version':'Version 1.0',
        'copyright':'Copyright Shittim contributors. MIT License.',
        'licenseDescription':'Original vector outlines, distributed under the repository MIT License.'})
    fb.setupOS2(sTypoAscender=1000,sTypoDescender=0,sTypoLineGap=0,usWinAscent=1000,usWinDescent=0)
    fb.setupPost()
    fb.font['head'].created = fb.font['head'].modified = 3786912000
    fb.font.recalcTimestamp = False
    target = Path(__file__).resolve().parents[1]/'assets/fonts/ShittimHUDControls-Regular.ttf'
    target.parent.mkdir(parents=True,exist_ok=True)
    fb.save(target)


if __name__ == '__main__': build()
