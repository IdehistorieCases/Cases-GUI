import bpy, pathlib
r=pathlib.Path(__file__).resolve().parents[2]/"art_source/vendor/quaternius"
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(r/'universal-base-character.glb'))
base=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('base',base.name)
bpy.ops.import_scene.gltf(filepath=str(r/'universal-animation-library.glb'))
print('ACTIONS',[a.name for a in bpy.data.actions if 'Sitting' in a.name])
for fragment in ['Sitting_Idle_Loop','Sitting_Talking_Loop']:
 act=next(a for a in bpy.data.actions if fragment in a.name)
 base.animation_data_create().action=act
 print('ACTION',act.name,'RANGE',list(act.frame_range))
 for fr in [1,10,20,30,45]:
  bpy.context.scene.frame_set(fr);bpy.context.view_layer.update()
  for n in ['pelvis','Head','hand_l','hand_r','foot_l']:
   b=base.pose.bones.get(n)
   if b:print(fr,n,tuple(round(x,3) for x in b.head))
