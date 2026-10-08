"""BlockRise Empire - 16:9 thumbnails for the game page (2026-10-08): hero objects from the icon pipeline, big 3D headlines,
rendered transparent at 1920 x 1080, then composed on a deep gradient with soft rays (no stars) in `compose`."""
import json, math, os, sys
import numpy as np
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
import bl_build as B
B.load_spec = lambda url=None: json.load(open(os.path.join(HERE, "spec.json"), encoding="utf-8"))
import robux as R, icons as I, icons3 as I3, items as T, postnp
from robux import candy, text

OUT = r"C:\Users\Vlad\BlockRise_thumbnails\Thumbs_2026-10-08"
os.makedirs(OUT, exist_ok=True)


def frame_wide(path, view=(0, -1, 0.22), margin=1.06, aspect=16 / 9):
    bpy.context.view_layer.update()
    pts = []
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            for c in ob.bound_box:
                pts.append(ob.matrix_world @ Vector(c))
    lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    center = (lo + hi) / 2
    d = Vector(view).normalized()
    cam_loc = center + d * 30
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.rotation_euler = (center - cam_loc).normalized().to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for q in pts:
        v = inv @ q
        xs.append(v.x)
        ys.append(v.y)
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    cam.data.ortho_scale = max(w, h * aspect) * margin + I.OUTLINE * 4
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def headline(s, size, loc, col="#ffffff"):
    return text(s, size, 0.22, candy(col, rough=0.25, emit=0.35), loc=loc, rot=(90, 0, 0), bevel=0.03, outline=True, center=True)


def render_wide(name, builder, view=(0, -1, 0.22), margin=1.06, samples=64):
    I3.reset()
    T._M.clear()
    I.OUTLINE = 0.03
    R.GROUPS.clear()
    R.CRATE_O.clear()
    builder()
    I.add_outlines()
    scn = I3.iscene()
    scn.render.resolution_x, scn.render.resolution_y = 1920, 1080
    scn.cycles.samples = samples
    raw = os.path.join(OUT, name + "_raw.png")
    frame_wide(raw, view, margin)
    return raw


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def compose(name, c0, c1, out_name=None, ray_strength=0.16):
    """the raw render over a deep radial gradient (c0 middle, c1 edge) with soft rays and a vignette, 1920 x 1080"""
    raw = postnp.load(os.path.join(OUT, name + "_raw.png"))
    H, W = raw.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = (W - 1) / 2, (H - 1) / 2 + H * 0.06
    d = np.sqrt(((xx - cx) / (W * 0.55)) ** 2 + ((yy - cy) / (H * 0.62)) ** 2)
    t = np.clip(d, 0, 1) ** 1.2
    a, b = _hex(c0), _hex(c1)
    rgb = a[None, None] * (1 - t[..., None]) + b[None, None] * t[..., None]
    ang = np.arctan2(yy - cy, xx - cx)
    rays = (0.5 + 0.5 * np.sin(ang * 14)) ** 6 * np.clip(1 - d * 0.9, 0, 1) * ray_strength
    rgb = np.clip(rgb + rays[..., None] * (a * 0.6 + 0.4), 0, 1)
    vig = np.clip(1 - (d - 0.75) / 0.6, 0, 1)
    rgb = rgb * (0.55 + 0.45 * vig[..., None])
    bg = np.concatenate([rgb, np.ones((H, W, 1), np.float32)], -1)
    # a soft floor shadow under the objects
    sh = np.exp(-(((xx - cx) / (W * 0.33)) ** 2 + ((yy - H * 0.86) / (H * 0.045)) ** 2))[..., None]
    bg[..., :3] *= 1 - sh * 0.4
    out = postnp.over(bg, raw)
    out[..., 3] = 1
    path = os.path.join(OUT, (out_name or name) + ".png")
    postnp.save(out, path)
    return path
