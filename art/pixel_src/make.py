#!/usr/bin/env python3
"""Builds the pixel art in this folder and puts it where the game reads it.

Needs Node 22.18+ and claude-pxl (https://github.com/crsolver/claude-pxl):
    git clone https://github.com/crsolver/claude-pxl.git
    python3 art/pixel_src/make.py --pxl path/to/claude-pxl [animals] [gifts] [scenery]

- animals.px.js -> art/animals/<animal>/frames.png and a generated animal.tscn
  (a Sprite2D strip of 7 frames, an AnimationPlayer with walk, idle and sad,
  and Neck and Mouth markers that follow each frame).
- gifts.px.js   -> art/gifts/<gift>.png (replacing the placeholder .svg).
- scenery.px.js -> the dive bush (art/walk/bush.png) and the holiday props
  (pumpkins, eggs). The walk's layers themselves are drawn in code on the
  same pixel grid (scenes/walk/scenery_painter.gd, ui/pixel_draw.gd).
- home.px.js    -> art/home/<layer>.png, the hilltop view behind every screen.

Edit the .px.js files and run this again; or paint over the PNGs in any
pixel editor (keep nearest-neighbour, no smoothing).
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
# One pixel of art is this many pixels on a screen 720 tall.
PIXEL = 3.0
FRAMES = 7
STAND, BLINK, SAD = 4, 5, 6


def build(pxl: str, name: str, out: str) -> str:
    """Runs pxl on <name>.px.js; returns what the file printed (its markers)."""
    res = subprocess.run(["node", os.path.join(pxl, "bin", "pxl.js"), "build", os.path.join(HERE, name + ".px.js"),
                          "--out", out, "--no-preview"], capture_output=True, text=True)
    if res.returncode != 0 or "error" in res.stderr.lower():
        raise SystemExit(res.stdout + res.stderr)
    return res.stdout


def animals(pxl: str) -> None:
    out = tempfile.mkdtemp()
    text = build(pxl, "animals", out)
    marks = json.loads(next(l for l in text.splitlines() if l.startswith("@@MARKS "))[8:])
    cast = json.load(open(os.path.join(ROOT, "data", "animals.json")))["animals"]
    for a in cast:
        m = marks.get(a["id"])
        if m is None:
            print("no art for", a["id"])
            continue
        folder = os.path.join(ROOT, a["sprite_dir"].replace("res://", ""))
        os.makedirs(folder, exist_ok=True)
        shutil.copy(os.path.join(out, "anims", a["id"] + ".png"), os.path.join(folder, "frames.png"))
        # The outline adds a pixel all round; the origin is where the feet meet the ground.
        ox, oy = m["ax"] + 1, m["h"] + 1
        k = PIXEL / float(a.get("size", 1.0))

        def at(p, f, drop=0):
            return ((p[0] + 1 - ox) * k, (p[1] + 1 + m["move"][f] + drop - oy) * k)

        res_path = a["sprite_dir"] + "frames.png"
        with open(os.path.join(folder, "animal.tscn"), "w") as fh:
            fh.write(scene(res_path, ox, oy, k, m, at))
    print("animals:", len(marks))


def _vec(p):
    return "Vector2(%g, %g)" % (round(p[0], 2), round(p[1], 2))


def _track(i, path, times, values, discrete=True):
    vals = ", ".join(values)
    return (f'tracks/{i}/type = "value"\ntracks/{i}/imported = false\ntracks/{i}/enabled = true\n'
            f'tracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 0\ntracks/{i}/loop_wrap = true\n'
            f'tracks/{i}/keys = {{\n"times": PackedFloat32Array({", ".join("%g" % t for t in times)}),\n'
            f'"transitions": PackedFloat32Array({", ".join("1" for _ in times)}),\n'
            f'"update": {1 if discrete else 0},\n"values": [{vals}]\n}}\n')


def _anim(name, length, frames, times, m, at):
    body = f'[sub_resource type="Animation" id="Animation_{name}"]\nresource_name = "{name}"\nlength = {length}\nloop_mode = 1\n'
    body += _track(0, "Sprite:frame", times, [str(f) for f in frames])
    body += _track(1, "Neck:position", times, [_vec(at(m["neck"], f)) for f in frames])
    body += _track(2, "Mouth:position", times, [_vec(at(m["mouth"], f, 2 if f == SAD else 0)) for f in frames])
    return body + "\n"


def scene(res_path, ox, oy, k, m, at):
    s = '[gd_scene format=3]\n\n'
    s += f'[ext_resource type="Texture2D" path="{res_path}" id="1_frames"]\n\n'
    s += _anim("walk", 0.8, [0, 1, 2, 3], [0, 0.2, 0.4, 0.6], m, at)
    s += _anim("idle", 4.0, [STAND, BLINK, STAND], [0, 3.5, 3.65], m, at)
    s += _anim("sad", 1.0, [SAD], [0], m, at)
    s += ('[sub_resource type="AnimationLibrary" id="AnimationLibrary_main"]\n_data = {\n'
          '&"idle": SubResource("Animation_idle"),\n&"sad": SubResource("Animation_sad"),\n'
          '&"walk": SubResource("Animation_walk")\n}\n\n')
    s += '[node name="Rig" type="Node2D"]\n\n'
    s += ('[node name="Sprite" type="Sprite2D" parent="."]\ntexture_filter = 1\n'
          f'scale = Vector2({k:g}, {k:g})\ntexture = ExtResource("1_frames")\ncentered = false\n'
          f'offset = Vector2({-ox}, {-oy})\nhframes = {FRAMES}\nframe = {STAND}\n\n')
    s += f'[node name="Neck" type="Marker2D" parent="."]\nposition = {_vec(at(m["neck"], STAND))}\n\n'
    s += f'[node name="Mouth" type="Marker2D" parent="."]\nposition = {_vec(at(m["mouth"], STAND))}\n\n'
    s += '[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("AnimationLibrary_main")\n'
    return s


def gifts(pxl: str) -> None:
    out = tempfile.mkdtemp()
    build(pxl, "gifts", out)
    data = json.load(open(os.path.join(ROOT, "data", "gifts.json")))["gifts"]
    folder = os.path.join(ROOT, "art", "gifts")
    done = 0
    for g in data:
        src = os.path.join(out, "sprites", g["id"] + ".png")
        if not os.path.exists(src):
            print("no art for gift", g["id"])
            continue
        shutil.copy(src, os.path.join(folder, g["id"] + ".png"))
        for old in (g["id"] + ".svg", g["id"] + ".svg.import"):
            if os.path.exists(os.path.join(folder, old)):
                os.remove(os.path.join(folder, old))
        done += 1
    print("gifts:", done)


# Where each piece of scenery.px.js goes, and how much it's scaled up.
PROPS = {
    "bush": ("art/walk/bush.png", 1),
    "pumpkin": ("art/holidays/halloween/pumpkin.png", 5),
    "jack_o_lantern": ("art/holidays/halloween/jack_o_lantern.png", 5),
    "egg_pink": ("art/holidays/easter/egg_pink.png", 5),
    "egg_blue": ("art/holidays/easter/egg_blue.png", 5),
    "egg_green": ("art/holidays/easter/egg_green.png", 5),
    "egg_yellow": ("art/holidays/easter/egg_yellow.png", 5),
}


def props(pxl: str) -> None:
    from PIL import Image
    out = tempfile.mkdtemp()
    build(pxl, "scenery", out)
    for name, (dest, k) in PROPS.items():
        im = Image.open(os.path.join(out, "sprites", name + ".png"))
        im.resize((im.width * k, im.height * k), Image.NEAREST).save(os.path.join(ROOT, dest), optimize=True)
    print("scenery:", len(PROPS))


def home(pxl: str) -> None:
    """The home view: each picture scaled up 4x without smoothing, so the
    layers keep their 1600 x 1000 canvas (holiday decorations are laid out
    on it). Halloween's dead forests go beside its look."""
    from PIL import Image
    out = tempfile.mkdtemp()
    build(pxl, "home", out)
    n = 0
    for sub in ("scenes", "sprites"):
        for f in sorted(os.listdir(os.path.join(out, sub))):
            im = Image.open(os.path.join(out, sub, f))
            im = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
            if f.startswith("dead_"):
                dest = os.path.join(ROOT, "art", "holidays", "halloween", "home", f[5:])
            else:
                dest = os.path.join(ROOT, "art", "home", f)
            im.save(dest, optimize=True)
            n += 1
    print("home:", n)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pxl", default=os.environ.get("PXL", ""), help="the claude-pxl checkout")
    ap.add_argument("what", nargs="*", default=["animals", "gifts", "scenery", "home"])
    args = ap.parse_args()
    if not args.pxl:
        raise SystemExit("pass --pxl <claude-pxl folder> (or set PXL)")
    for w in args.what:
        if w == "animals":
            animals(args.pxl)
        elif w == "gifts":
            gifts(args.pxl)
        elif w == "scenery":
            props(args.pxl)
        elif w == "home":
            home(args.pxl)
