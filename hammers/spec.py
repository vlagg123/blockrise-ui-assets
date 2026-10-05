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


# ------------------------------------------------------------------------------------------------ pieces
class Hammer:
    def __init__(self, tier, key, name, desc):
        self.d = dict(tier=tier, key=key, name=name, desc=desc, pieces=[], fx=[], light=None, trail=None, head=None)

    def add(self, name, shape, size, pos=(0, 0, 0), R=I3, mat="iron", planes=None, smooth=0, cast=True):
        R = np.array(R, dtype=float)
        self.d["pieces"].append(dict(name=name, shape=shape, size=[round(float(s), 4) for s in size],
                                     pos=[round(float(p), 4) for p in pos], R=[[round(float(v), 6) for v in row] for row in R],
                                     mat=mat, planes=planes or [], smooth=smooth, cast=cast))

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
    "emerald":   dict(rbx=["Glass", [16, 186, 96], 0, 0.25], bl=dict(color=[0.02, 0.75, 0.25], metal=0, rough=0.02, trans=1.0, ior=1.58, emit=0.15)),
    "green_lth": dict(rbx=["Fabric", [20, 82, 52], 0, 0], bl=dict(color=[0.01, 0.10, 0.04], metal=0, rough=0.6)),
    "platinum":  dict(rbx=["Metal", [200, 206, 222], 0, 0.22], bl=dict(color=[0.80, 0.82, 0.86], metal=1, rough=0.12)),
    "ruby":      dict(rbx=["Glass", [214, 16, 52], 0, 0.25], bl=dict(color=[0.85, 0.01, 0.06], metal=0, rough=0.02, trans=1.0, ior=1.76, emit=0.18)),
    "red_lth":   dict(rbx=["Fabric", [120, 18, 32], 0, 0], bl=dict(color=[0.22, 0.005, 0.02], metal=0, rough=0.6)),
    "sapphire":  dict(rbx=["Glass", [28, 78, 240], 0, 0.25], bl=dict(color=[0.02, 0.10, 0.95], metal=0, rough=0.02, trans=1.0, ior=1.76, emit=0.18)),
    "navy_lth":  dict(rbx=["Fabric", [26, 36, 96], 0, 0], bl=dict(color=[0.01, 0.02, 0.12], metal=0, rough=0.6)),
    "amethyst":  dict(rbx=["Glass", [146, 66, 240], 0, 0.25], bl=dict(color=[0.45, 0.10, 0.95], metal=0, rough=0.03, trans=1.0, ior=1.55, emit=0.22)),
    "obsidian":  dict(rbx=["Slate", [40, 30, 56], 0, 0.05], bl=dict(color=[0.03, 0.02, 0.05], metal=0.2, rough=0.35)),
    "neon_purple": dict(rbx=["Neon", [176, 90, 255], 0, 0], bl=dict(color=[0.45, 0.12, 1.0], metal=0, rough=0.4, emit=6.0)),
    "basalt":    dict(rbx=["Basalt", [42, 36, 36], 0, 0], bl=dict(color=[0.03, 0.025, 0.025], metal=0, rough=0.8, tex="rock")),
    "lava":      dict(rbx=["Neon", [255, 112, 20], 0, 0], bl=dict(color=[1.0, 0.25, 0.02], metal=0, rough=0.5, emit=9.0)),
    "lava_hot":  dict(rbx=["Neon", [255, 196, 70], 0, 0], bl=dict(color=[1.0, 0.62, 0.15], metal=0, rough=0.5, emit=12.0)),
    "ice":       dict(rbx=["Ice", [176, 226, 255], 0.05, 0.1], bl=dict(color=[0.55, 0.82, 1.0], metal=0, rough=0.08, trans=0.85, ior=1.31, emit=0.1)),
    "icicle":    dict(rbx=["Glass", [176, 226, 255], 0.1, 0.3], bl=dict(color=[0.75, 0.93, 1.0], metal=0, rough=0.02, trans=1.0, ior=1.31)),
    "frost_neon": dict(rbx=["Neon", [120, 230, 255], 0, 0], bl=dict(color=[0.25, 0.85, 1.0], metal=0, rough=0.4, emit=6.0)),
    "silver":    dict(rbx=["Metal", [214, 230, 244], 0, 0.22], bl=dict(color=[0.72, 0.80, 0.88], metal=1, rough=0.15)),
    "ice_lth":   dict(rbx=["Fabric", [120, 186, 250], 0, 0], bl=dict(color=[0.18, 0.48, 0.95], metal=0, rough=0.6)),
    "diamond":   dict(rbx=["Glass", [170, 232, 255], 0.08, 0.45], bl=dict(color=[0.92, 0.98, 1.0], metal=0, rough=0.0, trans=1.0, ior=2.42, emit=0.05, disp=0.08)),
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
    "void":      dict(rbx=["SmoothPlastic", [26, 18, 44], 0, 0.05], bl=dict(color=[0.015, 0.008, 0.035], metal=0.2, rough=0.3)),
    "star":      dict(rbx=["Neon", [255, 250, 230], 0, 0], bl=dict(color=[1.0, 0.98, 0.9], metal=0, rough=0.4, emit=12.0)),
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
            size = (0.02, 0.03, ln)
        else:  # top / bottom faces (normal Y)
            R = Ry(ang)
            size = (0.03, 0.02, ln)
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

    return [x.d for x in H]


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
