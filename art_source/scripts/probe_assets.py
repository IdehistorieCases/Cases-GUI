import bpy, pathlib
root=pathlib.Path(__file__).resolve().parents[2] / "art_source"
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/"vendor/quaternius/universal-base-character.glb"))
def report(label):
    print("\n=== "+label+" ===")
    for o in bpy.data.objects:
        print(o.name,o.type,"pos",tuple(round(x,3) for x in o.location),"dims",tuple(round(x,3) for x in o.dimensions))
        if o.type=="MESH":
            print("   verts",len(o.data.vertices),"faces",len(o.data.polygons),"groups",[g.name for g in o.vertex_groups[:12]],"parent",o.parent.name if o.parent else "", "modifiers",[(m.name,m.type) for m in o.modifiers])
        if o.type=="ARMATURE":
            print("   bones",len(o.data.bones),[b.name for b in o.data.bones[:40]])
    print("actions",[(a.name,len(a.fcurves) if hasattr(a,"fcurves") else "layered") for a in bpy.data.actions])
report("BASE CHARACTER")
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/"vendor/quaternius/universal-animation-library.glb"))
report("ANIMATION LIBRARY")
