"""Build ONLY the vanguard two-handed hammer as a standalone review asset.

Blender 5.x background script. The character body is intentionally excluded so
the weapon silhouette, housing, framing and internal crystal can be judged on
their own before rebuilding the character around them.

Output:
  art_source/vanguard_hammer_weapon.blend   (editable source)
  assets/characters/vanguard_hammer_weapon.glb (exported preview asset)

Design intent (from reference image):
  * Dark heavy metal housing dominates the silhouette; crystal is contained.
  * Rectangular crystal well set INSIDE a raised bevelled aperture frame on
    each striking face, held by visible hex bolts.
  * Horizontal metal spine bisects each face between an upper and lower well.
  * Side windows on the front/back faces glow through narrow slits.
  * Substantial haft with wrapped grip segments, top collar, and a small
    pommel that carries a bright crystal seed.
"""
import bpy, math, os
from mathutils import Vector, Euler

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def material(name, color, metal=0.0, rough=0.5, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m


# Slightly darker base than the previous pass; the reference metal is inky
# rather than mid-grey.  The shader adds mottling on top of this.
steel = material('Vanguard_DarkForgedSteel', (0.070, 0.080, 0.105), 0.85, 0.36)
edge = material('Vanguard_WornEdges', (0.24, 0.26, 0.30), 0.82, 0.28)
rubber = material('Vanguard_JointLeather', (0.020, 0.022, 0.030), 0.05, 0.86)
trim = material('Vanguard_OldTitanium', (0.20, 0.19, 0.18), 0.78, 0.34)
# Crystal albedo is deep violet; brightness comes from emission in the shader.
crystal = material('Vanguard_VioletCrystal', (0.19, 0.010, 0.55), 0.15, 0.20, 2.4)


def _bevel(o, width, segments):
    mod = o.modifiers.new('Bevel', 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(30)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _finish(o, name, mat, bevel_w=0.012, bevel_segs=3, weighted=True):
    o.name = name
    o.data.materials.append(mat)
    if bevel_w > 0.0:
        _bevel(o, bevel_w, bevel_segs)
    for p in o.data.polygons:
        p.use_smooth = True
    if weighted and mat is not crystal:
        mod = o.modifiers.new('WeightedNormals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        mod.weight = 45
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def box(name, at, size, mat, bevel_w=0.012, bevel_segs=3, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, name, mat, bevel_w, bevel_segs)


def cylinder(name, at, radius, depth, mat, verts=32, bevel_w=0.006, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=at)
    o = bpy.context.object
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, name, mat, bevel_w, 3)


def ring(name, at, major, minor, mat, axis=(0, 0, 1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=36, minor_segments=10,
                                     location=at, major_radius=major, minor_radius=minor)
    o = bpy.context.object
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector(axis).to_track_quat('Z', 'Y')
    return _finish(o, name, mat, 0.0)


def oval_ring(name, at, radii_xyz, minor, mat, rotation=(0, 0, 0)):
    """Torus scaled per-axis to hug an elliptical body. `radii_xyz` gives the
    x/y/z half-extents the ring should sit on. Rotation is applied last so
    the ring can wrap the body around any axis.
    """
    base = max(radii_xyz)
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=10,
                                     location=at, major_radius=base,
                                     minor_radius=minor)
    o = bpy.context.object
    o.scale = (radii_xyz[0] / base, radii_xyz[1] / base, radii_xyz[2] / base)
    o.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, name, mat, 0.0)


def hex_bolt(name, at, radius, height, mat, axis='X'):
    """Small hex-headed rivet.  Axis points OUT of the bolt (its long axis)."""
    if axis == 'X':
        rot = (0, math.radians(90), 0)
    elif axis == 'Y':
        rot = (math.radians(90), 0, 0)
    else:
        rot = (0, 0, 0)
    return cylinder(name, at, radius, height, mat, verts=6, bevel_w=0.0015, rot=rot)


def crystal_chunk(name, at, size, tilt=(0, 0, 0), jitter=0.25, cuts=2):
    """Angular crystal volume: subdivided box with mildly displaced interior
    verts for a faceted surface. Outermost verts are only lightly perturbed
    along the depth axis so the block still reads as a filled aperture rather
    than a jagged shard.
    """
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = tilt
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.subdivide(number_cuts=cuts)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh = o.data
    seed = int(abs(at[0] * 100 + at[1] * 37 + at[2] * 13)) or 1
    import random
    rng = random.Random(seed)
    # Bounding half-extents so we can detect boundary verts and pin them.
    # Vertices are in local space because transform_apply used location=False,
    # so we compare v.co.x directly to hx.
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    eps = 1e-4
    for v in mesh.vertices:
        boundary_x = abs(abs(v.co.x) - hx) < eps
        boundary_y = abs(abs(v.co.y) - hy) < eps
        boundary_z = abs(abs(v.co.z) - hz) < eps
        # Interior verts move freely; boundary verts stay pinned so the
        # crystal keeps its overall rectangular volume and cleanly fills
        # the aperture.
        if not (boundary_x or boundary_y or boundary_z):
            v.co.x += (rng.random() - 0.5) * jitter * hx
            v.co.y += (rng.random() - 0.5) * jitter * hy
            v.co.z += (rng.random() - 0.5) * jitter * hz
        else:
            # Slight in-plane perturbation only, so the surface still shows
            # subtle facet breaks without eating into the silhouette.
            if boundary_x:
                v.co.y += (rng.random() - 0.5) * jitter * hy * 0.30
                v.co.z += (rng.random() - 0.5) * jitter * hz * 0.30
            if boundary_y:
                v.co.x += (rng.random() - 0.5) * jitter * hx * 0.30
                v.co.z += (rng.random() - 0.5) * jitter * hz * 0.30
            if boundary_z:
                v.co.x += (rng.random() - 0.5) * jitter * hx * 0.30
                v.co.y += (rng.random() - 0.5) * jitter * hy * 0.30
    mesh.update()
    # Small bevel to soften the sharp cube edges so the crystal reads as
    # tumbled/polished shards rather than raw cube corners. Weighted normals
    # skipped for crystal (we want flat facets, not a rounded blob).
    o2 = _finish(o, name, crystal, bevel_w=0.006, bevel_segs=2, weighted=False)
    for p in o2.data.polygons:
        p.use_smooth = False
    return o2


def crystal_spike(name, at, radius, height, tilt=(0, 0, 0), sides=10):
    """Multi-ring tapered spike. Higher `sides` gives a smoother silhouette
    while still reading as a faceted crystal because faces stay flat-shaded.
    """
    verts = []
    rings = [(0.0, 0.9), (height * 0.28, 1.05), (height * 0.58, 0.80),
             (height * 0.82, 0.42)]
    for z, scale in rings:
        for i in range(sides):
            a = i * math.tau / sides + (z * 4.0)
            verts.append((math.cos(a) * radius * scale,
                          math.sin(a) * radius * scale, z))
    tip_idx = len(verts)
    verts.append((radius * 0.10, 0, height))
    faces = []
    for ring_idx in range(len(rings) - 1):
        base = ring_idx * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((base + i, base + j,
                          base + sides + j, base + sides + i))
    top_base = (len(rings) - 1) * sides
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((top_base + i, top_base + j, tip_idx))
    faces.append(tuple(reversed(range(sides))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = at
    o.rotation_euler = tilt
    o.data.materials.append(crystal)
    # Flat facets, but the higher side count gives a rounder outline.
    for p in o.data.polygons:
        p.use_smooth = False
    return o


# --------- Hammer construction ----------
# Coordinate system in Blender: +Z up, +Y forward.  Hammer is authored so the
# haft points down along -Z and the head sits at Z=~0.
# Head extents (half): elongated along the striking (X) axis so the silhouette
# reads as a two-handed maul, not a cube. Overall 0.90 x 0.46 x 0.60.

HEAD_C = Vector((0.0, 0.0, 0.0))
# Lozenge proportions: longer along the striking axis, noticeably shorter
# vertically, moderate depth. Matches the crystal-mace head silhouette in
# reference.jpg -- wider than tall, flat-ish coin/lozenge form.
HW, HD, HH = 0.55, 0.22, 0.22  # half sizes X/Y/Z (striking, forward, up)


def _boolean_subtract(target, cutter):
    mod = target.modifiers.new('AperturePunch', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    mod.solver = 'FLOAT'
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Remove the cutter from the scene once its geometry has been baked in.
    bpy.data.objects.remove(cutter, do_unlink=True)


# Core crystal housing: subdivided cube cast to sphere, then decimated so
# the surface reads as large flat crystal facets rather than a smooth egg.
bpy.ops.mesh.primitive_cube_add(size=1, location=HEAD_C)
housing = bpy.context.object
housing.scale = (HW * 2, HD * 2, HH * 2)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
housing.select_set(True)
bpy.context.view_layer.objects.active = housing
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.subdivide(number_cuts=12)
bpy.ops.object.mode_set(mode='OBJECT')
cast_mod = housing.modifiers.new('CastToOval', 'CAST')
cast_mod.cast_type = 'SPHERE'
# Modest factor so the lozenge stays LONG on X and SHORT on Z (a strong
# factor would collapse the elongated cube into a near-sphere).
cast_mod.factor = 0.40
cast_mod.use_x = True
cast_mod.use_y = True
cast_mod.use_z = True
bpy.context.view_layer.objects.active = housing
bpy.ops.object.modifier_apply(modifier=cast_mod.name)
# Facets: decimate for chunky planar cuts, then a subdivision-surface pass
# with SMOOTH shading so the surface curves gently between facets. This
# stops the mesh from reading as "just polygon walls meeting at hard edges"
# while still giving readable large crystal facets in the silhouette.
decim = housing.modifiers.new('Facet', 'DECIMATE')
decim.ratio = 0.22               # slightly less aggressive — keep some curves
bpy.context.view_layer.objects.active = housing
bpy.ops.object.modifier_apply(modifier=decim.name)
dissolve = housing.modifiers.new('Dissolve', 'DECIMATE')
dissolve.decimate_type = 'DISSOLVE'
dissolve.angle_limit = math.radians(6.0)
bpy.context.view_layer.objects.active = housing
bpy.ops.object.modifier_apply(modifier=dissolve.name)
# Bevel facet edges so the crystal has rolled seams instead of knife-edge
# joins; then subsurf to add gentle curvature between facets.
_bevel(housing, 0.010, 3)
subsurf = housing.modifiers.new('SoftenFacets', 'SUBSURF')
subsurf.levels = 1
subsurf.render_levels = 1
bpy.context.view_layer.objects.active = housing
bpy.ops.object.modifier_apply(modifier=subsurf.name)
housing.data.materials.append(crystal)
# Smooth shading with auto-smooth so any remaining hard angles read as
# facets while wide-open faces blend smoothly. Blender 5.x uses the
# "Shade Smooth by Angle" attribute API rather than the old
# mesh.use_auto_smooth boolean.
for p in housing.data.polygons:
    p.use_smooth = True
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35.0))
except Exception:
    pass
housing.name = 'Hammer core crystal'


def barrel_taper(obj, xy_factor=0.06, z_bulge_power=1.6,
                 y_factor=None, y_power=None):
    """Scale vertices inward towards the top and bottom so the housing bulges
    in the middle instead of being a pure rectangular prism. Optionally use
    a stronger taper on the Y axis (front/back) than the X axis (striking
    axis) so the side profile reads as an oval while the striking face keeps
    its width.
    """
    mesh = obj.data
    if not mesh.vertices:
        return
    if y_factor is None:
        y_factor = xy_factor
    if y_power is None:
        y_power = z_bulge_power
    zs = [v.co.z for v in mesh.vertices]
    z_mid = (min(zs) + max(zs)) * 0.5
    z_half = max(1e-4, (max(zs) - min(zs)) * 0.5)
    for v in mesh.vertices:
        t = abs((v.co.z - z_mid) / z_half)          # 0 middle, 1 extreme
        v.co.x *= 1.0 - xy_factor * (t ** z_bulge_power)
        v.co.y *= 1.0 - y_factor * (t ** y_power)
    mesh.update()


def side_pinch(obj, factor=0.18, power=1.4):
    """Additionally squeeze the housing in Y at any Z (independent taper along
    height). Used to make the side profile read as a rounded lens instead of
    a rectangle. Also pinches at the striking-axis extremes so the head
    ends read as tapering into a rounded tip rather than a hard cut.
    """
    mesh = obj.data
    if not mesh.vertices:
        return
    xs = [v.co.x for v in mesh.vertices]
    x_mid = (min(xs) + max(xs)) * 0.5
    x_half = max(1e-4, (max(xs) - min(xs)) * 0.5)
    for v in mesh.vertices:
        # Squeeze Y based on X position: less in the middle, more at ends.
        t = abs((v.co.x - x_mid) / x_half)
        v.co.y *= 1.0 - factor * (t ** power)
    mesh.update()


def apply_subsurf(obj, levels=1):
    """Apply a subdivision surface pass, then bake, so the housing curves
    smoothly between its authored edge loops.
    """
    mod = obj.modifiers.new('HousingSubSurf', 'SUBSURF')
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def crease_boundary_of_apertures(obj, threshold_x):
    """Add a moderate edge crease weight to any edge whose both endpoints lie
    on the outer striking face (|x| ~= threshold_x). This preserves the
    aperture rim shape under subsurf so it doesn't melt into an ellipse.
    Uses the bmesh 'crease_edge' attribute layer (Blender 4.x+ location).
    """
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    crease = bm.edges.layers.float.get('crease_edge')
    if crease is None:
        crease = bm.edges.layers.float.new('crease_edge')
    for edge in bm.edges:
        a, b = edge.verts[0].co, edge.verts[1].co
        both_on_face = (abs(abs(a.x) - threshold_x) < 0.020 and
                        abs(abs(b.x) - threshold_x) < 0.020)
        if not both_on_face:
            continue
        edge[crease] = 0.7
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# Gentle Y-pinch further tapers the head ends. Skip subsurf: the housing
# is already a smooth cast-sphere and flat-shading is intentional for
# crystal facet reading.
side_pinch(housing, factor=0.12, power=1.4)

# All head-side metal shells/plating are gone. The head is a single ovoid
# crystal mass (built above) with radiating crystal wing shards (added
# below). Only the haft, its collars, pommel and yoke remain metal.
#
# Dark cage rings act as an OUTLINE tracing the head silhouette from each
# axis. Three rings: equator (waist), meridian-Y (wraps the striking axis
# over the top), and meridian-X (wraps front-to-back over the top). Ring
# thickness is meaningful — not just a hairline — so it reads as a rim
# rather than a pinstripe. Rubber (near-black) so it contrasts strongly
# with the glowing crystal underneath but doesn't look like a metal plate.
CAGE_RING_MINOR = 0.022
# Equator ring in the XY plane (axis Z): wraps horizontally around the
# waist. Slightly proud of the surface so it reads as a rim.
oval_ring('Hammer cage equator', HEAD_C,
          (HW * 1.04, HD * 1.06, 0.0), CAGE_RING_MINOR, rubber,
          rotation=(0, 0, 0))
# Meridian around Y axis (torus in XZ plane): wraps top-to-bottom through
# the striking axis. Rotate 90 deg around X so its native XY becomes XZ.
oval_ring('Hammer cage meridian-y', HEAD_C,
          (HW * 1.04, HH * 1.06, 0.0), CAGE_RING_MINOR, rubber,
          rotation=(math.radians(90), 0, 0))
# Meridian around X axis (torus in YZ plane): wraps front-to-back over
# the top of the head, completing the "outline from every angle" cage.
oval_ring('Hammer cage meridian-x', HEAD_C,
          (HD * 1.06, HH * 1.06, 0.0), CAGE_RING_MINOR, rubber,
          rotation=(0, math.radians(90), 0))

# ---- Radiating crystal wing shards ----
# Break the block silhouette by growing crystal spikes outward from the top,
# bottom and ±Y faces of the housing. These are what turn a lit metal box
# into a crystalline mass in silhouette. Inspired by (not copied from)
# reference.jpg where the crystal reads as flared plates around a metal core.

# Top: one central spike + two flanking teeth (existing) + four outboard
# wing shards leaning outward toward the striking-face ends and slightly
# forward/backward for asymmetry.
crystal_spike('Hammer top spike', Vector((0.0, 0.0, HH + 0.040)),
              radius=0.075, height=0.28, tilt=(0, 0, 0))
for s in (-1, 1):
    crystal_spike('Hammer top spike tooth',
                  Vector((s * 0.14, 0.0, HH + 0.038)),
                  radius=0.032, height=0.09,
                  tilt=(0, s * 0.9, 0))
# Outboard top wings — two per striking side, one tilted forward, one back.
for s in (-1, 1):
    for y_sign, forward_tilt in [(-1, s * 0.35), (1, s * 0.35)]:
        crystal_spike('Hammer top wing',
                      Vector((s * (HW * 0.58),
                              y_sign * HD * 0.55,
                              HH + 0.030)),
                      radius=0.048, height=0.22,
                      tilt=(y_sign * -0.35, forward_tilt, 0))

# Bottom: shards pointing DOWN and outward under the striking faces so the
# housing does not just hard-cut into the haft. Small, subtle -- these read
# as vestigial crystal fangs beneath the head.
for s in (-1, 1):
    for y_sign in (-1, 1):
        crystal_spike('Hammer bottom fang',
                      Vector((s * (HW * 0.55),
                              y_sign * HD * 0.45,
                              -HH - 0.030)),
                      radius=0.034, height=0.13,
                      tilt=(math.pi + y_sign * 0.35, s * 0.30, 0))

# ±Y side wings — big flared shards jutting forward and back from the
# housing sides. These are what break the "flat slab" side-view silhouette
# most visibly.
for y_sign in (-1, 1):
    yaw_out = math.radians(-90.0) * y_sign  # +Z (spike) rotates to point ±Y
    # Two wings per side: one tilted upward, one downward, at the striking
    # ends of the housing. Placed so they clear the aperture bolts.
    for s in (-1, 1):
        for z_lift, height_scale in [(0.16, 1.0), (-0.16, 0.85)]:
            crystal_spike('Hammer side wing',
                          Vector((s * (HW * 0.65),
                                  y_sign * (HD + 0.010),
                                  z_lift)),
                          radius=0.055,
                          height=0.24 * height_scale,
                          tilt=(yaw_out, s * 0.30 + z_lift * 1.6, 0))
    # A single centered forward blade -- taller, more aggressive lean.
    crystal_spike('Hammer side blade',
                  Vector((0.0, y_sign * (HD + 0.010), 0.02)),
                  radius=0.058, height=0.30,
                  tilt=(yaw_out, 0.0, 0))

# ---------- Haft ----------
HAFT_TOP = Vector((0.0, 0.0, -HH - 0.020))
HAFT_LEN = 1.75                  # longer two-handed reach
HAFT_R = 0.058
HAFT_BOTTOM = HAFT_TOP + Vector((0.0, 0.0, -HAFT_LEN))

cylinder('Hammer haft core', HAFT_TOP + Vector((0, 0, -HAFT_LEN * 0.5)),
         HAFT_R, HAFT_LEN, rubber, verts=24)

# Metal collar bindings at top, quarter, three-quarter and above pommel.
for z_frac, r, thick in [(0.02, 0.080, 0.038),
                         (0.20, 0.070, 0.026),
                         (0.50, 0.070, 0.026),
                         (0.80, 0.068, 0.024),
                         (0.96, 0.082, 0.032)]:
    at = HAFT_TOP + Vector((0, 0, -HAFT_LEN * z_frac))
    ring('Hammer haft collar', at, r, thick * 0.5, edge, axis=(0, 0, 1))

# Grip wrap segments -- more of them, spread over the longer haft.
for i in range(14):
    z_frac = 0.24 + i * 0.045
    at = HAFT_TOP + Vector((0, 0, -HAFT_LEN * z_frac))
    ring('Hammer grip wrap', at, HAFT_R + 0.008, 0.013, rubber, axis=(0, 0, 1))

# Pommel: heavily bevelled disk with an embedded crystal seed and radial bolts.
pommel_at = HAFT_BOTTOM + Vector((0, 0, 0.014))
cylinder('Hammer pommel disk', pommel_at, 0.088, 0.062, steel, verts=24,
         bevel_w=0.020, rot=(0, 0, 0))
crystal_chunk('Hammer pommel seed', pommel_at + Vector((0, 0, -0.018)),
              (0.052, 0.052, 0.044), jitter=0.5)
for i in range(6):
    a = i * math.tau / 6
    hex_bolt('Hammer pommel bolt',
             pommel_at + Vector((math.cos(a) * 0.062, math.sin(a) * 0.062, 0.022)),
             0.008, 0.014, trim, axis='Z')

# Head-to-haft yoke: heavier bevelled cylinder plus a decorative collar bolt
# ring so the head does not appear to float off the shaft.
cylinder('Hammer haft yoke', HAFT_TOP + Vector((0, 0, 0.016)),
         HAFT_R * 2.1, 0.075, edge, verts=24, bevel_w=0.020)
for i in range(6):
    a = i * math.tau / 6
    hex_bolt('Hammer yoke bolt',
             HAFT_TOP + Vector((math.cos(a) * 0.100, math.sin(a) * 0.100, 0.028)),
             0.010, 0.014, trim, axis='Z')

# ---------- Save editable source, then batch-export ----------
bpy.ops.wm.save_as_mainfile(
    filepath=os.path.join(ROOT, 'art_source/vanguard_hammer_weapon.blend'),
    compress=True)

# Join by material to keep the exported .glb cheap (fewer mesh instances)
# while leaving the .blend source unbatched for future edits.
for mat in [steel, edge, rubber, trim, crystal]:
    objects = [o for o in bpy.context.scene.objects
               if o.type == 'MESH' and o.data.materials and o.data.materials[0] == mat]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = mat.name

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=os.path.join(ROOT, 'assets/characters/vanguard_hammer_weapon.glb'),
    export_format='GLB', use_selection=True, export_apply=True, export_yup=True)

# Report triangle and mesh counts so downstream tools can compare vs budget.
total_tris = 0
total_meshes = 0
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        total_meshes += 1
        mesh = o.data
        for poly in mesh.polygons:
            total_tris += len(poly.vertices) - 2
print('HAMMER_WEAPON_EXPORT_COMPLETE meshes=%d tris=%d' % (total_meshes, total_tris))
