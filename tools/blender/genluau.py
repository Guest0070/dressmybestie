import json, sys
exp = sys.argv[1]
d = json.load(open(f"{exp}/blend_data.json")); centers = json.load(open(f"{exp}/centers.json"))
def v3(a): return f"Vector3.new({a[0]}, {a[1]}, {a[2]})"
def c3(a): return f"Color3.new({a[0]}, {a[1]}, {a[2]})"
L = ["--!strict", "-- GENERATED from Style_My_Bestie_Final.blend by the export script. Don't edit by hand.",
     "-- Roblox coordinates (Blender X, Z, -Y), before BlendImport's OFFSET is applied.", "",
     "export type MaterialInfo = { color: Color3, metallic: number, roughness: number, alpha: number, emission: number }",
     "export type LightInfo = { name: string, kind: string, pos: Vector3, dir: Vector3, color: Color3, energy: number, angle: number? }",
     "export type GroupInfo = { center: Vector3, size: Vector3 }", "",
     "local BlendData = {}", "", "BlendData.materials = {"]
for k, m in sorted(d["materials"].items()):
    L.append(f'\t["{k}"] = {{ color = {c3(m["color"])}, metallic = {round(m["metallic"],3)}, roughness = {round(m["roughness"],3)}, alpha = {round(m["alpha"],3)}, emission = {round(m["emission"],3)} }},')
L += ["} :: { [string]: MaterialInfo }", "", "BlendData.lights = {"]
for l in d["lights"]:
    extra = f', angle = {l["angle"]}' if "angle" in l else ""
    L.append(f'\t{{ name = "{l["name"]}", kind = "{l["type"]}", pos = {v3(l["pos"])}, dir = {v3(l["dir"])}, color = {c3(l["color"])}, energy = {l["energy"]}{extra} }},')
L += ["} :: { LightInfo }", "", "BlendData.markers = {"]
for m in d["markers"]:
    L.append(f'\t["{m["name"]}"] = {v3(m["pos"])},')
L += ["} :: { [string]: Vector3 }", "", "-- Bounding box of each imported .glb (used to put each model back exactly in place).", "BlendData.groups = {"]
for g, c in centers.items():
    L.append(f'\t{g} = {{ center = {v3(c["center"])}, size = {v3(c["size"])} }},')
L += ["} :: { [string]: GroupInfo }", "", "return BlendData", ""]
open(sys.argv[2], "w").write("\n".join(L))
