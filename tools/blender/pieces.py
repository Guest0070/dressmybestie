import sys, json, glob, os, bpy
out = {}
for path in sorted(glob.glob(sys.argv[1] + "/SMB_*.glb")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    group = os.path.basename(path)[:-4]
    for o in bpy.data.objects:
        if o.type != 'MESH': continue
        ws = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = [min(w[i] for w in ws) for i in range(3)]; hi = [max(w[i] for w in ws) for i in range(3)]
        c = [(lo[i]+hi[i])/2 for i in range(3)]; s = [hi[i]-lo[i] for i in range(3)]
        name = o.name
        assert name not in out, name
        # Blender (x,y,z) -> Roblox (x, z, -y); sizes (sx, sz, sy)
        out[name] = {"g": group, "c": [round(c[0],3), round(c[2],3), round(-c[1],3)], "s": [round(max(s[0],0.05),3), round(max(s[2],0.05),3), round(max(s[1],0.05),3)]}
json.dump(out, open(sys.argv[2], "w"))
print(len(out), "pieces")
