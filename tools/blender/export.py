import sys, json, math, bpy
from mathutils import Vector
src, outdir = sys.argv[sys.argv.index("--")+1:][:2] if "--" in sys.argv else sys.argv[1:3]
bpy.ops.wm.open_mainfile(filepath=src)
C = bpy.data.collections
MAX_TRIS = 19000

GROUPS = {
    "SMB_Hall": ["ENV_Floors","ENV_Walls","ENV_Pillars","ENV_Doorways","ENV_Ceiling","ENV_Lighting","ENV_Planters"],
    "SMB_VIPLounge": ["ROOM_VIP_LOUNGE"],
    "SMB_Shop": ["ROOM_SHOP"],
    "SMB_HallOfFame": ["ROOM_HALL_OF_FAME"],
    "SMB_CustomizeTeamUp": ["ROOM_CUSTOMIZATION_TEAMUP"],
    "SMB_RunwayStage": ["COMPACT_RUNWAY_STAGE"],
    "SMB_DressingRoom": ["PRIVATE_MATCH_DRESSING_ROOM"],
    "SMB_VIPRamp": ["VIP_RAMP_ASSET"],
    "SMB_ArcadeHall": ["ARCADE_HALL"],
}
def allobjs(c):
    out = list(c.objects)
    for ch in c.children: out += allobjs(ch)
    return out

def to_rbx(v):  # Blender Z-up (x,y,z) -> Roblox Y-up (x, z, -y)
    return [round(v.x,3), round(v.z,3), round(-v.y,3)]

def socket_value(node, name):
    s = node.inputs.get(name)
    if s is None: return None
    if s.is_linked:
        n = s.links[0].from_node
        if n.type == 'VALTORGB':  # colour ramp: average of its stops
            els = n.color_ramp.elements
            return [sum(e.color[i] for e in els)/len(els) for i in range(4)]
        if n.type == 'RGB':
            return list(n.outputs[0].default_value)
        return None
    v = s.default_value
    try: return list(v)
    except TypeError: return v

materials = {}
for m in bpy.data.materials:
    info = {"color": list(m.diffuse_color[:3]), "metallic": m.metallic, "roughness": m.roughness, "alpha": 1.0, "emission": 0.0, "transmission": 0.0}
    if m.node_tree:
        bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            c = socket_value(bsdf, "Base Color"); info["color"] = c[:3] if isinstance(c, list) else info["color"]
            for key, sock in (("metallic","Metallic"),("roughness","Roughness"),("alpha","Alpha"),("transmission","Transmission Weight"),("emission","Emission Strength")):
                v = socket_value(bsdf, sock)
                if isinstance(v, (int, float)): info[key] = v
            ec = socket_value(bsdf, "Emission Color")
            if isinstance(ec, list) and info["emission"] > 0:
                info["emissionColor"] = ec[:3]
        emit = next((n for n in m.node_tree.nodes if n.type == 'EMISSION'), None)
        if emit and not bsdf:
            info["emission"] = emit.inputs["Strength"].default_value
            info["color"] = list(emit.inputs["Color"].default_value)[:3]
    # linear -> sRGB for Roblox Color3
    def srgb(x): x = max(0.0, min(1.0, x)); return 12.92*x if x <= 0.0031308 else 1.055*(x**(1/2.4))-0.055
    info["color"] = [round(srgb(x),4) for x in info["color"]]
    if "emissionColor" in info: info["emissionColor"] = [round(srgb(x),4) for x in info["emissionColor"]]
    materials[m.name] = info

report = {"groups": {}, "decimated": []}
lights, markers = [], []
for o in bpy.data.objects:
    if o.type == 'LIGHT':
        L = o.data
        fwd = (o.matrix_world.to_3x3() @ Vector((0,0,-1))).normalized()
        e = {"name": o.name, "type": L.type, "pos": to_rbx(o.matrix_world.translation), "dir": to_rbx(fwd),
             "color": [round(x,3) for x in L.color], "energy": round(L.energy,2)}
        if L.type == 'SPOT': e["angle"] = round(math.degrees(L.spot_size),1)
        if L.type == 'AREA': e["size"] = [round(L.size,2), round(getattr(L,'size_y',L.size),2)]
        lights.append(e)
    elif o.type in ('EMPTY','CAMERA') and o.name != 'Camera':
        fwd = (o.matrix_world.to_3x3() @ Vector((0,0,-1))).normalized()
        markers.append({"name": o.name, "type": o.type, "pos": to_rbx(o.matrix_world.translation), "dir": to_rbx(fwd)})

import os
# ONLY=SMB_ArcadeHall exports just those groups (comma separated); the JSON data is always complete.
ONLY = [g for g in os.environ.get("ONLY", "").split(",") if g]
dg = bpy.context.evaluated_depsgraph_get()
for gname, colls in GROUPS.items():
    if ONLY and gname not in ONLY:
        continue
    srcobjs = []
    for cn in colls: srcobjs += [o for o in allobjs(C[cn]) if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    made = []
    for o in srcobjs:
        ev = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev)
        me.transform(o.matrix_world)
        n = bpy.data.objects.new(o.name + "_x", me)
        n["orig"] = o.name
        bpy.context.scene.collection.objects.link(n)
        made.append(n)
    pieces = []
    for n in made:
        base = n["orig"]
        bpy.ops.object.select_all(action='DESELECT')
        n.select_set(True); bpy.context.view_layer.objects.active = n
        if len(n.data.materials) > 1:
            bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
        for p in bpy.context.selected_objects:
            mat = p.data.materials[p.data.polygons[0].material_index].name if len(p.data.polygons) and p.data.materials and p.data.materials[p.data.polygons[0].material_index] else "NONE"
            # drop unused slots so each piece has exactly one material
            p.name = f"{base}__{mat}"
            if p.name != f"{base}__{mat}":  # duplicate piece name: keep it unique but readable
                p.name = f"{base}__{mat}__{len(pieces)}"
            p.data.name = p.name
            pieces.append(p)
    for p in pieces:
        tris = sum(len(f.vertices)-2 for f in p.data.polygons)
        if tris > MAX_TRIS:
            bpy.ops.object.select_all(action='DESELECT'); p.select_set(True); bpy.context.view_layer.objects.active = p
            mod = p.modifiers.new("dec", 'DECIMATE'); mod.ratio = (MAX_TRIS * 0.95) / tris
            bpy.ops.object.modifier_apply(modifier="dec")
            after = sum(len(f.vertices)-2 for f in p.data.polygons)
            report["decimated"].append([p.name, tris, after])
    bpy.ops.object.select_all(action='DESELECT')
    for p in pieces:
        if len(p.data.polygons): p.select_set(True)
    path = f"{outdir}/{gname}.glb"
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB', export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_lights=False, export_cameras=False)
    report["groups"][gname] = {"pieces": len(pieces), "tris": sum(sum(len(f.vertices)-2 for f in p.data.polygons) for p in pieces)}
    for p in pieces: bpy.data.objects.remove(p, do_unlink=True)

json.dump({"materials": materials, "lights": lights, "markers": markers}, open(f"{outdir}/blend_data.json","w"), indent=1)
json.dump(report, open(f"{outdir}/report.json","w"), indent=1)
print(json.dumps(report, indent=1))
