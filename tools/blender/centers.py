import sys, json, bpy
from mathutils import Vector
src, outfile = sys.argv[sys.argv.index("--")+1:][:2] if "--" in sys.argv else sys.argv[1:3]
bpy.ops.wm.open_mainfile(filepath=src)
GROUPS = {
    "SMB_Hall": ["ENV_Floors","ENV_Walls","ENV_Pillars","ENV_Doorways","ENV_Ceiling","ENV_Lighting","ENV_Planters"],
    "SMB_VIPLounge": ["ROOM_VIP_LOUNGE"], "SMB_Shop": ["ROOM_SHOP"], "SMB_HallOfFame": ["ROOM_HALL_OF_FAME"],
    "SMB_CustomizeTeamUp": ["ROOM_CUSTOMIZATION_TEAMUP"], "SMB_RunwayStage": ["CUSTOMIZABLE_RUNWAY_STAGE"],
    "SMB_StageLooks": ["RUNWAY_COSMETICS"],
    "SMB_DressingRoom": ["PRIVATE_MATCH_DRESSING_ROOM"], "SMB_VIPRamp": ["VIP_RAMP_ASSET"],
    "SMB_ArcadeHall": ["ARCADE_HALL"],
}
EXCLUDE = {"STAGE_RAMP_SLOT", "STAGE_BACKDROP_SLOT"}  # same as export.py
def allobjs(c):
    out = list(c.objects)
    for ch in c.children:
        if ch.name not in EXCLUDE: out += allobjs(ch)
    return out
C=bpy.data.collections
dg=bpy.context.evaluated_depsgraph_get()
out={}
for g, cs in GROUPS.items():
    objs=[o for c in cs for o in allobjs(C[c]) if o.type=='MESH']
    ws=[]
    for o in objs:
        ev=o.evaluated_get(dg); m=ev.to_mesh()
        ws += [o.matrix_world @ v.co for v in m.vertices]
        ev.to_mesh_clear()
    lo=Vector([min(w[i] for w in ws) for i in range(3)]); hi=Vector([max(w[i] for w in ws) for i in range(3)])
    c=(lo+hi)/2
    out[g]={"center":[round(c.x,3),round(c.z,3),round(-c.y,3)],"size":[round(hi.x-lo.x,3),round(hi.z-lo.z,3),round(hi.y-lo.y,3)]}
json.dump(out, open(outfile,"w"), indent=1); print(out)
