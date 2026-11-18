import bpy, mathutils, pathlib
root=pathlib.Path(__file__).resolve().parents[2]
p=root/"art_source/vendor/quaternius/universal-base-character.glb"
bpy.ops.import_scene.gltf(filepath=str(p))
for o in bpy.data.objects:
 if o.type=="MESH":
  print(o.name, "ranges", [(round(min(v.co[i] for v in o.data.vertices),3),round(max(v.co[i] for v in o.data.vertices),3)) for i in range(3)])
  if o.name in {"Eyes","SuperHero_Male"}:
   print(" centroids",tuple(round(sum(v.co[i] for v in o.data.vertices)/len(o.data.vertices),3) for i in range(3)))
a=bpy.data.objects['Armature']
for name in ['pelvis','spine_01','spine_02','spine_03','neck_01','Head','upperarm_l','hand_l','thigh_l','calf_l','foot_l']:
 b=a.data.bones.get(name)
 if b: print(name,"head",tuple(round(x,3) for x in b.head_local),"tail",tuple(round(x,3) for x in b.tail_local))
