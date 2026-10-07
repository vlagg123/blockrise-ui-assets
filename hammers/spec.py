"""BlockRise Empire - the 15 hammers (tool tiers), as ONE spec used by both builders:
  * Roblox (roblox/HammerForge.lua): the hammer in your hand, made of parts + CSG cuts
  * Blender (hammers/bl_build.py): the same geometry, rendered for the shop tiles and the hotbar icon

Tool space, in studs: origin = your hand (the grip), +Y up the handle, -Z = the striking face (forward),
+Z = the back (claw / spike), X = sideways.

Shapes: box (sx, sy, sz) · cyl (length, radius), axis = local Y · ball (diameter,) · ring (thickness, r_out, r_in), axis = local Y
Every piece may be cut by planes given in its own local frame: keep n . x <= d  (bevels, facets, gem points, spikes).
"""
import json, math, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
R2 = math.sqrt(2)

# ------------------------------------------------------------------------------------------------ math
def Rx(a):
    a = math.radians(a); c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def Ry(a):
    a = math.radians(a); c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def Rz(a):
    a = math.radians(a); c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
I3 = np.eye(3)
# a cylinder / ring / prism whose local Y axis points along tool Z (heads lying along the striking axis)
ALONG_Z = Rx(90)


def unit(v):
    v = np.array(v, dtype=float)
    return v / np.linalg.norm(v)


def plane(n, d):
    n = unit(n)
    return [round(float(n[0]), 5), round(float(n[1]), 5), round(float(n[2]), 5), round(float(d), 5)]


def plane_through(n, p):
    n = unit(n)
    return plane(n, float(np.dot(n, p)))


# ------------------------------------------------------------------------------------------------ cuts
def chamfer(sx, sy, sz, c, edges="xyz"):
    """bevel the 12 edges of a box by c (edges parallel to the listed axes)"""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    out = []
    for a in (-1, 1):
        for b in (-1, 1):
            if "x" in edges: out.append(plane((0, a, b), (hy + hz - c) / R2))
            if "y" in edges: out.append(plane((a, 0, b), (hx + hz - c) / R2))
            if "z" in edges: out.append(plane((a, b, 0), (hx + hy - c) / R2))
    return out


def octagon(w, axis="z", c=None):
    """regular octagon cross-section for a w x w box: chamfer the 4 edges parallel to the axis"""
    c = w * (1 - 1 / R2) if c is None else c
    return chamfer(w, w, w, c, edges=axis)


def hexagon(a, start=0.0):
    """regular hexagon cross-section along local Z (start=0: vertical faces left/right, a ridge on top)"""
    return [plane((math.cos(math.radians(start + 60 * k)), math.sin(math.radians(start + 60 * k)), 0), a) for k in range(6)]


def gem_ends(a, half, tip, sides=8, table=0.35, ends=(1, -1), start=0.0):
    """pointed, faceted ends along local Z for a prism with apothem a and half-length half:
    every side face bends in to a point `tip` long; the point is cut flat (the gem 'table') at `table` of the tip"""
    out = []
    for e in ends:
        z0 = e * (half - tip)
        for k in range(sides):
            t = math.radians(start + k * 360 / sides)
            n = np.array([tip * math.cos(t), tip * math.sin(t), e * a])
            p = np.array([a * math.cos(t), a * math.sin(t), z0])
            out.append(plane_through(n, p))
        out.append(plane((0, 0, e), half - tip * table))
    return out


def spike(w, h, sides=4, start=45.0):
    """a pyramid pointing up local +Y on a w x h x w box (base at -h/2, point at +h/2)"""
    r = w / 2
    out = []
    apex = np.array([0, h / 2, 0])
    for k in range(sides):
        t = math.radians(start + k * 360 / sides)
        n = np.array([h * math.cos(t), r, h * math.sin(t)])
        out.append(plane_through(n, apex))
    return out


def taper(sx, sy, sz, top_scale_x=1.0, top_scale_z=1.0):
    """narrow a box towards its +Y end (prongs, wedges)"""
    out = []
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if top_scale_x < 1:
        dx = hx * (1 - top_scale_x)
        for e in (-1, 1):
            out.append(plane_through((e * 2 * hy, dx, 0), (e * hx, -hy, 0)))
    if top_scale_z < 1:
        dz = hz * (1 - top_scale_z)
        for e in (-1, 1):
            out.append(plane_through((0, dz, e * 2 * hy), (0, -hy, e * hz)))
    return out


def cyl_bevel(length, r, c, ends=(1, -1), n=16):
    """conical bevel on the ends of a cylinder (local Y axis), n facets"""
    out = []
    for e in ends:
        for k in range(n):
            t = 2 * math.pi * k / n
            out.append(plane((math.cos(t), e, math.sin(t)), (r + length / 2 - c) / R2))
    return out


# the classic lightning bolt, as two convex halves that share an edge (u = across, v = up)
BOLT = [
    [(-0.05, 0.25), (0.13, 0.25), (0.04, 0.04), (-0.02, -0.06), (-0.11, -0.06)],
    [(0.04, 0.04), (0.13, 0.04), (-0.08, -0.27), (-0.02, -0.06)],
]


# ------------------------------------------------------------------------------------------------ pieces
class Hammer:
    def __init__(self, tier, key, name, desc):
        self.d = dict(tier=tier, key=key, name=name, desc=desc, pieces=[], fx=[], light=None, trail=None, head=None)

    def add(self, name, shape, size, pos=(0, 0, 0), R=I3, mat="iron", planes=None, smooth=0, cast=True, union=None):
        R = np.array(R, dtype=float)
        d = dict(name=name, shape=shape, size=[round(float(s), 4) for s in size],
                 pos=[round(float(p), 4) for p in pos], R=[[round(float(v), 6) for v in row] for row in R],
                 mat=mat, planes=planes or [], smooth=smooth, cast=cast)
        if union:
            d["union"] = union  # pieces with the same union name become one part in Roblox (no seams)
        self.d["pieces"].append(d)

    def poly(self, name, pts, thick, center, R, mat, scale=1.0, union=None):
        """a flat convex polygon (u = local Z, v = local Y), `thick` deep along local X, as a box cut by its edges"""
        pts = [(u * scale, v * scale) for u, v in pts]
        us, vs = [p[0] for p in pts], [p[1] for p in pts]
        cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
        rel = [(u - cu, v - cv) for u, v in pts]
        n = len(rel)
        area = sum(rel[i][0] * rel[(i + 1) % n][1] - rel[(i + 1) % n][0] * rel[i][1] for i in range(n)) / 2
        planes = []
        for i in range(n):
            u0, v0 = rel[i]
            u1, v1 = rel[(i + 1) % n]
            du, dv = u1 - u0, v1 - v0
            nu, nv = (dv, -du) if area > 0 else (-dv, du)
            planes.append(plane_through((0, nv, nu), (0, v0, u0)))
        R = np.array(R, dtype=float)
        off = R @ np.array([0.0, cv, cu])
        self.add(name, "box", (thick, max(vs) - min(vs), max(us) - min(us)), np.array(center, dtype=float) + off, R=R, mat=mat,
                 planes=planes, cast=False, union=union)

    def bolt(self, name, center, R, scale, mat, rim_mat=None, out=(1, 0, 0)):
        """a lightning bolt (two convex halves, one part in Roblox), with an optional metal rim behind it"""
        center = np.array(center, dtype=float)
        o = np.array(out, dtype=float)
        if rim_mat:
            for j, pts in enumerate(BOLT):
                self.poly("%sRim%d" % (name, j), pts, 0.02, center + o * 0.002, R, rim_mat, scale=scale * 1.22, union=name + "Rim")
        for j, pts in enumerate(BOLT):
            self.poly("%s%d" % (name, j), pts, 0.022, center + o * 0.012, R, mat, scale=scale, union=name)

    # common bits -------------------------------------------------------------------------------
    def shaft(self, y0, y1, r, mat, bevel=0.02):
        L = y1 - y0
        self.add("Shaft", "cyl", (L, r), (0, (y0 + y1) / 2, 0), mat=mat, planes=cyl_bevel(L, r, bevel), smooth=40)

    def band(self, name, y, r, length, mat, R=I3, bevel=0.012):
        self.add(name, "cyl", (length, r), (0, y, 0), R=R, mat=mat, planes=cyl_bevel(length, r, bevel), smooth=40, cast=False)

    def grip(self, y0, y1, r, mat, rings=0, ring_mat=None, ring_r=None):
        L = y1 - y0
        self.add("Grip", "cyl", (L, r), (0, (y0 + y1) / 2, 0), mat=mat, planes=cyl_bevel(L, r, 0.025), smooth=40)
        for i in range(rings):
            y = y0 + L * (i + 1) / (rings + 1)
            self.band("GripRing%d" % i, y, ring_r or (r + 0.006), 0.026, ring_mat or mat)

    def fx(self, kind, pos, colors, rate, size, area=(0.2, 0.2, 0.2), **kw):
        self.d["fx"].append(dict(kind=kind, pos=list(pos), colors=colors, rate=rate, size=size, area=list(area), **kw))

    def light(self, pos, color, brightness, rng):
        self.d["light"] = dict(pos=list(pos), color=color, brightness=brightness, range=rng)

    def trail(self, top, bottom, colors, life=0.22, width=1.0):
        self.d["trail"] = dict(top=list(top), bottom=list(bottom), colors=colors, life=life, width=width)

    def headbox(self, center, size):
        self.d["head"] = dict(center=list(center), size=list(size))


# ------------------------------------------------------------------------------------------------ palette
# rbx: Roblox Material, color, transparency, reflectance · bl: Blender base colour, metallic, roughness,
# transmission, emission strength (+ optional ior / clearcoat)
PALETTE = {
    "rust":      dict(rbx=["CorrodedMetal", [146, 76, 40], 0, 0], bl=dict(color=[0.42, 0.17, 0.06], metal=0.55, rough=0.95, tex="rust")),
    "rust_dark": dict(rbx=["CorrodedMetal", [96, 54, 34], 0, 0], bl=dict(color=[0.22, 0.10, 0.05], metal=0.5, rough=0.95, tex="rust")),
    "old_wood":  dict(rbx=["Wood", [112, 86, 62], 0, 0], bl=dict(color=[0.25, 0.16, 0.09], metal=0, rough=0.9, tex="wood")),
    "tape":      dict(rbx=["Fabric", [150, 152, 158], 0, 0], bl=dict(color=[0.45, 0.45, 0.47], metal=0, rough=0.7)),
    "crack":     dict(rbx=["SmoothPlastic", [32, 22, 16], 0, 0], bl=dict(color=[0.02, 0.012, 0.008], metal=0, rough=0.9)),
    "wood":      dict(rbx=["Wood", [186, 132, 84], 0, 0], bl=dict(color=[0.55, 0.30, 0.12], metal=0, rough=0.6, tex="wood")),
    "leather":   dict(rbx=["Fabric", [96, 58, 34], 0, 0], bl=dict(color=[0.20, 0.09, 0.04], metal=0, rough=0.65)),
    "iron":      dict(rbx=["Metal", [92, 96, 108], 0, 0], bl=dict(color=[0.20, 0.21, 0.24], metal=1, rough=0.45)),
    "iron_lt":   dict(rbx=["Metal", [128, 132, 144], 0, 0], bl=dict(color=[0.34, 0.35, 0.39], metal=1, rough=0.35)),
    "steel":     dict(rbx=["Metal", [206, 212, 224], 0, 0.15], bl=dict(color=[0.70, 0.72, 0.77], metal=1, rough=0.18)),
    "steel_dk":  dict(rbx=["Metal", [150, 156, 170], 0, 0.1], bl=dict(color=[0.42, 0.44, 0.50], metal=1, rough=0.25)),
    "rubber_bl": dict(rbx=["Rubber", [36, 104, 220], 0, 0], bl=dict(color=[0.02, 0.15, 0.75], metal=0, rough=0.55)),
    "rubber_dk": dict(rbx=["Rubber", [22, 52, 120], 0, 0], bl=dict(color=[0.01, 0.04, 0.22], metal=0, rough=0.6)),
    "red":       dict(rbx=["SmoothPlastic", [226, 46, 52], 0, 0], bl=dict(color=[0.80, 0.03, 0.04], metal=0, rough=0.3)),
    "gold":      dict(rbx=["Metal", [255, 186, 40], 0, 0.18], bl=dict(color=[1.0, 0.62, 0.12], metal=1, rough=0.16)),
    "gold_dk":   dict(rbx=["Metal", [204, 138, 30], 0, 0.15], bl=dict(color=[0.62, 0.30, 0.04], metal=1, rough=0.25)),
    "gold_lt":   dict(rbx=["Metal", [255, 220, 120], 0, 0.2], bl=dict(color=[1.0, 0.86, 0.45], metal=1, rough=0.12)),
    "black_lth": dict(rbx=["Fabric", [32, 30, 38], 0, 0], bl=dict(color=[0.018, 0.016, 0.022], metal=0, rough=0.55)),
    "titan":     dict(rbx=["Metal", [168, 180, 198], 0, 0.12], bl=dict(color=[0.45, 0.50, 0.58], metal=1, rough=0.28)),
    "plate":     dict(rbx=["DiamondPlate", [150, 156, 172], 0, 0.05], bl=dict(color=[0.40, 0.42, 0.47], metal=1, rough=0.3, tex="plate")),
    "orange":    dict(rbx=["SmoothPlastic", [255, 124, 26], 0, 0], bl=dict(color=[1.0, 0.25, 0.01], metal=0, rough=0.3)),
    "carbon":    dict(rbx=["SmoothPlastic", [34, 36, 44], 0, 0.05], bl=dict(color=[0.015, 0.016, 0.02], metal=0.3, rough=0.25)),
    "emerald":   dict(rbx=["Glass", [0, 170, 75], 0.38, 0.2], core=[40, 255, 140, 0.55], bl=dict(color=[0.02, 0.75, 0.25], metal=0, rough=0.02, trans=1.0, ior=1.58, emit=0.15)),
    "green_lth": dict(rbx=["Fabric", [20, 82, 52], 0, 0], bl=dict(color=[0.01, 0.10, 0.04], metal=0, rough=0.6)),
    "platinum":  dict(rbx=["Metal", [200, 206, 222], 0, 0.22], bl=dict(color=[0.80, 0.82, 0.86], metal=1, rough=0.12)),
    "ruby":      dict(rbx=["Glass", [205, 0, 40], 0.35, 0.2], core=[255, 70, 100, 0.55], bl=dict(color=[0.85, 0.01, 0.06], metal=0, rough=0.02, trans=1.0, ior=1.76, emit=0.18)),
    "red_lth":   dict(rbx=["Fabric", [120, 18, 32], 0, 0], bl=dict(color=[0.22, 0.005, 0.02], metal=0, rough=0.6)),
    "sapphire":  dict(rbx=["Glass", [10, 60, 230], 0.35, 0.2], core=[80, 150, 255, 0.55], bl=dict(color=[0.02, 0.10, 0.95], metal=0, rough=0.02, trans=1.0, ior=1.76, emit=0.18)),
    "navy_lth":  dict(rbx=["Fabric", [26, 36, 96], 0, 0], bl=dict(color=[0.01, 0.02, 0.12], metal=0, rough=0.6)),
    "amethyst":  dict(rbx=["Glass", [125, 40, 230], 0.35, 0.2], core=[195, 120, 255, 0.55], bl=dict(color=[0.45, 0.10, 0.95], metal=0, rough=0.03, trans=1.0, ior=1.55, emit=0.22)),
    "obsidian":  dict(rbx=["Slate", [40, 30, 56], 0, 0.05], bl=dict(color=[0.03, 0.02, 0.05], metal=0.2, rough=0.35)),
    "neon_purple": dict(rbx=["Neon", [176, 90, 255], 0, 0], bl=dict(color=[0.45, 0.12, 1.0], metal=0, rough=0.4, emit=6.0)),
    "basalt":    dict(rbx=["Basalt", [36, 30, 30], 0, 0], bl=dict(color=[0.018, 0.014, 0.014], metal=0, rough=0.8, tex="rock")),
    "lava":      dict(rbx=["Neon", [255, 112, 20], 0, 0], bl=dict(color=[1.0, 0.25, 0.02], metal=0, rough=0.5, emit=9.0)),
    "lava_hot":  dict(rbx=["Neon", [255, 196, 70], 0, 0], bl=dict(color=[1.0, 0.62, 0.15], metal=0, rough=0.5, emit=12.0)),
    "ice":       dict(rbx=["Ice", [176, 226, 255], 0.05, 0.1], bl=dict(color=[0.55, 0.82, 1.0], metal=0, rough=0.08, trans=0.85, ior=1.31, emit=0.1)),
    "icicle":    dict(rbx=["Glass", [176, 226, 255], 0.1, 0.3], bl=dict(color=[0.75, 0.93, 1.0], metal=0, rough=0.02, trans=1.0, ior=1.31)),
    "frost_neon": dict(rbx=["Neon", [120, 230, 255], 0, 0], bl=dict(color=[0.25, 0.85, 1.0], metal=0, rough=0.4, emit=6.0)),
    "silver":    dict(rbx=["Metal", [214, 230, 244], 0, 0.22], bl=dict(color=[0.72, 0.80, 0.88], metal=1, rough=0.15)),
    "ice_lth":   dict(rbx=["Fabric", [120, 186, 250], 0, 0], bl=dict(color=[0.18, 0.48, 0.95], metal=0, rough=0.6)),
    "diamond":   dict(rbx=["Glass", [185, 236, 255], 0.35, 0.45], core=[230, 250, 255, 0.7], bl=dict(color=[0.92, 0.98, 1.0], metal=0, rough=0.0, trans=1.0, ior=2.42, emit=0.05, disp=0.08)),
    "white_lth": dict(rbx=["Fabric", [236, 238, 246], 0, 0], bl=dict(color=[0.80, 0.82, 0.88], metal=0, rough=0.6)),
    "gunmetal":  dict(rbx=["Metal", [52, 56, 70], 0, 0.15], bl=dict(color=[0.05, 0.055, 0.07], metal=1, rough=0.25)),
    "plasma":    dict(rbx=["Glass", [40, 190, 255], 0.35, 0.2], bl=dict(color=[0.1, 0.8, 1.0], metal=0, rough=0.2, trans=0.6, emit=2.5)),
    "plasma_core": dict(rbx=["Neon", [40, 200, 255], 0, 0], bl=dict(color=[0.55, 0.95, 1.0], metal=0, rough=0.4, emit=14.0)),
    "cyan_neon": dict(rbx=["Neon", [60, 220, 255], 0, 0], bl=dict(color=[0.1, 0.8, 1.0], metal=0, rough=0.4, emit=7.0)),
    "black_rub": dict(rbx=["Rubber", [26, 28, 34], 0, 0], bl=dict(color=[0.012, 0.013, 0.016], metal=0, rough=0.6)),
    "sun":       dict(rbx=["Neon", [255, 138, 20], 0, 0], bl=dict(color=[1.0, 0.45, 0.03], metal=0, rough=0.5, emit=10.0)),
    "sun_hot":   dict(rbx=["Neon", [255, 196, 70], 0, 0], bl=dict(color=[1.0, 0.85, 0.45], metal=0, rough=0.5, emit=14.0)),
    "cosmos":    dict(rbx=["SmoothPlastic", [255, 255, 255], 0, 0], bl=dict(color=[0.01, 0.005, 0.03], metal=0, rough=0.4, tex="galaxy", emit=2.0)),
    "cosmic_glass": dict(rbx=["Glass", [150, 110, 255], 0.6, 0.3], bl=dict(color=[0.55, 0.35, 1.0], metal=0, rough=0.0, trans=1.0, ior=1.45, alpha=0.35)),
    "pink_neon": dict(rbx=["Neon", [255, 120, 236], 0, 0], bl=dict(color=[1.0, 0.25, 0.85], metal=0, rough=0.4, emit=7.0)),
    "stormstone": dict(rbx=["Slate", [72, 84, 108], 0, 0.05], bl=dict(color=[0.07, 0.09, 0.14], metal=0.2, rough=0.45, tex="rock")),
    "stormwood": dict(rbx=["Wood", [70, 62, 72], 0, 0], bl=dict(color=[0.09, 0.07, 0.08], metal=0, rough=0.6, tex="wood")),
    "storm_lth": dict(rbx=["Fabric", [64, 78, 104], 0, 0], bl=dict(color=[0.06, 0.08, 0.14], metal=0, rough=0.6)),
    "storm_neon": dict(rbx=["Neon", [80, 176, 255], 0, 0], bl=dict(color=[0.15, 0.55, 1.0], metal=0, rough=0.4, emit=8.0)),
    "storm_crystal": dict(rbx=["Glass", [100, 185, 255], 0.3, 0.3], core=[160, 220, 255, 0.6], bl=dict(color=[0.5, 0.8, 1.0], metal=0, rough=0.02, trans=1.0, ior=1.5, emit=0.4)),
    "void":      dict(rbx=["SmoothPlastic", [26, 18, 44], 0, 0.05], bl=dict(color=[0.015, 0.008, 0.035], metal=0.2, rough=0.3)),
    "star":      dict(rbx=["Neon", [255, 250, 230], 0, 0], bl=dict(color=[1.0, 0.98, 0.9], metal=0, rough=0.4, emit=12.0)),
    # ---- the 24 hammers added in October 2026 ----
    "oak":       dict(rbx=["Wood", [214, 168, 108], 0, 0], bl=dict(color=[0.66, 0.40, 0.16], metal=0, rough=0.55, tex="wood")),
    "oak_end":   dict(rbx=["Wood", [168, 118, 70], 0, 0], bl=dict(color=[0.40, 0.21, 0.08], metal=0, rough=0.7, tex="wood")),
    "brass":     dict(rbx=["Metal", [226, 178, 74], 0, 0.15], bl=dict(color=[0.86, 0.56, 0.16], metal=1, rough=0.22)),
    "brick":     dict(rbx=["Brick", [184, 78, 54], 0, 0], bl=dict(color=[0.48, 0.09, 0.04], metal=0, rough=0.9, tex="rock")),
    "mortar":    dict(rbx=["Concrete", [206, 200, 188], 0, 0], bl=dict(color=[0.62, 0.58, 0.52], metal=0, rough=0.95)),
    "hole":      dict(rbx=["SmoothPlastic", [62, 26, 20], 0, 0], bl=dict(color=[0.04, 0.012, 0.008], metal=0, rough=0.9)),
    "fiber_yel": dict(rbx=["SmoothPlastic", [255, 204, 36], 0, 0.05], bl=dict(color=[1.0, 0.6, 0.02], metal=0, rough=0.3)),
    "copper":    dict(rbx=["Metal", [222, 120, 66], 0, 0.2], bl=dict(color=[0.9, 0.32, 0.12], metal=1, rough=0.16)),
    "copper_dk": dict(rbx=["Metal", [170, 84, 46], 0, 0.1], bl=dict(color=[0.5, 0.15, 0.05], metal=1, rough=0.3)),
    "patina":    dict(rbx=["Slate", [92, 186, 156], 0, 0], bl=dict(color=[0.12, 0.52, 0.38], metal=0, rough=0.75)),
    "neon_mag":  dict(rbx=["Neon", [255, 64, 200], 0, 0], bl=dict(color=[1.0, 0.08, 0.6], metal=0, rough=0.4, emit=7.0)),
    "neon_lime": dict(rbx=["Neon", [150, 255, 70], 0, 0], bl=dict(color=[0.35, 1.0, 0.08], metal=0, rough=0.4, emit=7.0)),
    "tb_red":    dict(rbx=["Metal", [220, 40, 44], 0, 0.05], bl=dict(color=[0.72, 0.02, 0.02], metal=0.5, rough=0.3)),
    "tb_dark":   dict(rbx=["Metal", [70, 20, 22], 0, 0], bl=dict(color=[0.08, 0.005, 0.005], metal=0.5, rough=0.4)),
    "bronze":    dict(rbx=["Metal", [198, 130, 66], 0, 0.1], bl=dict(color=[0.58, 0.28, 0.08], metal=1, rough=0.32)),
    "bronze_dk": dict(rbx=["Metal", [128, 80, 40], 0, 0], bl=dict(color=[0.25, 0.1, 0.03], metal=1, rough=0.45)),
    "dark_wood": dict(rbx=["Wood", [86, 56, 38], 0, 0], bl=dict(color=[0.12, 0.055, 0.025], metal=0, rough=0.6, tex="wood")),
    "cord":      dict(rbx=["Fabric", [206, 176, 120], 0, 0], bl=dict(color=[0.6, 0.43, 0.2], metal=0, rough=0.8)),
    "obsid_glass": dict(rbx=["Glass", [34, 24, 44], 0, 0.3], bl=dict(color=[0.012, 0.008, 0.016], metal=0.2, rough=0.06)),
    "ember":     dict(rbx=["Neon", [255, 54, 30], 0, 0], bl=dict(color=[1.0, 0.06, 0.02], metal=0, rough=0.4, emit=9.0)),
    "charcoal":  dict(rbx=["SmoothPlastic", [52, 50, 56], 0, 0], bl=dict(color=[0.03, 0.028, 0.034], metal=0, rough=0.6)),
    "jade":      dict(rbx=["Glass", [30, 160, 90], 0.22, 0.15], core=[90, 230, 150, 0.65], bl=dict(color=[0.05, 0.5, 0.2], metal=0, rough=0.12, trans=0.45, ior=1.6, emit=0.12)),
    "lacquer":   dict(rbx=["SmoothPlastic", [32, 22, 24], 0, 0.15], bl=dict(color=[0.015, 0.008, 0.009], metal=0, rough=0.15)),
    "silk_red":  dict(rbx=["Fabric", [200, 30, 40], 0, 0], bl=dict(color=[0.6, 0.01, 0.02], metal=0, rough=0.6)),
    "candy_pink": dict(rbx=["SmoothPlastic", [255, 112, 182], 0, 0.05], bl=dict(color=[1.0, 0.17, 0.48], metal=0, rough=0.2)),
    "candy_white": dict(rbx=["SmoothPlastic", [255, 246, 250], 0, 0.05], bl=dict(color=[1.0, 0.93, 0.96], metal=0, rough=0.2)),
    "candy_red": dict(rbx=["SmoothPlastic", [236, 36, 58], 0, 0.05], bl=dict(color=[0.84, 0.02, 0.04], metal=0, rough=0.2)),
    "sprinkle_b": dict(rbx=["SmoothPlastic", [70, 170, 255], 0, 0], bl=dict(color=[0.06, 0.4, 1.0], metal=0, rough=0.3)),
    "sprinkle_y": dict(rbx=["SmoothPlastic", [255, 220, 50], 0, 0], bl=dict(color=[1.0, 0.72, 0.03], metal=0, rough=0.3)),
    "sprinkle_g": dict(rbx=["SmoothPlastic", [90, 220, 120], 0, 0], bl=dict(color=[0.1, 0.72, 0.19], metal=0, rough=0.3)),
    "bone":      dict(rbx=["SmoothPlastic", [246, 238, 214], 0, 0.05], bl=dict(color=[0.92, 0.85, 0.66], metal=0, rough=0.35)),
    "scale_red": dict(rbx=["Slate", [168, 26, 34], 0, 0], bl=dict(color=[0.4, 0.01, 0.015], metal=0, rough=0.45)),
    "scale_blk": dict(rbx=["Slate", [34, 26, 30], 0, 0], bl=dict(color=[0.016, 0.01, 0.012], metal=0, rough=0.5)),
    "glass_dome": dict(rbx=["Glass", [205, 232, 255], 0.55, 0.2], bl=dict(color=[0.85, 0.93, 1.0], metal=0, rough=0.02, trans=1.0, ior=1.45, alpha=0.25)),
    "walnut":    dict(rbx=["Wood", [110, 66, 40], 0, 0], bl=dict(color=[0.16, 0.06, 0.022], metal=0, rough=0.5, tex="wood")),
    "robo_white": dict(rbx=["SmoothPlastic", [242, 246, 252], 0, 0.05], bl=dict(color=[0.88, 0.92, 0.97], metal=0, rough=0.25)),
    "robo_blue": dict(rbx=["SmoothPlastic", [40, 120, 255], 0, 0], bl=dict(color=[0.02, 0.19, 1.0], metal=0, rough=0.3)),
    "led_blue":  dict(rbx=["Neon", [70, 190, 255], 0, 0], bl=dict(color=[0.06, 0.5, 1.0], metal=0, rough=0.4, emit=9.0)),
    "chrome":    dict(rbx=["Metal", [232, 238, 246], 0, 0.35], bl=dict(color=[0.85, 0.88, 0.92], metal=1, rough=0.06)),
    "red_led":   dict(rbx=["Neon", [255, 60, 60], 0, 0], bl=dict(color=[1.0, 0.05, 0.05], metal=0, rough=0.4, emit=8.0)),
    "flame":     dict(rbx=["Neon", [255, 128, 30], 0, 0], bl=dict(color=[1.0, 0.22, 0.01], metal=0, rough=0.4, emit=8.0)),
    "flame_red": dict(rbx=["Neon", [255, 64, 30], 0, 0], bl=dict(color=[1.0, 0.05, 0.01], metal=0, rough=0.4, emit=8.0)),
    "white_gold": dict(rbx=["Metal", [255, 238, 196], 0, 0.2], bl=dict(color=[1.0, 0.85, 0.55], metal=1, rough=0.15)),
    "water_deep": dict(rbx=["Glass", [20, 70, 190], 0.1, 0.2], bl=dict(color=[0.006, 0.07, 0.42], metal=0, rough=0.04, trans=0.8, ior=1.33, emit=0.15)),
    "bone_dk":   dict(rbx=["SmoothPlastic", [196, 182, 150], 0, 0], bl=dict(color=[0.55, 0.47, 0.3], metal=0, rough=0.45)),
    "water":     dict(rbx=["Glass", [36, 120, 236], 0.15, 0.2], bl=dict(color=[0.02, 0.18, 0.82], metal=0, rough=0.03, trans=0.85, ior=1.33, emit=0.25)),
    "foam":      dict(rbx=["SmoothPlastic", [240, 250, 255], 0, 0], bl=dict(color=[0.88, 0.95, 1.0], metal=0, rough=0.5, emit=0.15)),
    "driftwood": dict(rbx=["Wood", [176, 160, 138], 0, 0], bl=dict(color=[0.43, 0.36, 0.27], metal=0, rough=0.85, tex="wood")),
    "matte_blk": dict(rbx=["SmoothPlastic", [26, 28, 34], 0, 0], bl=dict(color=[0.01, 0.011, 0.014], metal=0.3, rough=0.5)),
    "hexplate":  dict(rbx=["Metal", [60, 66, 80], 0, 0.1], bl=dict(color=[0.045, 0.05, 0.065], metal=1, rough=0.35)),
    "void_black": dict(rbx=["SmoothPlastic", [6, 4, 10], 0, 0], bl=dict(color=[0.0, 0.0, 0.0], metal=0, rough=1.0, flat=True)),
    "void_purple": dict(rbx=["Fabric", [56, 26, 84], 0, 0], bl=dict(color=[0.04, 0.008, 0.09], metal=0, rough=0.6)),
    "accretion": dict(rbx=["Neon", [255, 150, 50], 0, 0], bl=dict(color=[1.0, 0.32, 0.03], metal=0, rough=0.4, emit=11.0)),
    "accretion_hot": dict(rbx=["Neon", [255, 236, 190], 0, 0], bl=dict(color=[1.0, 0.85, 0.55], metal=0, rough=0.4, emit=14.0)),
    "crimson":   dict(rbx=["Slate", [118, 12, 22], 0, 0.05], bl=dict(color=[0.11, 0.0, 0.004], metal=0.3, rough=0.35)),
    "horn":      dict(rbx=["SmoothPlastic", [28, 22, 26], 0, 0.1], bl=dict(color=[0.012, 0.008, 0.01], metal=0, rough=0.3)),
    "chain":     dict(rbx=["Metal", [120, 124, 134], 0, 0.1], bl=dict(color=[0.22, 0.23, 0.26], metal=1, rough=0.35)),
    "marble":    dict(rbx=["Marble", [246, 244, 238], 0, 0], bl=dict(color=[0.9, 0.88, 0.84], metal=0, rough=0.25)),
    "halo":      dict(rbx=["Neon", [255, 224, 130], 0, 0], bl=dict(color=[1.0, 0.75, 0.25], metal=0, rough=0.4, emit=10.0)),
    "ivory":     dict(rbx=["SmoothPlastic", [244, 236, 214], 0, 0], bl=dict(color=[0.9, 0.83, 0.67], metal=0, rough=0.3)),
    "velvet":    dict(rbx=["Fabric", [160, 16, 40], 0, 0], bl=dict(color=[0.35, 0.003, 0.02], metal=0, rough=0.85)),
    "ghost":     dict(rbx=["Glass", [190, 246, 255], 0.35, 0.1], bl=dict(color=[0.5, 0.92, 1.0], metal=0, rough=0.2, alpha=0.6, emit=0.8)),
    "ghost_eye": dict(rbx=["SmoothPlastic", [20, 34, 52], 0, 0], bl=dict(color=[0.006, 0.016, 0.035], metal=0, rough=0.3)),
    "ghost_handle": dict(rbx=["Glass", [150, 220, 240], 0.45, 0.1], bl=dict(color=[0.3, 0.72, 0.86], metal=0, rough=0.15, alpha=0.55, emit=0.4)),
    "prism_glass": dict(rbx=["Glass", [236, 246, 255], 0.3, 0.25], bl=dict(color=[0.95, 0.97, 1.0], metal=0, rough=0.0, trans=1.0, ior=1.52)),
    "rb_red":    dict(rbx=["Neon", [255, 50, 60], 0, 0], bl=dict(color=[1.0, 0.03, 0.04], metal=0, rough=0.4, emit=8.0)),
    "rb_orange": dict(rbx=["Neon", [255, 150, 40], 0, 0], bl=dict(color=[1.0, 0.3, 0.02], metal=0, rough=0.4, emit=8.0)),
    "rb_yellow": dict(rbx=["Neon", [255, 236, 60], 0, 0], bl=dict(color=[1.0, 0.84, 0.04], metal=0, rough=0.4, emit=8.0)),
    "rb_green":  dict(rbx=["Neon", [70, 240, 100], 0, 0], bl=dict(color=[0.06, 0.87, 0.13], metal=0, rough=0.4, emit=8.0)),
    "rb_blue":   dict(rbx=["Neon", [60, 140, 255], 0, 0], bl=dict(color=[0.05, 0.26, 1.0], metal=0, rough=0.4, emit=8.0)),
    "rb_violet": dict(rbx=["Neon", [170, 80, 255], 0, 0], bl=dict(color=[0.4, 0.08, 1.0], metal=0, rough=0.4, emit=8.0)),
    "beam_white": dict(rbx=["Neon", [255, 255, 255], 0, 0], bl=dict(color=[1.0, 1.0, 1.0], metal=0, rough=0.4, emit=12.0)),
    "navy":      dict(rbx=["SmoothPlastic", [26, 36, 92], 0, 0.1], bl=dict(color=[0.01, 0.018, 0.1], metal=0.3, rough=0.3)),
}

# ------------------------------------------------------------------------------------------------ the hammers
def claw(h, y, z, prong_len, mat, w=0.085, gap=0.06, droop=38, broken=False):
    """the two curved prongs of a claw hammer, leaving the back of the head and bending down"""
    for i, x in enumerate((-gap, gap)):
        L = prong_len * (0.62 if (broken and i == 0) else 1.0)
        # root segment: leaves the head straight back
        h.add("Claw%dA" % i, "box", (w, 0.13, L * 0.55), (x, y + 0.01, z + L * 0.25), R=Rx(-droop * 0.35), mat=mat,
              planes=chamfer(w, 0.13, L * 0.55, 0.02))
        # tip segment: bends down to a point
        tip = L * 0.55
        R = Rx(-droop) @ (Ry(9 if (broken and i == 0) else 0))
        p = np.array([x, y - 0.035, z + L * 0.5]) + R @ np.array([0, 0, tip * 0.45])
        planes = chamfer(w, 0.11, tip, 0.018) + [plane_through((0, 1, 0.55), (0, 0.0, tip / 2))]
        h.add("Claw%dB" % i, "box", (w, 0.11, tip), p, R=R, mat=mat, planes=planes)


ALONG_X = Rz(-90)  # local Y -> tool +X (discs and rings that face sideways)


def rot_axis(axis, deg):
    """rotation of deg degrees about an axis (Rodrigues)"""
    k = unit(axis)
    a = math.radians(deg)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return I3 + math.sin(a) * K + (1 - math.cos(a)) * (K @ K)


def toward(d, twist=0.0):
    """rotation taking local +Y onto direction d (then a twist about it)"""
    d = unit(d)
    up = np.array([0.0, 1.0, 0.0])
    v = np.cross(up, d)
    s, c = np.linalg.norm(v), float(np.dot(up, d))
    if s < 1e-6:
        R = I3 if c > 0 else Rx(180)
    else:
        vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
        R = I3 + vx + vx @ vx * ((1 - c) / s ** 2)
    return R @ Ry(twist)


def chain(h, name, start, d0, axis, segs, mat, tip=True, tip_frac=0.6, joints=None):
    """a curved horn / fang / wisp: octagonal segments (length, width, bend in degrees after it) from start along d0,
    bending about axis; the last one ends in a point. Returns the tip (joints: a list that gets every joint)."""
    p = np.array(start, dtype=float)
    d = unit(d0)
    for i, (L, w, bend) in enumerate(segs):
        if joints is not None:
            joints.append(p.copy())
        planes = octagon(w, "y")
        if tip and i == len(segs) - 1:
            planes = planes + _shard_tip(w, L, tip_frac=tip_frac)
        h.add("%s%d" % (name, i), "box", (w, L, w), p + d * L / 2, R=toward(d), mat=mat, planes=planes)
        p = p + d * L * (1.0 if i == len(segs) - 1 else 0.86)
        d = rot_axis(axis, bend) @ d
    return p


def blade_tip(L, W, tl=None):
    """a pointed +Y end on a flat blade (thin along local X, W wide along local Z)"""
    tl = tl or W * 0.9
    return [plane_through((0, W / 2, tl), (0, L / 2 - tl, W / 2)), plane_through((0, W / 2, -tl), (0, L / 2 - tl, -W / 2))]


def feather(h, name, base, d, L, W, T, mat, x=0.0):
    """a flat feather / flame from base along d (in the YZ plane), its flat side facing sideways"""
    d = unit(d)
    c = np.array(base, dtype=float) + d * L / 2 + np.array([x, 0, 0])
    h.add(name, "box", (T, L, W), c, R=toward(d), mat=mat, planes=blade_tip(L, W) + chamfer(T, L, W, min(T, W) * 0.3, edges="y"), cast=False)


def gear(h, name, center, r, thick, teeth, mat, phase=0.0, hub="steel_dk"):
    """a cog facing sideways (axis X): a disc and its teeth as one part"""
    center = np.array(center, dtype=float)
    h.add(name, "cyl", (thick, r), center, R=ALONG_X, mat=mat, smooth=40, cast=False, union=name)
    for k in range(teeth):
        a = math.radians(phase + k * 360 / teeth)
        dv = np.array([0, math.cos(a), math.sin(a)])
        h.add("%sT%d" % (name, k), "box", (thick, r * 0.36, r * 0.32), center + dv * r * 0.98, R=toward(dv), mat=mat,
              planes=taper(thick, r * 0.36, r * 0.32, top_scale_z=0.6), cast=False, union=name)
    h.add(name + "Hub", "cyl", (thick * 1.5, r * 0.3), center, R=ALONG_X, mat=hub, smooth=40, cast=False)


def face_cracks(h, hp, apothem, cracks, mat, prefix="Crack"):
    """glowing cracks lying on the faces of a prism along Z: (face angle in the XY plane, z, turn on the face, length)"""
    for i, (t, z, ang, ln) in enumerate(cracks):
        n = np.array([math.cos(math.radians(t)), math.sin(math.radians(t)), 0.0])
        R = Rz(t - 90) @ Ry(ang)
        h.add("%s%d" % (prefix, i), "box", (0.04, 0.03, ln), np.array(hp) + n * (apothem + 0.004) + np.array([0, 0, z]), R=R, mat=mat, cast=False)


def build():
    H = []

    # 1 ----------------------------------------------------------------------------------- RUSTY
    h = Hammer(1, "rusty", "Rusty Hammer", "Old, bent and held together with tape. It works. Mostly.")
    hy = 1.52
    crook = Rx(6) @ Rz(-5)
    h.shaft(-0.46, hy - 0.06, 0.098, "old_wood", bevel=0.03)
    h.add("Crack", "box", (0.014, 0.62, 0.05), (0.093, 0.7, 0.0), R=Rz(4), mat="crack", cast=False)
    h.add("Crack2", "box", (0.05, 0.3, 0.012), (0.0, 0.05, -0.093), R=Rx(-3), mat="crack", cast=False)
    h.band("Tape1", 0.40, 0.111, 0.17, "tape", R=Rz(7))
    h.band("Tape2", 1.08, 0.108, 0.11, "tape", R=Rz(-6) @ Rx(4))
    hp = np.array([0.0, hy, -0.02])
    hs = (0.30, 0.30, 0.88)
    chip = [plane((0, 1, -1), (0.15 + 0.44 - 0.11) / R2), plane((-1, -1, 1), (0.15 + 0.15 + 0.44 - 0.1) / math.sqrt(3))]
    h.add("Head", "box", hs, hp, R=crook, mat="rust", planes=chamfer(*hs, 0.03) + chip)
    h.add("Face", "cyl", (0.10, 0.152), hp + crook @ np.array([0.01, -0.01, -0.48]), R=crook @ ALONG_Z @ Rz(3), mat="rust_dark",
          planes=cyl_bevel(0.10, 0.152, 0.02), smooth=40)
    claw(h, hp[1] + 0.03, hp[2] + 0.40, 0.48, "rust_dark", w=0.075, gap=0.055, droop=46, broken=True)
    h.headbox(hp, (0.32, 0.4, 1.4))
    h.fx("flakes", hp, [[150, 80, 40], [100, 56, 34]], 1.4, [0.035, 0.06], area=(0.3, 0.2, 0.8))
    H.append(h)

    # 2 ----------------------------------------------------------------------------------- IRON
    h = Hammer(2, "iron", "Iron Hammer", "Solid iron, honest wood. A real builder's hammer.")
    hy = 1.6
    h.shaft(-0.42, hy - 0.05, 0.104, "wood")
    h.grip(-0.38, 0.32, 0.118, "leather", rings=2, ring_mat="iron")
    h.add("Pommel", "cyl", (0.09, 0.124), (0, -0.46, 0), mat="iron", planes=cyl_bevel(0.09, 0.124, 0.03), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    hs = (0.34, 0.34, 0.96)
    h.add("Head", "box", hs, hp, mat="iron", planes=chamfer(*hs, 0.05))
    h.add("Wedge", "box", (0.05, 0.03, 0.22), hp + [0, 0.17, 0.02], mat="iron_lt", planes=chamfer(0.05, 0.03, 0.22, 0.012), cast=False)
    h.add("Face", "cyl", (0.14, 0.18), hp + [0, 0, -0.53], R=ALONG_Z, mat="iron_lt", planes=cyl_bevel(0.14, 0.18, 0.035), smooth=40)
    claw(h, hp[1] + 0.03, hp[2] + 0.42, 0.5, "iron", w=0.085, gap=0.06, droop=40)
    h.headbox(hp, (0.36, 0.4, 1.5))
    H.append(h)

    # 3 ----------------------------------------------------------------------------------- STEEL
    h = Hammer(3, "steel", "Steel Hammer", "Polished steel with a comfy rubber grip.")
    hy = 1.66
    h.shaft(-0.44, hy - 0.05, 0.1, "steel")
    h.grip(-0.40, 0.34, 0.124, "rubber_bl", rings=3, ring_mat="rubber_dk", ring_r=0.128)
    h.add("Pommel", "cyl", (0.12, 0.132), (0, -0.48, 0), mat="rubber_dk", planes=cyl_bevel(0.12, 0.132, 0.045), smooth=40)
    h.band("Accent", 0.52, 0.112, 0.06, "red")
    hp = np.array([0.0, hy, 0.0])
    hs = (0.36, 0.38, 1.02)
    h.add("Head", "box", hs, hp, mat="steel", planes=chamfer(*hs, 0.07))
    h.add("Neck", "box", (0.30, 0.10, 0.30), hp + [0, -0.22, 0], mat="steel_dk", planes=chamfer(0.30, 0.10, 0.30, 0.04))
    h.add("Face", "cyl", (0.16, 0.2), hp + [0, 0, -0.57], R=ALONG_Z, mat="steel", planes=cyl_bevel(0.16, 0.2, 0.04), smooth=40)
    claw(h, hp[1] + 0.04, hp[2] + 0.45, 0.54, "steel", w=0.09, gap=0.065, droop=40)
    h.headbox(hp, (0.4, 0.45, 1.6))
    H.append(h)

    # 4 ----------------------------------------------------------------------------------- GOLD
    h = Hammer(4, "gold", "Golden Hammer", "Solid gold. Every hit shines.")
    hy = 1.74
    h.shaft(-0.46, hy - 0.05, 0.106, "black_lth")
    for i, y in enumerate((-0.38, 0.36, 1.02)):
        h.band("Ring%d" % i, y, 0.122, 0.06, "gold")
    h.add("Pommel", "ball", (0.27,), (0, -0.55, 0), mat="gold", smooth=0)
    h.band("PommelCollar", -0.45, 0.115, 0.07, "gold_dk")
    hp = np.array([0.0, hy, 0.0])
    hs = (0.40, 0.42, 1.10)
    h.add("Head", "box", hs, hp, mat="gold", planes=chamfer(*hs, 0.09))
    for i, z in enumerate((-0.27, 0.27)):
        h.add("Engrave%d" % i, "box", (0.42, 0.44, 0.045), hp + [0, 0, z], mat="gold_dk", planes=chamfer(0.42, 0.44, 0.045, 0.09, edges="z"), cast=False)
    h.add("Face", "cyl", (0.18, 0.22), hp + [0, 0, -0.62], R=ALONG_Z, mat="gold_lt", planes=cyl_bevel(0.18, 0.22, 0.045), smooth=40)
    claw(h, hp[1] + 0.04, hp[2] + 0.48, 0.58, "gold", w=0.095, gap=0.07, droop=40)
    h.headbox(hp, (0.44, 0.5, 1.7))
    h.fx("glint", hp, [[255, 236, 150], [255, 255, 255]], 2.5, [0.1, 0.22], area=(0.42, 0.44, 1.1))
    H.append(h)

    # 5 ----------------------------------------------------------------------------------- TITANIUM SLEDGE
    h = Hammer(5, "titanium", "Titanium Sledge", "A double-faced sledge. Light as air, hard as rock.")
    hy = 1.82
    h.shaft(-0.46, hy - 0.06, 0.112, "carbon")
    h.grip(-0.42, 0.30, 0.13, "orange", rings=2, ring_mat="carbon", ring_r=0.134)
    for i, y in enumerate((0.62, 1.0, 1.38)):
        h.band("Ring%d" % i, y, 0.118, 0.035, "titan")
    h.add("Pommel", "box", (0.25, 0.12, 0.25), (0, -0.5, 0), mat="titan", planes=octagon(0.25, "y") + chamfer(0.25, 0.12, 0.25, 0.03))
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.54, 1.2
    h.add("Head", "box", (w, w, L), hp, mat="titan", planes=octagon(w, "z") + chamfer(w, w, L, 0.05, edges="xy"))
    h.add("Band", "box", (w + 0.03, w + 0.03, 0.16), hp, mat="orange", planes=octagon(w + 0.03, "z"))
    for e in (-1, 1):
        h.add("Face%d" % (e + 1), "cyl", (0.07, 0.235), hp + [0, 0, e * (L / 2 + 0.02)], R=ALONG_Z, mat="plate", planes=cyl_bevel(0.07, 0.235, 0.02), smooth=40)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        h.add("Bolt%d" % k, "ball", (0.07,), hp + [math.cos(a) * 0.255, math.sin(a) * 0.255, 0], mat="carbon", cast=False)
    h.headbox(hp, (0.6, 0.6, 1.3))
    H.append(h)

    # 6 ----------------------------------------------------------------------------------- EMERALD
    h = Hammer(6, "emerald", "Emerald Hammer", "A flawless emerald set in gold.")
    hy = 1.88
    h.shaft(-0.48, hy - 0.2, 0.105, "green_lth")
    for i, y in enumerate((-0.40, 0.38, 1.1)):
        h.band("Ring%d" % i, y, 0.12, 0.05, "gold")
    h.band("Socket", hy - 0.27, 0.15, 0.16, "gold")
    h.add("PommelCup", "cyl", (0.1, 0.13), (0, -0.5, 0), mat="gold", planes=cyl_bevel(0.1, 0.13, 0.03), smooth=40)
    h.add("PommelGem", "box", (0.15, 0.15, 0.15), (0, -0.62, 0), R=Rx(45) @ Rz(35), mat="emerald")
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.48, 1.32
    a = w / 2
    h.add("Head", "box", (w, w, L), hp, mat="emerald", planes=octagon(w, "z") + gem_ends(a, L / 2, 0.24, table=0.3, start=0))
    for i, z in enumerate((-0.27, 0.27)):
        h.add("Frame%d" % i, "box", (w + 0.05, w + 0.05, 0.1), hp + [0, 0, z], mat="gold", planes=octagon(w + 0.05, "z") + chamfer(w + 0.05, w + 0.05, 0.1, 0.02, edges="xy"))
    h.headbox(hp, (0.55, 0.55, 1.4))
    h.fx("sparkle", hp, [[120, 255, 170], [255, 255, 255]], 3, [0.12, 0.24], area=(0.5, 0.5, 1.3))
    h.light(hp, [60, 255, 140], 0.9, 6)
    H.append(h)

    # 7 ----------------------------------------------------------------------------------- RUBY
    h = Hammer(7, "ruby", "Ruby Hammer", "Two blazing rubies on a platinum core.")
    hy = 1.94
    h.shaft(-0.48, hy - 0.2, 0.106, "platinum")
    h.grip(-0.42, 0.34, 0.124, "red_lth", rings=2, ring_mat="platinum")
    h.band("Socket", hy - 0.27, 0.15, 0.16, "platinum")
    h.add("PommelCup", "cyl", (0.1, 0.13), (0, -0.5, 0), mat="platinum", planes=cyl_bevel(0.1, 0.13, 0.03), smooth=40)
    h.add("PommelGem", "box", (0.15, 0.15, 0.15), (0, -0.62, 0), R=Rx(45) @ Rz(35), mat="ruby")
    hp = np.array([0.0, hy, 0.0])
    cw, cl = 0.46, 0.66
    h.add("Core", "box", (cw, cw, cl), hp, mat="platinum", planes=octagon(cw, "z") + chamfer(cw, cw, cl, 0.04, edges="xy"))
    gw, gl = 0.44, 0.44
    for e in (-1, 1):
        h.add("Gem%d" % (e + 1), "box", (gw, gw, gl), hp + [0, 0, e * (cl / 2 + gl / 2 - 0.04)], mat="ruby",
              planes=octagon(gw, "z") + gem_ends(gw / 2, gl / 2, 0.2, table=0.32, ends=(e,), start=22.5))
    for e in (-1, 1):
        h.add("Inset%d" % (e + 1), "box", (0.13, 0.13, 0.13), hp + [e * 0.232, 0, 0], R=Rz(45) @ Rx(45), mat="ruby", cast=False)
    h.headbox(hp, (0.52, 0.52, 1.5))
    h.fx("sparkle", hp, [[255, 120, 140], [255, 255, 255]], 3.5, [0.12, 0.24], area=(0.5, 0.5, 1.4))
    h.light(hp, [255, 50, 80], 1.0, 6)
    H.append(h)

    # 8 ----------------------------------------------------------------------------------- SAPPHIRE
    h = Hammer(8, "sapphire", "Sapphire War Hammer", "A sapphire war hammer with a deadly spike.")
    hy = 2.0
    h.shaft(-0.5, hy - 0.2, 0.108, "navy_lth")
    for i, y in enumerate((-0.42, 0.36, 0.9, 1.4)):
        h.band("Ring%d" % i, y, 0.122, 0.045, "gold")
    h.band("Socket", hy - 0.27, 0.15, 0.16, "gold")
    h.add("PommelSpike", "box", (0.2, 0.26, 0.2), (0, -0.6, 0), R=Rx(180), mat="gold", planes=spike(0.2, 0.26))
    hp = np.array([0.0, hy, 0.0])
    fw, fh, fl = 0.48, 0.52, 0.64
    h.add("Front", "box", (fw, fh, fl), hp + [0, 0, -0.14], mat="sapphire",
          planes=chamfer(fw, fh, fl, 0.11) + gem_ends(fw / 2, fl / 2, 0.12, table=0.2, ends=(-1,), sides=8, start=22.5))
    h.add("Collar", "box", (0.5, 0.56, 0.11), hp + [0, 0, 0.2], mat="gold", planes=chamfer(0.5, 0.56, 0.11, 0.06, edges="z"))
    h.add("Spike", "box", (0.34, 0.6, 0.34), hp + [0, 0, 0.53], R=Rx(90), mat="sapphire", planes=spike(0.34, 0.6))
    h.add("TopSpike", "box", (0.15, 0.2, 0.15), hp + [0, 0.33, -0.14], mat="gold", planes=spike(0.15, 0.2))
    h.headbox(hp, (0.55, 0.65, 1.4))
    h.fx("sparkle", hp, [[120, 170, 255], [255, 255, 255]], 3.5, [0.12, 0.24], area=(0.5, 0.55, 1.2))
    h.light(hp, [70, 120, 255], 1.0, 6)
    H.append(h)

    # 9 ----------------------------------------------------------------------------------- AMETHYST
    h = Hammer(9, "amethyst", "Amethyst Crystal Hammer", "Crystals that grew on their own. Glowing.")
    hy = 2.06
    h.shaft(-0.5, hy - 0.18, 0.11, "obsidian")
    for i, y in enumerate((-0.36, 0.1, 0.55, 1.0, 1.45)):
        h.band("Neon%d" % i, y, 0.114, 0.026, "neon_purple")
    h.add("PommelShard", "box", (0.16, 0.3, 0.16), (0, -0.62, 0), R=Rx(180), mat="amethyst", planes=spike(0.16, 0.3, sides=6, start=0))
    hp = np.array([0.0, hy, 0.0])
    cs = (0.44, 0.46, 0.86)
    h.add("Core", "box", cs, hp, mat="obsidian", planes=chamfer(*cs, 0.08))
    shards = [  # (direction, length, width, offset along it)
        ((0, 0, -1), 0.5, 0.36, 0.38), ((0, 0, 1), 0.42, 0.3, 0.36),
        ((0, 1, -0.35), 0.4, 0.2, 0.18), ((0.45, 1, 0.25), 0.34, 0.17, 0.18), ((-0.5, 1, 0.1), 0.3, 0.15, 0.18),
        ((1, 0.25, -0.2), 0.28, 0.15, 0.2), ((-1, 0.2, 0.25), 0.26, 0.14, 0.2),
    ]
    for i, (d, ln, wd, off) in enumerate(shards):
        d = unit(d)
        up = np.array([0, 1, 0])
        # rotation that takes local +Y to d
        v = np.cross(up, d)
        s, c = np.linalg.norm(v), float(np.dot(up, d))
        if s < 1e-6:
            R = I3 if c > 0 else Rx(180)
        else:
            vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
            R = I3 + vx + vx @ vx * ((1 - c) / s ** 2)
        h.add("Shard%d" % i, "box", (wd, ln, wd), hp + d * (off + ln / 2 - 0.12), R=R @ Ry(30 * i), mat="amethyst",
              planes=octagon(wd, "y", c=wd * 0.29) + spike(wd, ln, sides=8, start=22.5)[:0] + _shard_tip(wd, ln))
    h.headbox(hp, (0.8, 0.9, 1.5))
    h.fx("sparkle", hp, [[200, 140, 255], [255, 255, 255]], 4, [0.12, 0.26], area=(0.6, 0.6, 1.3))
    h.fx("rise", hp, [[190, 120, 255]], 2, [0.05, 0.09], area=(0.5, 0.3, 1.0))
    h.light(hp, [170, 80, 255], 1.3, 7)
    H.append(h)

    # 10 ---------------------------------------------------------------------------------- LAVA
    h = Hammer(10, "lava", "Lava Hammer", "Forged in a volcano. Still hot.")
    hy = 2.12
    h.shaft(-0.5, hy - 0.08, 0.116, "basalt")
    for i, y in enumerate((-0.38, 0.38, 0.95, 1.5)):
        h.band("Neon%d" % i, y, 0.12, 0.03, "lava")
    h.add("PommelCage", "cyl", (0.16, 0.13), (0, -0.52, 0), mat="basalt", planes=cyl_bevel(0.16, 0.13, 0.05), smooth=40)
    h.add("PommelCore", "ball", (0.13,), (0, -0.62, 0), mat="lava_hot")
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.62, 1.3
    h.add("Head", "box", (w, w, L), hp, mat="basalt", planes=octagon(w, "z") + chamfer(w, w, L, 0.08, edges="xy"))
    for e in (-1, 1):
        h.add("Face%d" % (e + 1), "cyl", (0.05, 0.2), hp + [0, 0, e * (L / 2 + 0.005)], R=ALONG_Z, mat="lava_hot", planes=cyl_bevel(0.05, 0.2, 0.015), smooth=40, cast=False)
    cracks = [((0.31, 0.06, -0.3), 28, 0.34), ((0.31, -0.08, 0.18), -35, 0.3), ((-0.31, 0.04, -0.12), 50, 0.36), ((-0.31, -0.1, 0.34), -20, 0.26),
              ((0.0, 0.31, 0.05), 70, 0.4), ((0.12, -0.31, -0.25), 15, 0.3)]
    for i, (p, ang, ln) in enumerate(cracks):
        p = np.array(p)
        if abs(p[0]) > 0.3:  # side faces (normal X)
            R = Rx(ang)
            size = (0.03, 0.055, ln * 1.25)
        else:  # top / bottom faces (normal Y)
            R = Ry(ang)
            size = (0.055, 0.03, ln * 1.25)
        h.add("Crack%d" % i, "box", size, hp + p, R=R, mat="lava", cast=False)
    h.headbox(hp, (0.66, 0.66, 1.4))
    h.fx("embers", hp, [[255, 200, 80], [255, 90, 20]], 7, [0.05, 0.12], area=(0.6, 0.4, 1.2))
    h.fx("smoke", hp + [0, 0.25, 0], [[60, 50, 50]], 1.2, [0.25, 0.5], area=(0.4, 0.1, 0.8))
    h.light(hp, [255, 120, 30], 1.8, 9)
    H.append(h)

    # 11 ---------------------------------------------------------------------------------- FROST
    h = Hammer(11, "frost", "Frost Hammer", "Cold enough to freeze the air around it.")
    hy = 2.16
    h.shaft(-0.5, hy - 0.08, 0.11, "silver")
    h.grip(-0.42, 0.34, 0.126, "ice_lth", rings=3, ring_mat="silver")
    h.add("PommelShard", "box", (0.16, 0.32, 0.16), (0, -0.62, 0), R=Rx(180), mat="icicle", planes=octagon(0.16, "y") + _shard_tip(0.16, 0.32))
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.56, 1.22
    h.add("Head", "box", (w, w, L), hp, mat="ice", planes=octagon(w, "z") + chamfer(w, w, L, 0.08, edges="xy"))
    for e in (-1, 1):
        h.add("Cap%d" % (e + 1), "box", (w + 0.04, w + 0.04, 0.09), hp + [0, 0, e * (L / 2 - 0.02)], mat="silver", planes=octagon(w + 0.04, "z"))
    h.add("Core", "box", (w + 0.008, 0.06, L * 0.7), hp, mat="frost_neon", cast=False)
    for i, (x, z, ln, tilt) in enumerate(((0.0, -0.3, 0.42, -12), (0.12, 0.05, 0.34, 10), (-0.1, 0.32, 0.38, 18))):
        h.add("Icicle%d" % i, "box", (0.15, ln, 0.15), hp + [x, w / 2 + ln / 2 - 0.06, z], R=Rx(tilt) @ Rz(-x * 60), mat="icicle",
              planes=octagon(0.15, "y") + _shard_tip(0.15, ln))
    h.headbox(hp, (0.62, 0.95, 1.35))
    h.fx("snow", hp + [0, 0.1, 0], [[255, 255, 255], [200, 240, 255]], 4, [0.06, 0.13], area=(0.7, 0.3, 1.3))
    h.fx("mist", hp, [[180, 230, 255]], 1.5, [0.3, 0.55], area=(0.5, 0.3, 1.0))
    h.light(hp, [120, 220, 255], 1.2, 7)
    H.append(h)

    # 12 ---------------------------------------------------------------------------------- DIAMOND
    h = Hammer(12, "diamond", "Diamond Hammer", "The hardest hammer there is. Rainbow sparkles included.")
    hy = 2.22
    h.shaft(-0.5, hy - 0.22, 0.11, "platinum")
    h.grip(-0.42, 0.34, 0.126, "white_lth", rings=3, ring_mat="platinum")
    for i, y in enumerate((0.8, 1.35)):
        h.band("Ring%d" % i, y, 0.124, 0.05, "platinum")
    h.band("Socket", hy - 0.29, 0.16, 0.18, "platinum")
    h.add("PommelGem", "box", (0.2, 0.2, 0.2), (0, -0.6, 0), R=Rx(45) @ Rz(35), mat="diamond")
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.6, 1.4
    h.add("Head", "box", (w, w, L), hp, mat="diamond", planes=octagon(w, "z") + gem_ends(w / 2, L / 2, 0.3, table=0.28, start=22.5))
    for i, z in enumerate((-0.3, 0.3)):
        h.add("Frame%d" % i, "box", (w + 0.05, w + 0.05, 0.09), hp + [0, 0, z], mat="platinum", planes=octagon(w + 0.05, "z"))
    h.add("Crown", "box", (0.2, 0.16, 0.2), hp + [0, w / 2 + 0.04, 0], mat="platinum", planes=octagon(0.2, "y") + chamfer(0.2, 0.16, 0.2, 0.03, edges="xz"))
    h.add("CrownGem", "box", (0.13, 0.13, 0.13), hp + [0, w / 2 + 0.16, 0], R=Rx(45) @ Rz(35), mat="diamond", cast=False)
    h.headbox(hp, (0.66, 0.8, 1.5))
    h.fx("rainbow", hp, [[255, 80, 80], [255, 220, 80], [80, 255, 140], [80, 180, 255], [220, 100, 255]], 5, [0.12, 0.26], area=(0.65, 0.65, 1.45))
    h.fx("glint", hp, [[255, 255, 255]], 2, [0.18, 0.32], area=(0.6, 0.6, 1.4))
    h.light(hp, [220, 245, 255], 1.4, 8)
    H.append(h)

    # 13 ---------------------------------------------------------------------------------- PLASMA
    h = Hammer(13, "plasma", "Plasma Hammer", "Pure energy, held in a magnetic field.")
    hy = 2.28
    h.shaft(-0.5, hy - 0.08, 0.112, "gunmetal")
    h.grip(-0.42, 0.32, 0.128, "black_rub", rings=2, ring_mat="cyan_neon", ring_r=0.131)
    for i, y in enumerate((0.7, 1.2, 1.7)):
        h.band("Neon%d" % i, y, 0.118, 0.035, "cyan_neon")
    h.add("PommelCage", "box", (0.24, 0.16, 0.24), (0, -0.52, 0), mat="gunmetal", planes=octagon(0.24, "y") + chamfer(0.24, 0.16, 0.24, 0.04, edges="xz"))
    h.add("PommelCore", "ball", (0.15,), (0, -0.64, 0), mat="plasma_core")
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.62, 1.34
    h.add("Field", "box", (w, w, L - 0.2), hp, mat="plasma", planes=octagon(w, "z"), cast=False)
    h.add("Core", "cyl", (L - 0.16, 0.13), hp, R=ALONG_Z, mat="plasma_core", smooth=40, cast=False)
    for e in (-1, 1):
        h.add("Cap%d" % (e + 1), "box", (w + 0.03, w + 0.03, 0.16), hp + [0, 0, e * (L / 2 - 0.08)], mat="gunmetal",
              planes=octagon(w + 0.03, "z") + chamfer(w + 0.03, w + 0.03, 0.16, 0.04, edges="xy"))
        h.add("Glow%d" % (e + 1), "cyl", (0.03, 0.18), hp + [0, 0, e * (L / 2 + 0.005)], R=ALONG_Z, mat="cyan_neon", smooth=40, cast=False)
    h.add("Mid", "box", (w + 0.03, w + 0.03, 0.1), hp, mat="gunmetal", planes=octagon(w + 0.03, "z"))
    h.headbox(hp, (0.68, 0.68, 1.45))
    h.fx("sparks", hp, [[200, 250, 255], [60, 220, 255]], 9, [0.04, 0.09], area=(0.62, 0.62, 1.1))
    h.light(hp, [60, 220, 255], 2.0, 9)
    h.trail(hp + [0, 0.32, -0.6], hp + [0, -0.32, -0.6], [[150, 246, 255], [60, 140, 255]])
    H.append(h)

    # 14 ---------------------------------------------------------------------------------- SOLAR
    h = Hammer(14, "solar", "Solar Hammer", "A tiny sun on a stick. Do not look straight at it.")
    hy = 2.34
    h.shaft(-0.5, hy - 0.3, 0.114, "gold")
    h.grip(-0.42, 0.34, 0.13, "black_lth", rings=3, ring_mat="sun", ring_r=0.133)
    h.band("Socket", hy - 0.38, 0.16, 0.18, "gold")
    h.add("PommelSun", "ball", (0.17,), (0, -0.6, 0), mat="sun_hot")
    h.add("PommelRing", "ring", (0.04, 0.15, 0.115), (0, -0.6, 0), R=Rx(90), mat="gold", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    h.add("Sun", "ball", (0.62,), hp, mat="sun")
    h.add("RingA", "ring", (0.06, 0.5, 0.42), hp, R=ALONG_Z, mat="gold", smooth=40)
    h.add("RingB", "ring", (0.05, 0.47, 0.41), hp, R=Ry(90) @ Rz(55), mat="gold_lt", smooth=40)
    for e in (-1, 1):
        h.add("Arm%d" % (e + 1), "cyl", (0.34, 0.17), hp + [0, 0, e * 0.42], R=ALONG_Z, mat="gold", planes=cyl_bevel(0.34, 0.17, 0.03), smooth=40)
        h.add("Face%d" % (e + 1), "cyl", (0.08, 0.215), hp + [0, 0, e * 0.62], R=ALONG_Z, mat="gold_lt", planes=cyl_bevel(0.08, 0.215, 0.025), smooth=40)
        h.add("FaceSun%d" % (e + 1), "cyl", (0.02, 0.15), hp + [0, 0, e * 0.665], R=ALONG_Z, mat="sun_hot", smooth=40, cast=False)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        d = np.array([0, math.cos(a), math.sin(a)])
        R = Rx(-math.degrees(a) + 90)
        h.add("Flare%d" % k, "box", (0.12, 0.22, 0.12), hp + d * 0.42, R=Rx(math.degrees(math.atan2(d[2], d[1]))), mat="sun_hot",
              planes=spike(0.12, 0.22), cast=False)
    h.headbox(hp, (0.7, 0.9, 1.4))
    h.fx("fire", hp, [[255, 240, 140], [255, 120, 20]], 10, [0.12, 0.28], area=(0.5, 0.5, 0.5))
    h.fx("glint", hp, [[255, 240, 180]], 3, [0.14, 0.26], area=(0.7, 0.7, 1.3))
    h.light(hp, [255, 160, 40], 2.6, 11)
    h.trail(hp + [0, 0.36, -0.66], hp + [0, -0.36, -0.66], [[255, 236, 140], [255, 100, 20]])
    H.append(h)

    # 15 ---------------------------------------------------------------------------------- GALAXY
    h = Hammer(15, "galaxy", "Galaxy Hammer", "A whole galaxy, trapped in crystal. The last hammer.")
    hy = 2.42
    h.shaft(-0.52, hy - 0.22, 0.114, "void")
    for i, y in enumerate((-0.4, 0.36, 0.86, 1.36, 1.86)):
        h.band("Neon%d" % i, y, 0.119, 0.03, "pink_neon" if i % 2 == 0 else "cyan_neon")
    h.band("Socket", hy - 0.3, 0.16, 0.18, "void")
    h.add("PommelStar", "ball", (0.17,), (0, -0.62, 0), mat="star")
    h.add("PommelRing", "ring", (0.035, 0.16, 0.125), (0, -0.62, 0), R=Rx(90) @ Rz(25), mat="pink_neon", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.64, 1.52
    h.add("Galaxy", "box", (0.42, 0.42, L - 0.6), hp, mat="cosmos", cast=False)
    h.add("Shell", "box", (w, w, L), hp, mat="cosmic_glass", planes=octagon(w, "z") + gem_ends(w / 2, L / 2, 0.3, table=0.3, start=22.5))
    for i, z in enumerate((-0.33, 0.33)):
        h.add("Band%d" % i, "box", (w + 0.04, w + 0.04, 0.06), hp + [0, 0, z], mat="pink_neon", planes=octagon(w + 0.04, "z"), cast=False)
    h.add("Orbit", "ring", (0.035, 0.68, 0.64), hp, R=Rx(78) @ Rz(18), mat="cyan_neon", smooth=40, cast=False)
    h.add("Moon", "ball", (0.11,), hp + [0.64, 0.12, 0.12], mat="star", cast=False)
    h.headbox(hp, (0.8, 0.8, 1.6))
    h.fx("stars", hp, [[255, 255, 255], [255, 170, 250], [150, 210, 255]], 7, [0.1, 0.24], area=(0.75, 0.75, 1.5))
    h.light(hp, [190, 110, 255], 2.2, 10)
    h.trail(hp + [0, 0.36, -0.72], hp + [0, -0.36, -0.72], [[255, 150, 250], [140, 90, 255], [80, 200, 255]])
    h.d["scroll"] = dict(piece="Galaxy", image="galaxy", speed=[0.06, 0.02], studs=1.2)
    H.append(h)

    # special (Robux add-on) ----------------------------------------------------------------- THUNDERCLAP (original design)
    h = Hammer(16, "thunder", "Thunderclap Hammer", "A storm in a hammer. Triples your build power, forever.")
    h.d["special"] = True
    hy = 2.36
    h.shaft(-0.5, hy - 0.12, 0.114, "stormwood")
    h.grip(-0.42, 0.34, 0.132, "storm_lth", rings=3, ring_mat="silver", ring_r=0.136)
    for i, y in enumerate((0.62, 1.12, 1.62)):
        h.band("Rune%d" % i, y, 0.12, 0.035, "storm_neon")
    h.band("Socket", hy - 0.36, 0.17, 0.2, "silver")
    h.add("Pommel", "box", (0.26, 0.14, 0.26), (0, -0.52, 0), mat="silver", planes=chamfer(0.26, 0.14, 0.26, 0.05))
    h.add("PommelGem", "box", (0.15, 0.15, 0.15), (0, -0.65, 0), R=Rx(45) @ Rz(35), mat="storm_crystal")
    hp = np.array([0.0, hy, 0.0])
    # a big rectangular block of storm stone with silver edges
    hw, hh, L = 0.72, 0.78, 1.18
    h.add("Head", "box", (hw, hh, L), hp, mat="stormstone", planes=chamfer(hw, hh, L, 0.07))
    for e in (-1, 1):
        # silver end frames + the striking plates with a glowing core
        h.add("Frame%d" % (e + 1), "box", (hw + 0.06, hh + 0.06, 0.12), hp + [0, 0, e * (L / 2 - 0.03)], mat="silver",
              planes=chamfer(hw + 0.06, hh + 0.06, 0.12, 0.06, edges="z") + chamfer(hw + 0.06, hh + 0.06, 0.12, 0.03, edges="xy"))
        h.add("Plate%d" % (e + 1), "box", (hw - 0.14, hh - 0.14, 0.06), hp + [0, 0, e * (L / 2 + 0.05)], mat="silver",
              planes=chamfer(hw - 0.14, hh - 0.14, 0.06, 0.05, edges="z") + chamfer(hw - 0.14, hh - 0.14, 0.06, 0.02, edges="xy"))
        h.add("Core%d" % (e + 1), "box", (0.26, 0.26, 0.02), hp + [0, 0, e * (L / 2 + 0.085)], R=Rz(45), mat="storm_neon", cast=False)
    # silver bands around the middle of the block
    for i, z in enumerate((-0.22, 0.22)):
        h.add("Band%d" % i, "box", (hw + 0.03, hh + 0.03, 0.06), hp + [0, 0, z], mat="silver", planes=chamfer(hw + 0.03, hh + 0.03, 0.06, 0.07, edges="z"))
    # a glowing lightning bolt with a silver rim on both sides and on top of the block
    for sx in (-1, 1):
        R = I3 if sx > 0 else Ry(180)
        h.bolt("Bolt%d" % (sx + 1), hp + [sx * hw / 2, 0, 0], R, 1.05, "storm_neon", rim_mat="silver", out=(sx, 0, 0))
    h.bolt("BoltTop", hp + [0, hh / 2, 0], Rz(90), 0.95, "storm_neon", rim_mat="silver", out=(0, 1, 0))
    h.headbox(hp, (0.85, 0.9, 1.4))
    h.fx("sparks", hp, [[220, 240, 255], [80, 170, 255]], 12, [0.04, 0.09], area=(0.7, 0.8, 1.2))
    h.fx("glint", hp, [[170, 220, 255]], 3, [0.14, 0.3], area=(0.75, 0.8, 1.2))
    h.light(hp, [90, 170, 255], 2.4, 11)
    h.trail(hp + [0, 0.4, -0.66], hp + [0, -0.4, -0.66], [[230, 245, 255], [80, 160, 255]])
    h.d["storm"] = True
    H.append(h)

    build_new(H)
    return [x.d for x in H]


def build_new(H):
    """the 24 hammers added in October 2026 (tiers 17..40): their Tools are named Hammer_<key> in the game"""
    def new(key, name, desc):
        h = Hammer(len(H) + 1, key, name, desc)
        h.d["bykey"] = True
        return h

    def rf(v):
        return [round(float(x), 4) for x in v]

    # 17 ---------------------------------------------------------------------------------- CARPENTER'S MALLET (common)
    h = new("mallet", "Carpenter's Mallet", "A fat wooden mallet with a leather-wrapped handle. Thud.")
    hy = 1.58
    h.shaft(-0.44, hy - 0.04, 0.1, "oak")
    h.grip(-0.40, 0.30, 0.118, "leather", rings=3, ring_mat="black_lth", ring_r=0.121)
    h.add("Pommel", "cyl", (0.1, 0.13), (0, -0.48, 0), mat="oak_end", planes=cyl_bevel(0.1, 0.13, 0.035), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    h.add("Head", "cyl", (0.92, 0.27), hp, R=ALONG_Z, mat="oak", planes=cyl_bevel(0.92, 0.27, 0.05), smooth=40)
    for i, e in enumerate((-1, 1)):
        h.add("Band%d" % i, "cyl", (0.07, 0.283), hp + [0, 0, e * 0.3], R=ALONG_Z, mat="brass", planes=cyl_bevel(0.07, 0.283, 0.015), smooth=40, cast=False)
        h.add("End%d" % i, "cyl", (0.03, 0.225), hp + [0, 0, e * 0.462], R=ALONG_Z, mat="oak_end", smooth=40, cast=False)
    h.add("Wedge", "cyl", (0.06, 0.085), hp + [0, 0.262, 0], mat="oak_end", smooth=40, cast=False)
    h.headbox(hp, (0.56, 0.56, 1.0))
    H.append(h)

    # 18 ---------------------------------------------------------------------------------- BRICK HAMMER (common)
    h = new("brick", "Brick Hammer", "A red brick on a stick. Don't ask how it holds together.")
    hy = 1.56
    h.shaft(-0.44, hy - 0.02, 0.098, "wood")
    h.add("Pommel", "cyl", (0.08, 0.115), (0, -0.47, 0), mat="wood", planes=cyl_bevel(0.08, 0.115, 0.03), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    bs = (0.42, 0.3, 0.9)
    h.add("Brick", "box", bs, hp, mat="brick", planes=chamfer(*bs, 0.025))
    for i, z in enumerate((-0.27, 0.27)):
        h.add("Hole%d" % i, "cyl", (0.02, 0.065), hp + [0, 0.15, z], mat="hole", smooth=40, cast=False)
    h.add("ShaftTop", "cyl", (0.04, 0.09), hp + [0, 0.155, 0], mat="wood", smooth=40, cast=False)
    h.add("Mortar0", "box", (0.44, 0.05, 0.36), hp + [0, -0.135, -0.22], R=Rx(4), mat="mortar", planes=chamfer(0.44, 0.05, 0.36, 0.02))
    h.add("Mortar1", "box", (0.03, 0.12, 0.3), hp + [0.212, 0.05, 0.24], R=Rx(-6), mat="mortar", planes=chamfer(0.03, 0.12, 0.3, 0.012), cast=False)
    h.add("Mortar2", "box", (0.03, 0.1, 0.24), hp + [-0.212, -0.06, -0.18], R=Rx(5), mat="mortar", planes=chamfer(0.03, 0.1, 0.24, 0.012), cast=False)
    h.headbox(hp, (0.46, 0.36, 1.0))
    h.fx("flakes", hp, [[190, 90, 60], [200, 196, 186]], 1.2, [0.03, 0.06], area=(0.4, 0.2, 0.8))
    H.append(h)

    # 19 ---------------------------------------------------------------------------------- CLAW HAMMER (common)
    h = new("claw", "Claw Hammer", "The classic claw hammer, fresh from the hardware store.")
    hy = 1.66
    h.shaft(-0.46, hy - 0.05, 0.1, "fiber_yel")
    h.grip(-0.42, 0.36, 0.126, "black_rub")
    h.add("GripCap", "cyl", (0.1, 0.134), (0, -0.47, 0), mat="black_rub", planes=cyl_bevel(0.1, 0.134, 0.04), smooth=40)
    h.band("GripLip", 0.37, 0.132, 0.05, "black_rub")
    hp = np.array([0.0, hy, 0.0])
    h.add("Neck", "box", (0.3, 0.3, 0.3), hp + [0, -0.06, 0], mat="steel", planes=octagon(0.3, "y") + chamfer(0.3, 0.3, 0.3, 0.03, edges="xz"))
    h.add("Head", "box", (0.32, 0.34, 0.58), hp + [0, 0, -0.1], mat="steel", planes=chamfer(0.32, 0.34, 0.58, 0.08, edges="z") + chamfer(0.32, 0.34, 0.58, 0.02, edges="xy"))
    h.add("Face", "cyl", (0.16, 0.2), hp + [0, 0, -0.46], R=ALONG_Z, mat="steel", planes=cyl_bevel(0.16, 0.2, 0.04), smooth=40)
    h.add("FaceRing", "cyl", (0.04, 0.215), hp + [0, 0, -0.38], R=ALONG_Z, mat="steel_dk", smooth=40, cast=False)
    claw(h, hp[1] + 0.04, hp[2] + 0.2, 0.62, "steel", w=0.1, gap=0.07, droop=50)
    h.headbox(hp, (0.36, 0.42, 1.4))
    H.append(h)

    # 20 ---------------------------------------------------------------------------------- COPPER PIPE HAMMER (uncommon)
    h = new("copper", "Copper Pipe Hammer", "A plumber's revenge: a bent copper pipe, polished to a mirror.")
    hy = 1.74
    h.shaft(-0.46, hy - 0.06, 0.092, "copper")
    h.grip(-0.42, 0.30, 0.124, "black_rub", rings=2, ring_mat="copper_dk", ring_r=0.127)
    for i, y in enumerate((0.62, 1.12)):
        h.band("Clamp%d" % i, y, 0.108, 0.06, "steel_dk")
        h.add("Screw%d" % i, "box", (0.07, 0.05, 0.05), (0.11, y, 0), mat="steel", planes=chamfer(0.07, 0.05, 0.05, 0.012), cast=False)
    h.add("Pommel", "cyl", (0.08, 0.13), (0, -0.47, 0), mat="copper_dk", planes=cyl_bevel(0.08, 0.13, 0.03), smooth=40)
    hp = np.array([0.0, hy, -0.08])
    h.add("Tee", "cyl", (0.2, 0.135), (0, hy - 0.19, 0), mat="copper_dk", planes=cyl_bevel(0.2, 0.135, 0.03), smooth=40)
    h.add("Pipe", "cyl", (0.86, 0.19), hp + [0, 0, -0.05], R=ALONG_Z, mat="copper", smooth=40)
    h.add("Coupling", "cyl", (0.16, 0.23), hp + [0, 0, -0.46], R=ALONG_Z, mat="copper_dk", planes=cyl_bevel(0.16, 0.23, 0.03), smooth=40)
    h.add("Cap", "cyl", (0.06, 0.2), hp + [0, 0, -0.56], R=ALONG_Z, mat="copper", planes=cyl_bevel(0.06, 0.2, 0.025), smooth=40)
    h.add("Patina0", "cyl", (0.025, 0.206), hp + [0, 0, -0.37], R=ALONG_Z, mat="patina", smooth=40, cast=False)
    h.add("Elbow", "ball", (0.4,), hp + [0, 0, 0.38], mat="copper")
    h.add("Drop", "cyl", (0.38, 0.19), hp + [0, -0.2, 0.38], mat="copper", smooth=40)
    h.add("Coupling2", "cyl", (0.14, 0.23), hp + [0, -0.4, 0.38], mat="copper_dk", planes=cyl_bevel(0.14, 0.23, 0.03), smooth=40)
    h.add("Patina1", "cyl", (0.025, 0.206), hp + [0, -0.32, 0.38], mat="patina", smooth=40, cast=False)
    h.add("Patina2", "cyl", (0.025, 0.206), hp + [0, 0, 0.2], R=ALONG_Z, mat="patina", smooth=40, cast=False)
    h.headbox(hp + [0, -0.1, 0], (0.5, 0.7, 1.2))
    H.append(h)

    # 21 ---------------------------------------------------------------------------------- NEON HAMMER (uncommon)
    h = new("neon", "Neon Hammer", "Black rubber with glowing neon stripes. Looks fast standing still.")
    hy = 1.78
    h.shaft(-0.46, hy - 0.05, 0.104, "black_rub")
    h.grip(-0.42, 0.30, 0.124, "black_rub", rings=3, ring_mat="neon_lime", ring_r=0.127)
    for i, (y, m) in enumerate(((0.62, "neon_mag"), (0.98, "cyan_neon"), (1.34, "neon_lime"))):
        h.band("Glow%d" % i, y, 0.11, 0.035, m)
    h.add("Pommel", "cyl", (0.1, 0.132), (0, -0.48, 0), mat="black_rub", planes=cyl_bevel(0.1, 0.132, 0.04), smooth=40)
    h.add("PommelGlow", "cyl", (0.02, 0.1), (0, -0.535, 0), mat="neon_mag", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    hs = (0.44, 0.46, 1.08)
    h.add("Head", "box", hs, hp, mat="black_rub", planes=chamfer(*hs, 0.11))
    for i, (z, m) in enumerate(((-0.3, "neon_mag"), (0.0, "cyan_neon"), (0.3, "neon_lime"))):
        h.add("Stripe%d" % i, "box", (0.455, 0.475, 0.05), hp + [0, 0, z], mat=m, planes=chamfer(0.455, 0.475, 0.05, 0.115, edges="z"), cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Face%d" % i, "cyl", (0.08, 0.17), hp + [0, 0, e * 0.56], R=ALONG_Z, mat="black_rub", planes=cyl_bevel(0.08, 0.17, 0.03), smooth=40)
        h.add("FaceRing%d" % i, "ring", (0.025, 0.15, 0.1), hp + [0, 0, e * 0.6], R=ALONG_Z, mat="neon_mag" if e < 0 else "neon_lime", smooth=40, cast=False)
    h.headbox(hp, (0.48, 0.5, 1.25))
    h.light(hp, [255, 80, 220], 0.6, 5)
    H.append(h)

    # 22 ---------------------------------------------------------------------------------- TOOLBOX HAMMER (uncommon)
    h = new("toolbox", "Toolbox Hammer", "A whole red toolbox welded onto a handle. Everything you need, in one swing.")
    hy = 1.76
    h.shaft(-0.46, hy - 0.1, 0.1, "steel")
    h.grip(-0.42, 0.30, 0.124, "red", rings=2, ring_mat="carbon", ring_r=0.127)
    h.add("Pommel", "cyl", (0.1, 0.13), (0, -0.48, 0), mat="carbon", planes=cyl_bevel(0.1, 0.13, 0.035), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    bs = (0.46, 0.4, 0.94)
    h.add("Box", "box", bs, hp, mat="tb_red", planes=chamfer(*bs, 0.035))
    h.add("Seam", "box", (0.47, 0.025, 0.95), hp + [0, 0.08, 0], mat="tb_dark", planes=chamfer(0.47, 0.025, 0.95, 0.01), cast=False)
    for i, sx in enumerate((-1, 1)):
        h.add("Latch%d" % i, "box", (0.03, 0.1, 0.09), hp + [sx * 0.235, 0.06, 0], mat="steel", planes=chamfer(0.03, 0.1, 0.09, 0.01), cast=False)
    for i, z in enumerate((-0.17, 0.17)):
        h.add("Post%d" % i, "cyl", (0.12, 0.03), hp + [0, 0.25, z], mat="steel_dk", smooth=40)
    h.add("LidBar", "cyl", (0.42, 0.035), hp + [0, 0.31, 0], R=ALONG_Z, mat="carbon", smooth=40)
    for i, e in enumerate((-1, 1)):
        h.add("End%d" % i, "box", (0.49, 0.43, 0.05), hp + [0, 0, e * 0.48], mat="steel", planes=chamfer(0.49, 0.43, 0.05, 0.04, edges="z"))
    # a screwdriver sticking out of each side (yellow on one, blue on the other)
    for i, (sx, hm) in enumerate(((1, "fiber_yel"), (-1, "rubber_bl"))):
        d = unit((sx, 0.55, -0.25 * sx))
        base = hp + [sx * 0.2, 0.04, 0.16 * sx]
        h.add("Driver%dHandle" % i, "cyl", (0.2, 0.045), base + d * 0.1, R=toward(d), mat=hm, planes=cyl_bevel(0.2, 0.045, 0.015), smooth=40)
        h.add("Driver%dShaft" % i, "cyl", (0.16, 0.016), base + d * 0.27, R=toward(d), mat="steel", smooth=40, cast=False)
    h.headbox(hp, (0.6, 0.6, 1.05))
    H.append(h)

    # 23 ---------------------------------------------------------------------------------- BRONZE MALLET (uncommon)
    h = new("bronze", "Bronze Mallet", "Ancient bronze with green patina. It has seen things.")
    hy = 1.8
    h.shaft(-0.46, hy - 0.06, 0.104, "dark_wood")
    h.grip(-0.42, 0.32, 0.12, "cord", rings=4, ring_mat="dark_wood", ring_r=0.123)
    h.add("Pommel", "ball", (0.24,), (0, -0.52, 0), mat="bronze")
    h.band("PommelCollar", -0.43, 0.115, 0.06, "bronze_dk")
    h.band("Socket", hy - 0.27, 0.14, 0.14, "bronze_dk")
    hp = np.array([0.0, hy, 0.0])
    h.add("Head", "cyl", (0.62, 0.25), hp, R=ALONG_Z, mat="bronze", smooth=40)
    for i, e in enumerate((-1, 1)):
        h.add("Dome%d" % i, "ball", (0.5,), hp + [0, 0, e * 0.31], mat="bronze")
    for i, z in enumerate((-0.2, -0.07, 0.07, 0.2)):
        h.add("Ring%d" % i, "cyl", (0.03, 0.258), hp + [0, 0, z], R=ALONG_Z, mat="patina" if i % 2 else "bronze_dk", smooth=40, cast=False)
    h.headbox(hp, (0.52, 0.52, 1.12))
    H.append(h)

    # 24 ---------------------------------------------------------------------------------- OBSIDIAN HAMMER (rare)
    h = new("obsidian", "Obsidian Hammer", "Black volcanic glass with a red glow deep inside.")
    hy = 1.9
    h.shaft(-0.48, hy - 0.16, 0.104, "charcoal")
    h.grip(-0.42, 0.34, 0.122, "red_lth", rings=3, ring_mat="charcoal", ring_r=0.125)
    h.band("Socket", hy - 0.26, 0.15, 0.16, "charcoal")
    h.add("PommelShard", "box", (0.16, 0.3, 0.16), (0, -0.62, 0), R=Rx(180), mat="obsid_glass", planes=octagon(0.16, "y") + _shard_tip(0.16, 0.3))
    hp = np.array([0.0, hy, 0.0])
    L, a = 1.26, 0.22
    h.add("Head", "box", (0.52, 0.46, L), hp, mat="obsid_glass", planes=hexagon(a, start=30) + gem_ends(a, L / 2, 0.26, sides=6, table=0.3, start=30))
    h.add("Seam", "box", (0.53, 0.47, 0.035), hp, mat="ember", planes=hexagon(a + 0.006, start=30), cast=False)
    face_cracks(h, hp, a, [(90, 0.2, 25, 0.3), (90, -0.25, -30, 0.26), (30, 0.3, -20, 0.26), (150, -0.15, 35, 0.28),
                           (210, 0.25, 15, 0.24), (270, -0.05, -25, 0.3), (330, -0.3, 30, 0.24)], "ember")
    h.headbox(hp, (0.55, 0.5, 1.35))
    h.fx("embers", hp, [[255, 120, 80], [255, 40, 20]], 3, [0.04, 0.09], area=(0.5, 0.4, 1.1))
    h.light(hp, [255, 60, 40], 1.0, 6)
    H.append(h)

    # 25 ---------------------------------------------------------------------------------- JADE HAMMER (rare)
    h = new("jade", "Jade Hammer", "Carved green jade with golden dragon engravings.")
    hy = 1.94
    h.shaft(-0.48, hy - 0.2, 0.104, "lacquer")
    for i, y in enumerate((-0.4, 0.36, 1.1)):
        h.band("Ring%d" % i, y, 0.118, 0.05, "gold")
    h.band("Socket", hy - 0.27, 0.15, 0.16, "gold")
    h.add("PommelCap", "cyl", (0.1, 0.13), (0, -0.5, 0), mat="gold", planes=cyl_bevel(0.1, 0.13, 0.03), smooth=40)
    h.add("TasselKnot", "ball", (0.11,), (0, -0.6, 0), mat="silk_red")
    h.add("Tassel", "cyl", (0.26, 0.05), (0, -0.76, 0), mat="silk_red", planes=cyl_bevel(0.26, 0.05, 0.02), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.5, 1.12
    h.add("Head", "box", (w, w, L), hp, mat="jade", planes=octagon(w, "z") + chamfer(w, w, L, 0.06, edges="xy"))
    for i, e in enumerate((-1, 1)):
        h.add("Cap%d" % i, "box", (w + 0.05, w + 0.05, 0.1), hp + [0, 0, e * (L / 2 - 0.01)], mat="gold",
              planes=octagon(w + 0.05, "z") + chamfer(w + 0.05, w + 0.05, 0.1, 0.025, edges="xy"))
        h.add("Face%d" % i, "cyl", (0.06, 0.15), hp + [0, 0, e * (L / 2 + 0.05)], R=ALONG_Z, mat="jade", smooth=40)
    for i, sx in enumerate((-1, 1)):
        h.add("Medal%d" % i, "ring", (0.03, 0.17, 0.115), hp + [sx * 0.25, 0, 0], R=ALONG_X, mat="gold", smooth=40, cast=False)
        h.add("Pearl%d" % i, "ball", (0.13,), hp + [sx * 0.25, 0, 0], mat="gold_lt", cast=False)
        for j, (y, z) in enumerate(((0.12, -0.3), (-0.12, 0.3))):
            h.add("Line%d%d" % (i, j), "box", (0.02, 0.03, 0.16), hp + [sx * 0.252, y, z], R=Rx(18 if j else -18), mat="gold", cast=False)
    h.headbox(hp, (0.55, 0.55, 1.25))
    h.fx("sparkle", hp, [[120, 255, 170], [255, 240, 170]], 3, [0.12, 0.22], area=(0.5, 0.5, 1.2))
    h.light(hp, [80, 230, 140], 0.8, 6)
    H.append(h)

    # 26 ---------------------------------------------------------------------------------- CANDY HAMMER (rare)
    h = new("candy", "Candy Hammer", "A giant swirl lollipop head on a candy-cane handle. Sticky.")
    hy = 2.0
    h.shaft(-0.48, hy - 0.36, 0.1, "candy_white")
    for i in range(7):
        h.add("Stripe%d" % i, "cyl", (0.07, 0.104), (0, -0.36 + i * 0.3, 0), R=Rx(22), mat="candy_red", smooth=40, cast=False)
    h.add("Pommel", "ball", (0.22,), (0, -0.52, 0), mat="candy_red")
    hp = np.array([0.0, hy, 0.0])
    h.add("Pop", "cyl", (0.24, 0.46), hp, R=ALONG_X, mat="candy_white", planes=cyl_bevel(0.24, 0.46, 0.06), smooth=40)
    for i, sx in enumerate((-1, 1)):
        for j, (ro, ri) in enumerate(((0.38, 0.3), (0.23, 0.15))):
            h.add("Swirl%d%d" % (i, j), "ring", (0.02, ro, ri), hp + [sx * 0.115, 0, 0], R=ALONG_X, mat="candy_pink", smooth=40, cast=False)
        h.add("Core%d" % i, "cyl", (0.02, 0.075), hp + [sx * 0.115, 0, 0], R=ALONG_X, mat="candy_pink", smooth=40, cast=False)
    cols = ["sprinkle_b", "sprinkle_y", "sprinkle_g"]
    for k in range(9):
        a = math.radians(k * 40 + 12)
        n = np.array([0, math.cos(a), math.sin(a)])
        h.add("Sprinkle%d" % k, "box", (0.045, 0.03, 0.1), hp + [0.06 * (1 if k % 2 else -1), 0, 0] + n * 0.462, R=toward(n, twist=35 * k), mat=cols[k % 3], cast=False)
    h.headbox(hp, (0.3, 0.95, 0.95))
    h.fx("sparkle", hp, [[255, 160, 220], [255, 255, 255]], 3, [0.1, 0.2], area=(0.3, 0.9, 0.9))
    h.light(hp, [255, 120, 200], 0.7, 5)
    H.append(h)

    # 27 ---------------------------------------------------------------------------------- DRAGON FANG HAMMER (epic)
    h = new("dragon", "Dragon Fang Hammer", "A dragon's fang bound in scales. It still breathes a little smoke.")
    hy = 2.04
    h.shaft(-0.5, hy - 0.2, 0.11, "scale_red")
    for i in range(9):
        h.band("Scale%d" % i, -0.38 + i * 0.22, 0.117, 0.05, "scale_blk")
    h.band("Socket", hy - 0.28, 0.16, 0.18, "scale_blk")
    h.add("PommelClaw", "box", (0.16, 0.28, 0.16), (0, -0.6, 0), R=Rx(180), mat="bone", planes=octagon(0.16, "y") + _shard_tip(0.16, 0.28))
    hp = np.array([0.0, hy, 0.0])
    # the head IS the fang: a big curved tooth lying along the head, its wide root is the striking face (front), it
    # narrows and curls down to a sharp point at the back. Side profile (u = Z, v = Y) cut into convex slices.
    fang = []
    N = 9
    for k in range(N + 1):
        t = k / N
        c = np.array([-0.56 + 1.22 * t, 0.07 - 0.42 * t ** 2.2])            # the centre line (u, v)
        du = 1.22
        dv = -0.42 * 2.2 * t ** 1.2
        n = np.array([-dv, du]) / math.hypot(du, dv)                        # its normal, pointing up
        w = 0.5 * (1 - t) ** 0.85 + 0.004                                   # the width of the tooth
        fang.append((c, n, w))
    # the tooth also gets thinner towards its point: two side planes shared by every slice (no steps between them)
    tb = (0.07 - 0.22) / (0.66 + 0.56)
    ta = 0.22 + tb * 0.56
    tip = None
    for k in range(N):
        (c0, n0, w0), (c1, n1, w1) = fang[k], fang[k + 1]
        pts = [tuple(c0 - n0 * w0 / 2), tuple(c1 - n1 * w1 / 2), tuple(c1 + n1 * w1 / 2), tuple(c0 + n0 * w0 / 2)]
        if k == N - 1:
            pts = [tuple(c0 - n0 * w0 / 2), tuple(c1), tuple(c0 + n0 * w0 / 2)]
            tip = c1
        us, vs = [q[0] for q in pts], [q[1] for q in pts]
        cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
        rel = [(q[0] - cu, q[1] - cv) for q in pts]
        n = len(rel)
        area = sum(rel[i][0] * rel[(i + 1) % n][1] - rel[(i + 1) % n][0] * rel[i][1] for i in range(n)) / 2
        planes = []
        for i in range(n):
            u0, v0 = rel[i]
            u1, v1 = rel[(i + 1) % n]
            du, dv = u1 - u0, v1 - v0
            nu, nv = (dv, -du) if area > 0 else (-dv, du)
            planes.append(plane_through((0, nv, nu), (0, v0, u0)))
        half = ta + tb * cu
        for e in (-1, 1):
            planes.append(plane_through((e, 0, -tb), (e * half, 0, 0)))
        h.add("Fang%d" % k, "box", (0.44, max(vs) - min(vs), max(us) - min(us)), hp + [0, cv, cu], mat="bone", planes=planes, cast=False, union="Fang")
    # the root: a bone face and a collar of red scales
    h.add("Face", "cyl", (0.08, 0.24), hp + [0, 0.07, -0.6], R=ALONG_Z, mat="bone_dk", planes=cyl_bevel(0.08, 0.24, 0.03), smooth=40)
    h.add("Collar", "box", (0.5, 0.56, 0.12), hp + [0, 0.06, -0.38], mat="scale_red", planes=chamfer(0.5, 0.56, 0.12, 0.1, edges="z"), cast=False)
    for i, z in enumerate((-0.43, -0.33)):
        h.add("CollarScale%d" % i, "box", (0.52, 0.58, 0.03), hp + [0, 0.06, z], mat="scale_blk", planes=chamfer(0.52, 0.58, 0.03, 0.1, edges="z"), cast=False)
    # leather straps tie the tooth onto the handle
    for i, z in enumerate((-0.06, 0.1)):
        h.add("Strap%d" % i, "box", (0.47, 0.5, 0.07), hp + [0, 0.03 - 0.06 * i, z], R=Rx(-6 - 6 * i), mat="leather", planes=chamfer(0.47, 0.5, 0.07, 0.1, edges="z"))
    tip3 = hp + [0, tip[1], tip[0]]
    h.headbox(hp + [0, -0.05, 0.05], (0.5, 0.7, 1.4))
    h.fx("smoke", rf(tip3), [[90, 80, 80]], 1.5, [0.15, 0.35], area=(0.15, 0.15, 0.15))
    h.fx("embers", rf(tip3), [[255, 180, 80], [255, 90, 20]], 4, [0.04, 0.08], area=(0.15, 0.15, 0.15))
    h.light(hp, [255, 120, 40], 1.0, 6)
    H.append(h)

    # 28 ---------------------------------------------------------------------------------- CLOCKWORK HAMMER (epic)
    h = new("clockwork", "Clockwork Hammer", "Brass gears spin inside the glass head with every swing.")
    hy = 2.08
    h.shaft(-0.5, hy - 0.2, 0.108, "walnut")
    for i, y in enumerate((-0.4, 0.4, 1.0, 1.5)):
        h.band("Ring%d" % i, y, 0.122, 0.05, "brass")
    h.band("Socket", hy - 0.3, 0.16, 0.18, "brass")
    h.add("Pommel", "cyl", (0.12, 0.14), (0, -0.52, 0), mat="brass", planes=cyl_bevel(0.12, 0.14, 0.04), smooth=40)
    hp = np.array([0.0, hy, 0.0])
    h.add("Dome", "cyl", (0.76, 0.27), hp, R=ALONG_Z, mat="glass_dome", smooth=40, cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Cap%d" % i, "cyl", (0.16, 0.31), hp + [0, 0, e * 0.42], R=ALONG_Z, mat="brass", planes=cyl_bevel(0.16, 0.31, 0.04), smooth=40)
        h.add("Face%d" % i, "cyl", (0.06, 0.24), hp + [0, 0, e * 0.52], R=ALONG_Z, mat="copper", planes=cyl_bevel(0.06, 0.24, 0.02), smooth=40)
        for k in range(8):
            a = math.radians(k * 45 + 22.5)
            h.add("Rivet%d%d" % (i, k), "ball", (0.05,), hp + [math.cos(a) * 0.31, math.sin(a) * 0.31, e * 0.42], mat="copper", cast=False)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        h.add("Rod%d" % k, "cyl", (0.7, 0.025), hp + [math.cos(a) * 0.285, math.sin(a) * 0.285, 0], R=ALONG_Z, mat="brass", smooth=40, cast=False)
    gear(h, "Gear", hp + [0, 0.0, -0.08], 0.15, 0.05, 10, "brass")
    gear(h, "GearB", hp + [0, 0.12, 0.17], 0.085, 0.045, 8, "copper", phase=11)
    gear(h, "GearC", hp + [0, -0.11, 0.2], 0.075, 0.045, 8, "gold", phase=4)
    h.headbox(hp, (0.62, 0.62, 1.1))
    h.fx("glint", hp, [[255, 230, 160]], 2, [0.12, 0.22], area=(0.6, 0.6, 1.0))
    h.light(hp, [255, 200, 120], 0.8, 6)
    H.append(h)

    # 29 ---------------------------------------------------------------------------------- ROBO HAMMER (epic)
    h = new("robo", "Robo Hammer", "A white-and-blue robot head that beeps when it hits.")
    hy = 2.06
    h.shaft(-0.5, hy - 0.12, 0.104, "chrome")
    h.grip(-0.42, 0.32, 0.126, "rubber_bl", rings=3, ring_mat="rubber_dk", ring_r=0.129)
    h.add("Pommel", "ball", (0.22,), (0, -0.52, 0), mat="robo_blue")
    h.band("Neck", hy - 0.32, 0.13, 0.12, "robo_blue")
    hp = np.array([0.0, hy, 0.0])
    hs = (0.56, 0.52, 0.86)
    h.add("Head", "box", hs, hp, mat="robo_white", planes=chamfer(*hs, 0.09))
    for i, sx in enumerate((-1, 1)):
        h.add("Visor%d" % i, "box", (0.04, 0.2, 0.62), hp + [sx * 0.27, 0.05, 0], mat="robo_blue", planes=chamfer(0.04, 0.2, 0.62, 0.06, edges="x"), cast=False)
        for j, z in enumerate((-0.16, 0.16)):
            h.add("Eye%d%d" % (i, j), "cyl", (0.03, 0.065), hp + [sx * 0.292, 0.05, z], R=ALONG_X, mat="led_blue", smooth=40, cast=False)
        for k in range(3):
            h.add("Grill%d%d" % (i, k), "box", (0.02, 0.025, 0.26), hp + [sx * 0.282, -0.12 - k * 0.045, 0], mat="carbon", cast=False)
    h.add("Antenna", "cyl", (0.26, 0.022), hp + [0, 0.38, 0.12], mat="chrome", smooth=40)
    h.add("AntennaBall", "ball", (0.1,), hp + [0, 0.52, 0.12], mat="red_led", cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Ear%d" % i, "cyl", (0.12, 0.2), hp + [0, 0, e * 0.48], R=ALONG_Z, mat="robo_blue", planes=cyl_bevel(0.12, 0.2, 0.035), smooth=40)
        h.add("EarPlate%d" % i, "cyl", (0.05, 0.15), hp + [0, 0, e * 0.56], R=ALONG_Z, mat="chrome", planes=cyl_bevel(0.05, 0.15, 0.015), smooth=40)
        h.add("EarLed%d" % i, "cyl", (0.02, 0.06), hp + [0, 0, e * 0.59], R=ALONG_Z, mat="led_blue", smooth=40, cast=False)
    h.headbox(hp, (0.62, 0.75, 1.25))
    h.fx("sparks", hp, [[200, 235, 255], [70, 170, 255]], 2, [0.03, 0.07], area=(0.6, 0.5, 1.0))
    h.light(hp, [70, 170, 255], 0.9, 6)
    H.append(h)

    # 30 ---------------------------------------------------------------------------------- PHOENIX HAMMER (legendary)
    h = new("phoenix", "Phoenix Hammer", "Golden feathers and living flame. It rises with every swing.")
    hy = 2.14
    h.shaft(-0.5, hy - 0.16, 0.11, "white_gold")
    h.grip(-0.42, 0.34, 0.128, "red_lth", rings=3, ring_mat="gold", ring_r=0.131)
    for i, y in enumerate((0.7, 1.15, 1.6)):
        h.band("Flame%d" % i, y, 0.118, 0.035, "flame")
    h.band("Socket", hy - 0.28, 0.16, 0.18, "gold")
    h.band("PommelCup", -0.5, 0.12, 0.1, "gold")
    h.add("PommelFlame", "ball", (0.16,), (0, -0.6, 0), mat="sun_hot")
    hp = np.array([0.0, hy, 0.0])
    h.add("Body", "box", (0.4, 0.44, 0.74), hp, mat="gold", planes=chamfer(0.4, 0.44, 0.74, 0.1, edges="z") + gem_ends(0.2, 0.37, 0.14, sides=8, table=0.35, start=22.5))
    for i, sx in enumerate((-1, 1)):
        h.add("Gem%d" % i, "box", (0.12, 0.12, 0.12), hp + [sx * 0.19, 0.02, 0], R=Rx(45) @ Rz(35), mat="ruby", cast=False)
    for i, (dz, ang, L, m) in enumerate(((-0.12, -25, 0.36, "flame_red"), (0.0, 0, 0.46, "flame"), (0.12, 25, 0.36, "flame_red"))):
        d = (0, math.cos(math.radians(ang)), math.sin(math.radians(ang)))
        feather(h, "Crest%d" % i, hp + [0, 0.16, dz], d, L, 0.14, 0.06, m)
    wing = ((-14, 0.4, 0.15, "gold", 0.07), (10, 0.52, 0.17, "gold", 0.07), (38, 0.48, 0.16, "gold_lt", 0.07), (66, 0.38, 0.14, "gold", 0.07),
            (24, 0.38, 0.12, "flame", 0.05), (52, 0.32, 0.11, "flame", 0.05))
    for i, e in enumerate((-1, 1)):
        for j, (ang, L, W, m, T) in enumerate(wing):
            d = (0, math.sin(math.radians(ang)), e * math.cos(math.radians(ang)))
            base = hp + [0, 0.02, e * 0.26]
            if m == "flame":
                for k, x in enumerate((-0.045, 0.045)):
                    feather(h, "Wing%d%d%d" % (i, j, k), base, d, L, W, T, m, x=x)
            else:
                feather(h, "Wing%d%d" % (i, j), base, d, L, W, T, m)
    h.headbox(hp + [0, 0.1, 0], (0.5, 0.9, 1.5))
    h.fx("fire", hp + [0, 0.3, 0], [[255, 240, 140], [255, 110, 20]], 6, [0.1, 0.24], area=(0.3, 0.3, 0.5))
    h.fx("embers", hp, [[255, 200, 80], [255, 90, 20]], 4, [0.04, 0.09], area=(0.5, 0.6, 1.2))
    h.light(hp, [255, 140, 40], 1.6, 9)
    h.trail(hp + [0, 0.36, -0.7], hp + [0, -0.3, -0.7], [[255, 236, 140], [255, 100, 20]])
    H.append(h)

    # 31 ---------------------------------------------------------------------------------- TSUNAMI HAMMER (legendary)
    h = new("tsunami", "Tsunami Hammer", "A frozen wave of deep blue water, white foam on the crest.")
    hy = 2.16
    h.shaft(-0.5, hy - 0.14, 0.112, "driftwood")
    h.grip(-0.42, 0.30, 0.13, "cord", rings=4, ring_mat="driftwood", ring_r=0.133)
    h.add("PommelShell", "ball", (0.2,), (0, -0.56, 0), mat="foam")
    h.add("Knot", "ball", (0.26,), (0, hy - 0.3, 0), mat="driftwood")
    hp = np.array([0.0, hy, 0.0])
    # a barrelling wave seen from the side (u = Z, v = Y), like a surfer's wave: the sea low at the front (the striking face)
    # rising to the back; the face of the wave grows out of the sea and goes up concave, over the top, and the lip throws
    # forward and down, the barrel open under it. The face starts on the water (no gap where the wave begins).
    W = 0.46
    NS = 6
    U0, U1 = -0.62, 0.48
    def swell_v(u):
        return -0.14 + 0.24 * max(0.0, min(1.0, (u - U0) / (U1 - U0))) ** 1.7
    for k in range(NS):
        u0, u1 = U0 + (U1 - U0) * k / NS, U0 + (U1 - U0) * (k + 1) / NS
        h.poly("Swell%d" % k, [(u0, -0.3), (u1, -0.3), (u1, swell_v(u1)), (u0, swell_v(u0))], W, hp, I3, "water", union="Wave")
    RI = 0.22                                           # the barrel (inner radius)
    cu = 0.04
    C = np.array([cu, swell_v(cu) - 0.012 + RI])         # its bottom sits on the sea: the face starts on the water
    A0, A1 = -90.0, 212.0
    arc = []
    N = 16
    for k in range(N + 1):
        t = k / N
        th = math.radians(A0 + (A1 - A0) * t)
        ri = RI - 0.03 * t                              # the lip curls in a little
        tk = 0.26 * (1 - t) ** 0.85 + 0.035            # thick at the base, thin at the lip
        d = np.array([math.cos(th), math.sin(th)])
        o = C + d * (ri + tk)
        o[1] = max(o[1], -0.28)                         # (the base stays inside the sea: nothing pokes out under it)
        arc.append((C + d * ri, o))
    for k in range(N):
        (i0, o0), (i1, o1) = arc[k], arc[k + 1]
        h.poly("Crest%d" % k, [tuple(i0), tuple(i1), tuple(o1), tuple(o0)], W, hp, I3, "water", union="Wave")
    # white foam along the top of the wave and the falling lip, spray thrown off the lip
    for i, k in enumerate((7, 8, 9, 10, 11, 12, 13, 14, 15)):
        i0, o0 = arc[k]
        q = o0 * 0.72 + i0 * 0.28
        r = 0.15 - 0.008 * i
        for j, sx in enumerate((-1, 1)):
            h.add("Foam%d%d" % (i, j), "ball", (r,), hp + [sx * 0.12, q[1], q[0]], mat="foam", cast=False)
    lip = (arc[N][0] + arc[N][1]) / 2
    h.add("LipFoam", "ball", (0.11,), hp + [0, lip[1] - 0.02, lip[0]], mat="foam", cast=False)
    for i, (du, dv, d) in enumerate(((-0.1, 0.08, 0.08), (-0.18, -0.02, 0.06), (-0.05, 0.18, 0.05))):
        h.add("Spray%d" % i, "ball", (d,), hp + [0.05 * (i - 1), lip[1] + dv, lip[0] + du], mat="foam", cast=False)
    h.headbox(hp + [0, 0.05, 0], (0.56, 0.85, 1.25))
    h.fx("snow", hp + [0, 0.2, 0], [[255, 255, 255], [150, 210, 255]], 4, [0.05, 0.1], area=(0.5, 0.3, 1.0))
    h.fx("mist", hp, [[170, 220, 255]], 1.5, [0.3, 0.5], area=(0.5, 0.4, 1.0))
    h.light(hp, [60, 160, 255], 1.2, 7)
    h.trail(hp + [0, 0.36, -0.7], hp + [0, -0.3, -0.7], [[220, 245, 255], [40, 120, 255]])
    H.append(h)

    # 32 ---------------------------------------------------------------------------------- CYBER HAMMER (legendary)
    h = new("cyber", "Cyber Hammer", "Matte black with cyan circuit lines that pulse to the beat.")
    hy = 2.18
    h.shaft(-0.5, hy - 0.08, 0.108, "carbon")
    h.grip(-0.42, 0.32, 0.126, "matte_blk")
    for i, y in enumerate((-0.3, 0.1, 0.5, 0.9, 1.3, 1.7)):
        h.band("Light%d" % i, y, 0.131 if y < 0.34 else 0.116, 0.03, "cyan_neon")
    h.add("Pommel", "box", (0.24, 0.16, 0.24), (0, -0.52, 0), mat="matte_blk", planes=octagon(0.24, "y") + chamfer(0.24, 0.16, 0.24, 0.04, edges="xz"))
    h.add("PommelLed", "cyl", (0.02, 0.08), (0, -0.605, 0), mat="cyan_neon", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    w, hh, L = 0.56, 0.5, 1.22
    h.add("Head", "box", (w, hh, L), hp, mat="matte_blk", planes=chamfer(w, hh, L, 0.13, edges="z") + chamfer(w, hh, L, 0.08, edges="xy"))
    for i, e in enumerate((-1, 1)):
        h.add("Face%d" % i, "box", (0.34, 0.3, 0.06), hp + [0, 0, e * (L / 2 + 0.02)], mat="hexplate", planes=chamfer(0.34, 0.3, 0.06, 0.05, edges="z"))
        h.add("FaceLed%d" % i, "box", (0.22, 0.04, 0.02), hp + [0, 0, e * (L / 2 + 0.055)], mat="cyan_neon", cast=False)
    for i, sx in enumerate((-1, 1)):
        x = sx * (w / 2 + 0.005)
        for j, (y, z0, z1) in enumerate(((0.06, -0.5, 0.05), (-0.07, -0.45, -0.12), (0.0, 0.1, 0.45))):
            h.add("Trace%d%d" % (i, j), "box", (0.012, 0.024, z1 - z0), hp + [x, y, (z0 + z1) / 2], mat="cyan_neon", cast=False)
        h.add("TraceV%d" % i, "box", (0.012, 0.14, 0.024), hp + [x, -0.005, 0.05], mat="cyan_neon", cast=False)
        for j, (y, z) in enumerate(((0.06, -0.5), (-0.07, -0.45), (0.0, 0.45))):
            h.add("Node%d%d" % (i, j), "box", (0.016, 0.05, 0.05), hp + [x, y, z], mat="cyan_neon", cast=False)
        for j, (y, z) in enumerate(((0.05, 0.22), (0.05, 0.32), (-0.04, 0.27))):
            h.add("Hex%d%d" % (i, j), "box", (0.11, 0.11, 0.02), hp + [x, y, z], R=Ry(90), mat="hexplate", planes=hexagon(0.045), cast=False)
    h.add("TopLed", "box", (0.06, 0.012, L * 0.7), hp + [0, hh / 2 + 0.003, 0], mat="cyan_neon", cast=False)
    h.headbox(hp, (0.6, 0.56, 1.32))
    h.fx("sparks", hp, [[200, 250, 255], [60, 220, 255]], 4, [0.03, 0.07], area=(0.6, 0.5, 1.2))
    h.light(hp, [60, 220, 255], 1.4, 8)
    h.trail(hp + [0, 0.32, -0.66], hp + [0, -0.32, -0.66], [[160, 250, 255], [40, 120, 255]])
    H.append(h)

    # 33 ---------------------------------------------------------------------------------- VOID HAMMER (mythic)
    h = new("void", "Void Hammer", "A hole in the world shaped like a hammer. Light bends around it.")
    hy = 2.24
    h.shaft(-0.5, hy - 0.1, 0.112, "void_purple")
    h.grip(-0.42, 0.34, 0.13, "void_black", rings=2, ring_mat="neon_purple", ring_r=0.133)
    for i, y in enumerate((0.75, 1.25, 1.75)):
        h.band("Rim%d" % i, y, 0.12, 0.025, "neon_purple")
    h.add("Pommel", "ball", (0.22,), (0, -0.58, 0), mat="void_black")
    h.add("PommelRing", "ring", (0.03, 0.15, 0.12), (0, -0.58, 0), R=Rx(90) @ Rz(20), mat="neon_purple", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    w, L = 0.64, 1.3
    h.add("Head", "box", (w, w, L), hp, mat="void_black", planes=octagon(w, "z") + chamfer(w, w, L, 0.1, edges="xy"))
    for i, e in enumerate((-1, 1)):
        h.add("Frame%d" % i, "box", (w + 0.02, w + 0.02, 0.03), hp + [0, 0, e * (L / 2 - 0.07)], mat="neon_purple", planes=octagon(w + 0.02, "z"), cast=False)
        h.add("FaceRing%d" % i, "ring", (0.03, 0.22, 0.18), hp + [0, 0, e * (L / 2 + 0.005)], R=ALONG_Z, mat="neon_purple", smooth=40, cast=False)
    h.add("Horizon", "ring", (0.03, 0.5, 0.46), hp, R=Rx(14) @ ALONG_Z, mat="neon_purple", smooth=40, cast=False)
    h.headbox(hp, (0.7, 0.7, 1.4))
    h.fx("sparks", hp, [[220, 180, 255], [150, 70, 255]], 6, [0.04, 0.08], area=(0.7, 0.7, 1.3))
    h.fx("rise", hp, [[170, 90, 255]], 2, [0.05, 0.09], area=(0.6, 0.3, 1.1))
    h.light(hp, [150, 70, 255], 1.4, 8)
    h.trail(hp + [0, 0.36, -0.7], hp + [0, -0.36, -0.7], [[180, 110, 255], [40, 10, 80]])
    H.append(h)

    # 34 ---------------------------------------------------------------------------------- BLACK HOLE HAMMER (secret)
    h = new("blackhole", "Black Hole Hammer", "An event horizon on a handle. Whatever it hits is gone.")
    hy = 2.32
    h.shaft(-0.5, hy - 0.3, 0.114, "gunmetal")
    h.grip(-0.42, 0.34, 0.13, "black_lth", rings=3, ring_mat="accretion", ring_r=0.133)
    h.band("Socket", hy - 0.38, 0.16, 0.18, "gunmetal")
    h.add("PommelHole", "ball", (0.18,), (0, -0.6, 0), mat="void_black")
    h.add("PommelDisk", "ring", (0.025, 0.17, 0.11), (0, -0.6, 0), R=Rx(70), mat="accretion", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    h.add("Hole", "ball", (0.6,), hp, mat="void_black")
    h.add("Photon", "ring", (0.02, 0.33, 0.305), hp, R=ALONG_X, mat="accretion_hot", smooth=40, cast=False)
    tilt = Rx(18) @ Rz(8)
    h.add("DiskOuter", "ring", (0.03, 0.72, 0.52), hp, R=tilt, mat="accretion", smooth=40, cast=False)
    h.add("DiskInner", "ring", (0.035, 0.52, 0.36), hp, R=tilt, mat="accretion_hot", smooth=40, cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Arm%d" % i, "cyl", (0.26, 0.11), hp + [0, 0, e * 0.44], R=ALONG_Z, mat="gunmetal", planes=cyl_bevel(0.26, 0.11, 0.02), smooth=40)
        h.add("Face%d" % i, "cyl", (0.12, 0.22), hp + [0, 0, e * 0.62], R=ALONG_Z, mat="gunmetal", planes=cyl_bevel(0.12, 0.22, 0.035), smooth=40)
        h.add("FaceGlow%d" % i, "ring", (0.02, 0.17, 0.12), hp + [0, 0, e * 0.685], R=ALONG_Z, mat="accretion", smooth=40, cast=False)
    h.headbox(hp, (0.8, 0.8, 1.45))
    h.fx("stars", hp, [[255, 240, 200], [255, 150, 50]], 6, [0.08, 0.18], area=(0.9, 0.3, 0.9))
    h.fx("sparks", hp, [[255, 220, 150], [255, 120, 30]], 6, [0.04, 0.08], area=(0.8, 0.3, 0.8))
    h.light(hp, [255, 150, 60], 2.2, 10)
    h.trail(hp + [0, 0.36, -0.72], hp + [0, -0.36, -0.72], [[255, 240, 200], [255, 120, 30], [40, 20, 10]])
    H.append(h)

    # 35 ---------------------------------------------------------------------------------- DEMON KING HAMMER (secret)
    h = new("demon", "Demon King Hammer", "Horns, chains and a crown of fire. Forged in the deep.")
    hy = 2.34
    h.shaft(-0.5, hy - 0.12, 0.116, "basalt")
    h.grip(-0.42, 0.34, 0.132, "crimson", rings=2, ring_mat="horn", ring_r=0.135)
    for k in range(10):
        ang = math.radians(k * 70)
        y = 0.46 + k * 0.12
        radial = np.array([math.cos(ang), 0, math.sin(ang)])
        tang = np.array([-math.sin(ang), 0.35, math.cos(ang)])
        R = toward(radial) if k % 2 == 0 else toward(tang)
        h.add("Link%d" % k, "ring", (0.025, 0.065, 0.035), radial * 0.135 + [0, y, 0], R=R, mat="chain", smooth=40, cast=False)
    h.band("Socket", hy - 0.32, 0.17, 0.2, "horn")
    h.add("PommelSpike", "box", (0.2, 0.3, 0.2), (0, -0.62, 0), R=Rx(180), mat="horn", planes=spike(0.2, 0.3))
    hp = np.array([0.0, hy, 0.0])
    hs = (0.62, 0.62, 1.2)
    h.add("Head", "box", hs, hp, mat="crimson", planes=octagon(0.62, "z") + chamfer(*hs, 0.09, edges="xy"))
    for i, e in enumerate((-1, 1)):
        h.add("Face%d" % i, "box", (0.5, 0.5, 0.08), hp + [0, 0, e * 0.62], mat="horn", planes=octagon(0.5, "z"))
        h.add("FaceLava%d" % i, "ring", (0.02, 0.18, 0.12), hp + [0, 0, e * 0.665], R=ALONG_Z, mat="lava", smooth=40, cast=False)
    face_cracks(h, hp, 0.31, [(0, -0.25, 30, 0.32), (0, 0.22, -40, 0.28), (180, -0.1, 50, 0.32), (180, 0.3, -20, 0.24),
                              (270, -0.2, 20, 0.3), (225, 0.1, -35, 0.24), (315, -0.05, 25, 0.24)], "lava")
    for i, e in enumerate((-1, 1)):
        chain(h, "Horn%d" % i, hp + [0, 0.24, e * 0.3], (0, 1, e * 0.35), (1, 0, 0),
              [(0.22, 0.17, e * 22), (0.2, 0.14, e * 28), (0.18, 0.11, e * 30), (0.2, 0.08, 0)], "horn")
    h.add("Crown", "ring", (0.12, 0.17, 0.13), hp + [0, 0.37, 0], mat="gold", smooth=40)
    for k in range(5):
        a = math.radians(k * 72 + 18)
        h.add("CrownPt%d" % k, "box", (0.07, 0.12, 0.07), hp + [math.cos(a) * 0.15, 0.48, math.sin(a) * 0.15], mat="gold", planes=spike(0.07, 0.12), cast=False)
    h.add("CrownGem", "box", (0.07, 0.07, 0.07), hp + [-0.17, 0.37, 0], R=Rx(45) @ Rz(35), mat="ruby", cast=False)
    h.headbox(hp, (0.7, 1.1, 1.3))
    h.fx("embers", hp, [[255, 200, 80], [255, 60, 20]], 8, [0.05, 0.11], area=(0.6, 0.5, 1.2))
    h.fx("smoke", hp + [0, 0.3, 0], [[50, 30, 30]], 1.5, [0.25, 0.5], area=(0.4, 0.1, 0.8))
    h.light(hp, [255, 70, 30], 2.2, 10)
    h.trail(hp + [0, 0.38, -0.7], hp + [0, -0.38, -0.7], [[255, 160, 60], [200, 20, 20], [30, 0, 0]])
    H.append(h)

    # 36 ---------------------------------------------------------------------------------- CELESTIAL CREATOR (divine)
    h = new("celestial", "Celestial Creator", "White marble, gold and a halo of light. The hammer that built the sky.")
    hy = 2.44
    h.shaft(-0.52, hy - 0.22, 0.114, "ivory")
    for i, y in enumerate((-0.42, -0.1, 0.22, 0.6, 1.0, 1.4, 1.8)):
        h.band("Wrap%d" % i, y, 0.12, 0.05, "gold")
    h.band("Socket", hy - 0.3, 0.17, 0.2, "gold")
    h.add("PommelOrb", "ball", (0.2,), (0, -0.64, 0), mat="star")
    h.add("PommelHalo", "ring", (0.025, 0.17, 0.14), (0, -0.64, 0), mat="halo", smooth=40, cast=False)
    hp = np.array([0.0, hy, 0.0])
    h.add("Head", "box", (0.62, 0.62, 1.36), hp, mat="marble", planes=octagon(0.62, "z") + gem_ends(0.31, 0.68, 0.22, sides=8, table=0.45, start=22.5))
    for i, z in enumerate((-0.36, 0.0, 0.36)):
        h.add("Inlay%d" % i, "box", (0.64, 0.64, 0.04), hp + [0, 0, z], mat="gold", planes=octagon(0.64, "z"), cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Tip%d" % i, "cyl", (0.03, 0.12), hp + [0, 0, e * 0.585], R=ALONG_Z, mat="gold", smooth=40, cast=False)
    for i, sx in enumerate((-1, 1)):
        # a four-pointed star: two long thin diamonds crossed, a glowing heart
        for j, ang in enumerate((0, 90)):
            h.add("Star%d%d" % (i, j), "box", (0.03, 0.09, 0.42 if j == 0 else 0.34), hp + [sx * 0.315, 0, 0], R=Rx(ang) @ Rx(0), mat="gold",
                  planes=[plane((0, 1, 0.2), 0.042), plane((0, 1, -0.2), 0.042), plane((0, -1, 0.2), 0.042), plane((0, -1, -0.2), 0.042)], cast=False)
        h.add("StarCore%d" % i, "ball", (0.11,), hp + [sx * 0.31, 0, 0], mat="star", cast=False)
    h.add("Halo", "ring", (0.04, 0.38, 0.32), hp + [0, 0.62, 0], R=Rx(12), mat="halo", smooth=40, cast=False)
    h.add("HaloStar", "ball", (0.12,), hp + [0, 0.62, 0], mat="star", cast=False)
    h.headbox(hp, (0.7, 1.4, 1.5))
    h.fx("glint", hp, [[255, 255, 255], [255, 236, 170]], 4, [0.14, 0.3], area=(0.7, 0.7, 1.4))
    h.fx("rise", hp, [[255, 226, 140]], 3, [0.05, 0.1], area=(0.6, 0.3, 1.2))
    h.fx("stars", hp + [0, 0.6, 0], [[255, 255, 255], [255, 230, 160]], 4, [0.08, 0.16], area=(0.8, 0.2, 0.8))
    h.light(hp, [255, 236, 190], 2.6, 12)
    h.trail(hp + [0, 0.36, -0.74], hp + [0, -0.36, -0.74], [[255, 255, 255], [255, 220, 130]])
    H.append(h)

    # 37 ---------------------------------------------------------------------------------- ROYAL CROWN HAMMER (exclusive, legendary)
    h = new("crown", "Royal Crown Hammer", "A jewelled crown for a head, red velvet grip. Exclusive.")
    hy = 2.12
    h.shaft(-0.5, hy - 0.2, 0.108, "gold")
    h.grip(-0.42, 0.34, 0.128, "velvet", rings=3, ring_mat="gold", ring_r=0.131)
    h.band("Socket", hy - 0.28, 0.15, 0.16, "gold_dk")
    h.add("PommelCup", "cyl", (0.1, 0.13), (0, -0.5, 0), mat="gold", planes=cyl_bevel(0.1, 0.13, 0.03), smooth=40)
    h.add("PommelGem", "box", (0.15, 0.15, 0.15), (0, -0.6, 0), R=Rx(45) @ Rz(35), mat="ruby")
    hp = np.array([0.0, hy, 0.0])
    h.add("Velvet", "ball", (0.44,), hp + [0, 0.02, 0], mat="velvet")
    h.add("Band", "ring", (0.26, 0.31, 0.25), hp + [0, -0.02, 0], mat="gold", smooth=40)
    h.add("RimLow", "ring", (0.05, 0.33, 0.25), hp + [0, -0.14, 0], mat="gold_dk", smooth=40, cast=False)
    h.add("RimHigh", "ring", (0.04, 0.325, 0.25), hp + [0, 0.1, 0], mat="gold_dk", smooth=40, cast=False)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        p = hp + [math.cos(a) * 0.29, 0.26, math.sin(a) * 0.29]
        h.add("Point%d" % k, "box", (0.15, 0.32, 0.15), p, R=Ry(k * 60), mat="gold", planes=spike(0.15, 0.32), cast=False)
        h.add("Pearl%d" % k, "ball", (0.09,), p + [0, 0.17, 0], mat="white_gold", cast=False)
    for i, sx in enumerate((-1, 1)):
        for j, (ang, m) in enumerate(((-30, "sapphire"), (0, "ruby"), (30, "emerald"))):
            a = math.radians(ang)
            h.add("Jewel%d%d" % (i, j), "box", (0.085, 0.085, 0.085), hp + [sx * math.cos(a) * 0.318, -0.02, math.sin(a) * 0.318], R=Rx(45) @ Rz(35), mat=m, cast=False)
    for i, e in enumerate((-1, 1)):
        h.add("Arm%d" % i, "cyl", (0.3, 0.12), hp + [0, -0.02, e * 0.44], R=ALONG_Z, mat="gold", planes=cyl_bevel(0.3, 0.12, 0.02), smooth=40)
        h.add("Face%d" % i, "cyl", (0.12, 0.2), hp + [0, -0.02, e * 0.62], R=ALONG_Z, mat="gold", planes=cyl_bevel(0.12, 0.2, 0.04), smooth=40)
        h.add("FaceGem%d" % i, "box", (0.11, 0.11, 0.11), hp + [0, -0.02, e * 0.69], R=Rx(45) @ Rz(35), mat="ruby", cast=False)
    h.headbox(hp, (0.7, 0.75, 1.45))
    h.fx("glint", hp, [[255, 240, 170], [255, 255, 255]], 3, [0.12, 0.24], area=(0.7, 0.6, 1.3))
    h.fx("sparkle", hp, [[255, 90, 110], [255, 220, 120]], 3, [0.1, 0.2], area=(0.6, 0.5, 1.2))
    h.light(hp, [255, 200, 90], 1.4, 8)
    h.trail(hp + [0, 0.32, -0.68], hp + [0, -0.32, -0.68], [[255, 236, 140], [200, 20, 50]])
    H.append(h)

    # 38 ---------------------------------------------------------------------------------- GHOST HAMMER (exclusive, mythic)
    h = new("ghost", "Ghost Hammer", "Translucent and glowing, with wisps trailing behind. Exclusive.")
    hy = 2.2
    h.shaft(-0.5, hy - 0.18, 0.108, "ghost_handle")
    h.grip(-0.42, 0.30, 0.126, "ghost_handle", rings=3, ring_mat="ghost", ring_r=0.129)
    h.add("PommelWisp", "box", (0.16, 0.34, 0.16), (0, -0.62, 0), R=Rx(180), mat="ghost", planes=octagon(0.16, "y") + _shard_tip(0.16, 0.34, tip_frac=0.6))
    hp = np.array([0.0, hy, 0.0])
    h.add("Body", "box", (0.6, 0.62, 0.7), hp + [0, 0, -0.08], mat="ghost", planes=chamfer(0.6, 0.62, 0.7, 0.14))
    h.add("Brow", "ball", (0.6,), hp + [0, 0.02, -0.38], mat="ghost")
    for j, (dy, dx, bends) in enumerate(((0.12, 0.0, (-14, 22, 0)), (-0.14, 0.08, (12, -20, 0)), (-0.02, -0.1, (-8, 18, 0)))):
        chain(h, "Wisp%d" % j, hp + [dx, dy, 0.16], (0, 0.08, 1), (1, 0, 0),
              [(0.26, 0.2, bends[0] * 1.4), (0.24, 0.15, bends[1] * 1.4), (0.22, 0.11, -bends[0]), (0.22, 0.07, 0)], "ghost")
    for i, sx in enumerate((-1, 1)):
        for k, z in enumerate((-0.24, -0.06)):
            h.add("Eye%d%d" % (i, k), "cyl", (0.025, 0.065), hp + [sx * 0.3, 0.08, z], R=ALONG_X, mat="ghost_eye", smooth=40, cast=False)
        h.add("Mouth%d" % i, "ring", (0.025, 0.06, 0.035), hp + [sx * 0.3, -0.09, -0.15], R=ALONG_X, mat="ghost_eye", smooth=40, cast=False)
    h.headbox(hp, (0.66, 0.7, 1.5))
    h.fx("mist", hp, [[190, 246, 255]], 3, [0.3, 0.55], area=(0.6, 0.5, 1.2))
    h.fx("sparkle", hp, [[255, 255, 255], [160, 240, 255]], 3, [0.1, 0.2], area=(0.6, 0.6, 1.3))
    h.light(hp, [150, 240, 255], 1.6, 9)
    h.trail(hp + [0, 0.34, -0.7], hp + [0, -0.34, -0.7], [[230, 255, 255], [120, 220, 255]])
    H.append(h)

    # 39 ---------------------------------------------------------------------------------- RAINBOW PRISM HAMMER (exclusive, secret)
    h = new("prism", "Rainbow Prism Hammer", "A crystal prism that splits every hit into a rainbow. Exclusive.")
    hy = 2.3
    rb = ["rb_red", "rb_orange", "rb_yellow", "rb_green", "rb_blue", "rb_violet"]
    h.shaft(-0.5, hy - 0.26, 0.11, "chrome")
    h.grip(-0.42, 0.34, 0.128, "white_lth", rings=3, ring_mat="chrome", ring_r=0.131)
    for i, m in enumerate(rb):
        h.band("Band%d" % i, 0.6 + i * 0.2, 0.116, 0.035, m)
    h.band("Socket", hy - 0.32, 0.16, 0.18, "chrome")
    h.add("PommelPrism", "box", (0.18, 0.18, 0.18), (0, -0.6, 0), R=Rx(45) @ Rz(35), mat="prism_glass")
    hp = np.array([0.0, hy, 0.0])
    # the triangle stands in the side view (apex up, the two lower corners are the striking faces)
    tri = lambda a: [plane((0, -1, 0), a), plane((0, 0.5, 0.866), a), plane((0, 0.5, -0.866), a)]
    h.add("Prism", "box", (0.46, 1.2, 1.4), hp, mat="prism_glass", planes=tri(0.34) + chamfer(0.46, 1.2, 1.4, 0.04, edges="yz"), cast=False)
    h.add("Base", "box", (0.5, 0.1, 1.0), hp + [0, -0.33, 0], mat="chrome", planes=chamfer(0.5, 0.1, 1.0, 0.03))
    for i, e in enumerate((-1, 1)):
        h.add("Corner%d" % i, "box", (0.5, 0.16, 0.16), hp + [0, -0.28, e * 0.5], R=Rx(e * 30), mat="chrome", planes=chamfer(0.5, 0.16, 0.16, 0.03), cast=False)
    # light: a white beam enters the front face, a rainbow fans out of the back face
    def ray(name, p0, p1, w, mat):
        p0, p1 = np.array(p0, dtype=float), np.array(p1, dtype=float)
        d = p1 - p0
        L = float(np.linalg.norm(d))
        h.add(name, "box", (0.04, w, L), (p0 + p1) / 2, R=Rx(-math.degrees(math.atan2(d[1], d[2]))), mat=mat, cast=False)
    entry = hp + [0, 0.12, -0.12]
    ray("Beam", hp + [0, 0.02, -0.82], entry, 0.05, "beam_white")
    for i, m in enumerate(rb):
        ray("Ray%d" % i, entry, hp + [0, 0.24 - i * 0.075, 0.86], 0.045, m)
    h.headbox(hp, (0.5, 1.0, 1.4))
    h.fx("rainbow", hp, [[255, 80, 80], [255, 220, 80], [80, 255, 140], [80, 180, 255], [220, 100, 255]], 6, [0.1, 0.22], area=(0.7, 0.6, 1.2))
    h.fx("glint", hp, [[255, 255, 255]], 2, [0.16, 0.3], area=(0.7, 0.6, 1.2))
    h.light(hp, [255, 255, 255], 1.8, 9)
    h.trail(hp + [0, 0.34, -0.66], hp + [0, -0.34, -0.66], [[255, 60, 60], [255, 220, 60], [60, 240, 100], [60, 140, 255], [170, 80, 255]])
    H.append(h)

    # 40 ---------------------------------------------------------------------------------- FOUNDER'S HAMMER (exclusive, secret, event)
    h = new("founder", "Founder's Hammer", "Only given during the launch event. Never again.")
    hy = 2.3
    h.shaft(-0.5, hy - 0.12, 0.112, "navy")
    h.grip(-0.42, 0.2, 0.13, "black_lth", rings=2, ring_mat="gold", ring_r=0.133)
    h.band("FounderBand", 0.42, 0.13, 0.2, "gold")
    for i, y in enumerate((0.34, 0.5)):
        h.band("FounderLine%d" % i, y, 0.133, 0.02, "navy")
    for i, y in enumerate((0.95, 1.45)):
        h.band("Ring%d" % i, y, 0.12, 0.04, "gold")
    h.band("Socket", hy - 0.36, 0.17, 0.2, "gold")
    h.add("Pommel", "box", (0.18, 0.18, 0.18), (0, -0.6, 0), R=Rx(45) @ Rz(35), mat="gold")
    hp = np.array([0.0, hy, 0.0])
    hs = (0.62, 0.62, 1.16)
    h.add("Head", "box", hs, hp, mat="navy", planes=chamfer(*hs, 0.08))
    for i, e in enumerate((-1, 1)):
        h.add("Frame%d" % i, "box", (0.66, 0.66, 0.1), hp + [0, 0, e * 0.53], mat="gold",
              planes=chamfer(0.66, 0.66, 0.1, 0.08, edges="z") + chamfer(0.66, 0.66, 0.1, 0.03, edges="xy"))
        h.add("Face%d" % i, "box", (0.46, 0.46, 0.05), hp + [0, 0, e * 0.6], mat="gold_lt", planes=chamfer(0.46, 0.46, 0.05, 0.06, edges="z"))
    for i, sx in enumerate((-1, 1)):
        x = sx * 0.315
        for k in range(3):
            h.add("Logo%d%d" % (i, k), "box", (0.03, 0.12, 0.12), hp + [x, -0.11 + k * 0.11, -0.13 + k * 0.13], mat="gold", planes=chamfer(0.03, 0.12, 0.12, 0.015), cast=False)
        h.add("Underline%d" % i, "box", (0.025, 0.025, 0.42), hp + [x, -0.2, 0.0], mat="gold", cast=False)
        for k, (y, z) in enumerate(((0.17, 0.26), (0.2, -0.3), (-0.18, 0.32))):
            h.add("Star%d%d" % (i, k), "box", (0.02, 0.07, 0.07), hp + [x, y, z], R=Rx(45), mat="gold", cast=False)
    h.add("TopStar", "box", (0.12, 0.12, 0.12), hp + [0, 0.33, 0], R=Rx(45) @ Rz(35), mat="gold", cast=False)
    h.headbox(hp, (0.7, 0.7, 1.3))
    h.fx("glint", hp, [[255, 236, 150]], 3, [0.12, 0.24], area=(0.7, 0.7, 1.2))
    h.fx("stars", hp, [[255, 220, 120], [255, 255, 255]], 3, [0.08, 0.16], area=(0.7, 0.7, 1.2))
    h.light(hp, [255, 210, 110], 1.6, 9)
    h.trail(hp + [0, 0.34, -0.68], hp + [0, -0.34, -0.68], [[255, 226, 130], [30, 40, 110]])
    H.append(h)


def _shard_tip(w, ln, sides=8, tip_frac=0.38):
    """pointed tip on the +Y end of an octagonal prism (crystal shards, icicles)"""
    out = []
    a = w / 2
    tip = ln * tip_frac
    y0 = ln / 2 - tip
    for k in range(sides):
        t = math.radians(22.5 + k * 360 / sides)
        n = np.array([tip * math.cos(t), a, tip * math.sin(t)])
        p = np.array([a * math.cos(t), y0, a * math.sin(t)])
        out.append(plane_through(n, p))
    return out


def main():
    # scale: the in-hand hammers are drawn 1.25x the spec (chunky cartoon proportions next to a Roblox avatar)
    data = dict(version=2, scale=1.25, palette=PALETTE, hammers=build())
    with open(os.path.join(HERE, "spec.json"), "w") as f:
        json.dump(data, f, separators=(",", ":"))
    n = sum(len(h["pieces"]) for h in data["hammers"])
    print("hammers:", len(data["hammers"]), "pieces:", n)


if __name__ == "__main__":
    main()
