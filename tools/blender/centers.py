import sys, json, bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=sys.argv[1])
C=bpy.data.collections
GROUPS = {
    "SMB_Hall": ["ENV_Floors","ENV_Walls","ENV_Pillars","ENV_Doorways","ENV_Ceiling","ENV_Lighting","ENV_Planters"],
    "SMB_VIPLounge": ["ROOM_VIP_LOUNGE"], "SMB_Shop": ["ROOM_SHOP"], "SMB_HallOfFame": ["ROOM_HALL_OF_FAME"],
    "SMB_CustomizeTeamUp": ["ROOM_CUSTOMIZATION_TEAMUP"], "SMB_RunwayStage": ["COMPACT_RUNWAY_STAGE"],
    "SMB_DressingRoom": ["PRIVATE_MATCH_DRESSING_ROOM"], "SMB_VIPRamp": ["VIP_RAMP_ASSET"],
    "SMB_ArcadeHall": ["ARCADE_HALL"],
}
dg=bpy.context.evaluated_depsgraph_get()
out={}
for g, cs in GROUPS.items():
    objs=[o for c in cs for o in C[c].all_objects if o.type=='MESH']
    ws=[]
    for o in objs:
        ev=o.evaluated_get(dg); m=ev.to_mesh()
        ws += [o.matrix_world @ v.co for v in m.vertices]
        ev.to_mesh_clear()
    lo=Vector([min(w[i] for w in ws) for i in range(3)]); hi=Vector([max(w[i] for w in ws) for i in range(3)])
    c=(lo+hi)/2
    out[g]={"center":[round(c.x,3),round(c.z,3),round(-c.y,3)],"size":[round(hi.x-lo.x,3),round(hi.z-lo.z,3),round(hi.y-lo.y,3)]}
json.dump(out, open(sys.argv[2],"w"), indent=1); print(out)
