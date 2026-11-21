#!/usr/bin/env python3
"""Draws assets/icon.svg: a tilted blue keycap reading SUPER in glowing orange,
with lightning bolts, circuit traces and sparkles (after the project's reference art).

    python3 tools/make_icon.py        # then render to PNG with rsvg-convert if needed

Letters are drawn as strokes, not text, so the icon looks the same without any font.
Only gradients and paths are used (no filters, masks or clip paths), which every
SVG renderer on the desktop handles (Qt, librsvg, browsers).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Stroke letters in a 60 x 80 box (y grows downwards).
LETTERS = {
    "S": "M50 14C44 6 34 4 28 4 15 4 8 12 8 22c0 22 44 14 44 36 0 12-10 20-23 20-9 0-18-4-23-12",
    "U": "M8 4v46c0 18 10 28 22 28s22-10 22-28V4",
    "P": "M10 78V4h22c12 0 20 8 20 18s-8 18-20 18H10",
    "E": "M50 4H10v74h40M10 40h34",
    "R": "M10 78V4h22c12 0 20 8 20 18s-8 18-20 18H10M32 40l20 38",
}


def word(text, x0, y0, step):
    return "".join(f'<path transform="translate({x0 + i * step} {y0})" d="{LETTERS[c]}"/>' for i, c in enumerate(text))


def bolt(x, y, s, grad):
    # A lightning bolt, top at (x, y), scale s.
    pts = [(0, 0), (-28, 46), (-8, 46), (-22, 86), (24, 32), (4, 32), (16, 0)]
    d = "M" + " ".join(f"{x + px * s:.1f} {y + py * s:.1f}" for px, py in pts) + "z"
    return f'<path d="{d}" fill="url(#{grad})"/>'


def sparkle(x, y, r, colour):
    k = r * 0.28
    return (f'<path d="M{x} {y - r}Q{x + k} {y - k} {x + r} {y}Q{x + k} {y + k} {x} {y + r}'
            f'Q{x - k} {y + k} {x - r} {y}Q{x - k} {y - k} {x} {y - r}z" fill="{colour}"/>')


def icon():
    letters = word("SUPER", 0, 0, 66)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>Omarchy Hotkeys</title>
  <desc>A tilted blue keycap reading SUPER in glowing orange, with lightning bolts and circuit traces.</desc>
  <defs>
    <linearGradient id="side" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1d3f86"/><stop offset="1" stop-color="#0b1c48"/></linearGradient>
    <linearGradient id="top" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1a3b80"/><stop offset=".55" stop-color="#1f5fae"/><stop offset="1" stop-color="#2a86d0"/></linearGradient>
    <linearGradient id="gloss" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".0"/><stop offset=".5" stop-color="#bfe3ff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <linearGradient id="ink" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd24a"/><stop offset=".55" stop-color="#ff8a1f"/><stop offset="1" stop-color="#ee3b1c"/></linearGradient>
    <linearGradient id="bolt" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd43b"/><stop offset="1" stop-color="#ff6a13"/></linearGradient>
    <linearGradient id="trace" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1e5bb8"/><stop offset="1" stop-color="#36a7f0"/></linearGradient>
  </defs>
  <!-- circuit traces behind the key -->
  <g fill="none" stroke="url(#trace)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
    <path d="M300 372l26 40h70l34 22"/><path d="M262 384l14 46h-62l-34 34"/><path d="M348 344l58 24 34-6"/>
    <path d="M386 186l34-30 26-4"/>
  </g>
  <g fill="#fff" stroke="url(#trace)" stroke-width="8">
    <circle cx="436" cy="438" r="12"/><circle cx="176" cy="468" r="12"/><circle cx="448" cy="360" r="12"/><circle cx="452" cy="150" r="12"/>
  </g>
  <!-- the key: side, then the face, tilted like a keycap seen from above -->
  <g transform="rotate(-14 256 262)">
    <rect x="70" y="138" width="372" height="270" rx="56" fill="url(#side)"/>
    <rect x="70" y="122" width="372" height="262" rx="56" fill="#0e2559"/>
    <rect x="96" y="134" width="320" height="214" rx="38" fill="url(#top)" stroke="#48a6ee" stroke-width="5"/>
    <path d="M108 300c90-12 180-58 236-150h36c-58 98-150 150-272 172z" fill="url(#gloss)"/>
    <!-- SUPER: a soft glow, a light rim, then the letters -->
    <g transform="translate(126 200) scale(.86)" fill="none" stroke-linecap="round" stroke-linejoin="round">
      <g stroke="#ff9a3c" stroke-opacity=".35" stroke-width="34">{letters}</g>
      <g stroke="#ffe7a8" stroke-width="22">{letters}</g>
      <g stroke="url(#ink)" stroke-width="15">{letters}</g>
    </g>
  </g>
  <!-- speed streaks, bolts, sparkles -->
  <g fill="none" stroke-linecap="round">
    <path d="M58 300l120-40" stroke="#ff8a1f" stroke-width="9" stroke-opacity=".75"/>
    <path d="M44 344l92-30" stroke="#5ab8ff" stroke-width="7" stroke-opacity=".6"/>
    <path d="M118 120l80-36 60 10 64-50" stroke="#ff8a1f" stroke-width="10"/>
  </g>
  {bolt(452, 64, 1.25, "bolt")}
  {bolt(92, 360, 1.05, "bolt")}
  {sparkle(310, 52, 16, "#ffb02e")}
  {sparkle(470, 240, 14, "#ff6a13")}
  {sparkle(60, 452, 13, "#ff8a1f")}
  <g><circle cx="356" cy="58" r="8" fill="#1e5bb8"/><circle cx="40" cy="250" r="9" fill="#ff6a13"/><circle cx="476" cy="300" r="8" fill="#1e5bb8"/><circle cx="214" cy="486" r="7" fill="#1e5bb8"/><circle cx="140" cy="440" r="7" fill="#ffb02e"/></g>
</svg>
"""


if __name__ == "__main__":
    out = ROOT / "assets"
    out.mkdir(exist_ok=True)
    (out / "icon.svg").write_text(icon())
    print("assets/icon.svg")
