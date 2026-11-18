"""CASES: procedural three-piece suit on Quaternius Universal Base Character.
Run: blender -b --python art_source/scripts/build_suited_negotiator.py
Requires only Blender's built-in Python/bmesh and the locally stored source GLBs.
"""
import bpy, bmesh, math, pathlib, json, traceback
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source/vendor/quaternius"
OUTPUT = ROOT / "art_source/output"
GODOT = ROOT / "godot/assets/characters"
OUTPUT.mkdir(parents=True, exist_ok=True)
GODOT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, rgb, rough=.7, metallic=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*rgb,1)
    m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=(*rgb,1)
    p.inputs["Roughness"].default_value=rough
    p.inputs["Metallic"].default_value=metallic
    return m

navy=mat("Suit wool · midnight navy",(0.045,0.065,0.11))
trousers_mat=mat("Trousers · navy",(0.052,0.075,0.133))
waist=mat("Waistcoat · charcoal",(0.19,0.20,0.235))
shirt_mat=mat("Shirt · ivory",(0.89,0.855,0.79))
lapel_mat=mat("Jacket lapels · silk wool",(0.11,0.145,0.215))
tie_mat=mat("Tie · burgundy silk",(0.35,0.055,0.077),.35)
metal=mat("Buttons · antique brass",(0.60,0.43,0.18),.3,.5)
dark=mat("Shoes and hair · charcoal",(0.085,0.075,0.07))
wood=mat("Chair · dark mahogany",(0.20,0.092,0.04),.45)
leather=mat("Chair · olive green leather",(0.20,0.225,0.15),.65)

bpy.ops.import_scene.gltf(filepath=str(SOURCE/"universal-base-character.glb"))
body=next(o for o in bpy.data.objects if o.type=="MESH" and "SuperHero" in o.name)
rig=next(o for o in bpy.data.objects if o.type=="ARMATURE")
rig.name="CASES_Humanoid65"
body.name="OriginalQuaterniusBody"
print("BASE:",body.name,"verts",len(body.data.vertices),"bones",len(rig.data.bones))
# Source GLB has an extra locator sphere: remove any non-character helper objects.
for o in list(bpy.data.objects):
    if o!=body and o!=rig and o.type=="MESH" and o.name not in ("Eyes","Eyebrows"):
        bpy.data.objects.remove(o, do_unlink=True)

def cut_from_body(name, predicate, offset, material, thick=.002):
    """Clone rigged source topology including vertex group/armature weights."""
    mesh=body.data.copy()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    # Copy group definitions and weights to the same indices (mesh.copy carries geometry, not groups).
    for g in body.vertex_groups: obj.vertex_groups.new(name=g.name)
    for v in body.data.vertices:
        for gr in v.groups:
            obj.vertex_groups[gr.group].add([v.index],gr.weight,'REPLACE')
    obj.parent=rig
    for mod in body.modifiers:
        if mod.type=="ARMATURE":
            am=obj.modifiers.new("CASES shared 65-bone rig","ARMATURE")
            am.object=rig
    # Offset before cutting so original body normals are retained.
    for v in mesh.vertices:
        v.co += v.normal * offset
    bm=bmesh.new()
    bm.from_mesh(mesh)
    removed=[]
    for f in bm.faces:
        center=f.calc_center_median()
        if not predicate(center):
            removed.append(f)
    bmesh.ops.delete(bm,geom=removed,context='FACES')
    bm.to_mesh(mesh)
    bm.free()
    for m in list(mesh.materials): mesh.materials.pop(index=0)
    mesh.materials.append(material)
    if thick:
        sol=obj.modifiers.new("Thin cloth edge","SOLIDIFY")
        sol.thickness=thick
        sol.offset=0
    print("GARMENT",name,"verts",len(mesh.vertices),"polys",len(mesh.polygons))
    return obj

# -Y is front of imported character; seated hip is around (0,+.34,+.58).
# Tailored topology generated around bones, rather than slicing superhero skin.
# Every vertex has explicit bone weights; clothing follows the Quaternius rig.
def skinned(name,vertices,faces,weights,material):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth=True
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    ob.parent=rig
    mesh.materials.append(material)
    cache={}
    for i,w in enumerate(weights):
        for bone,value in w.items():
            if value<.001: continue
            if bone not in cache:cache[bone]=ob.vertex_groups.new(name=bone)
            cache[bone].add([i],value,'REPLACE')
    mod=ob.modifiers.new("Shared Quaternius armature","ARMATURE")
    mod.object=rig
    print("TAILORED",name,len(vertices),len(faces))
    return ob

def torso_weights(z):
    if z<1.10:return {"pelvis":.20,"spine_01":.80}
    if z<1.29:
        t=(z-1.10)/.19
        return {"spine_01":1-t,"spine_02":t}
    if z<1.45:
        t=(z-1.29)/.16
        return {"spine_02":1-t,"spine_03":t}
    return {"spine_03":1.0}

def tube(name,rings,angles,material):
    vertices=[];faces=[];weights=[]
    for z,rx,ry,cy in rings:
        for t in angles:
            vertices.append((rx*math.sin(t),cy-ry*math.cos(t),z))
            weights.append(torso_weights(z))
    n=len(angles)
    for row in range(len(rings)-1):
        for j in range(n-1):
            a=row*n+j;b=a+n
            faces.append((a,a+1,b+1,b))
    return skinned(name,vertices,faces,weights,material)

# Open front is built directly into the topology, with clean jacket edges.
jacket_rings=[
    (.99,.194,.134,.028),(1.08,.202,.140,.028),
    (1.17,.210,.146,.028),(1.28,.232,.153,.030),
    (1.40,.244,.145,.032),(1.48,.223,.139,.039),
    (1.54,.126,.116,.034)]
jacket_angles=[.34+i*(2*math.pi-.68)/20 for i in range(21)]
coat=tube("03 · Tailored midnight jacket",jacket_rings,jacket_angles,navy)

# Waistcoat fitted between the two open jacket front edges.
def make_waistcoat():
    n=13;vertices=[];weights=[];faces=[]
    for row in range(3):
        for j in range(n):
            angle=-.71+1.42*j/(n-1)
            z=(1.01 if row==0 else 1.15 if row==1 else 1.18+.21*abs(angle)/.71)
            x=.207*math.sin(angle)
            y=.031-.186*math.cos(angle)
            vertices.append((x,y,z))
            weights.append(torso_weights(z))
    for row in range(2):
        for j in range(n-1):
            a=row*n+j;b=a+n
            faces.append((a,a+1,b+1,b))
    return skinned("04 · V-neck charcoal waistcoat",vertices,faces,weights,waist)
vest=make_waistcoat()

def make_sleeve(side,label):
    lengths=[.215,.29,.39,.462,.51,.61,.675]
    radii=[.125,.123,.116,.106,.099,.089,.080]
    verts=[];weights=[];faces=[]
    for j,(x,r) in enumerate(zip(lengths,radii)):
        for k in range(12):
            t=2*math.pi*k/12
            verts.append((side*x,.065-r*math.cos(t),1.455+r*math.sin(t)))
            upper=1.0 if j<=2 else (0.75 if j==3 else 0.25 if j==4 else 0.0)
            weights.append({f"upperarm_{label}":upper,f"lowerarm_{label}":1-upper})
    for j in range(len(lengths)-1):
        for k in range(12):
            a=j*12+k;b=(j+1)*12+k;kk=(k+1)%12
            faces.append((a,j*12+kk,b//12*12+kk,b))
    skinned("Suit sleeve "+label,verts,faces,weights,navy)
    cuff_vertices=[];cuff_faces=[];cuff_weights=[]
    for ix in [.662,.713]:
        for k in range(12):
            t=2*math.pi*k/12
            cuff_vertices.append((side*ix,.065-.080*math.cos(t),1.455+.080*math.sin(t)))
            cuff_weights.append({f"lowerarm_{label}":1.0})
    for k in range(12):
        cuff_faces.append((k,(k+1)%12,12+(k+1)%12,12+k))
    skinned("Ivory shirt cuff "+label,cuff_vertices,cuff_faces,cuff_weights,shirt_mat)

def make_trouser(side,label):
    rings=[
        (1.015,.126,.121,.034),(.88,.127,.119,.034),
        (.70,.111,.113,.045),(.53,.109,.105,.068),
        (.39,.097,.093,.073),(.24,.088,.084,.083),
        (.105,.083,.077,.090)]
    verts=[];weights=[];faces=[]
    for j,(z,rx,ry,cy) in enumerate(rings):
        for k in range(14):
            a=2*math.pi*k/14
            verts.append((side*.115+rx*math.cos(a),cy+ry*math.sin(a),z))
            thigh=1.0 if j<2 else (0.85 if j==2 else 0.5 if j==3 else 0.0)
            weights.append({f"thigh_{label}":thigh,f"calf_{label}":1-thigh})
    for j in range(len(rings)-1):
        for k in range(14):
            a=j*14+k;b=(j+1)*14+k;kk=(k+1)%14
            faces.append((a,b,b//14*14+kk,j*14+kk))
    skinned("Wool trousers "+label,verts,faces,weights,trousers_mat)

for side,label in [(1,"l"),(-1,"r")]:
    make_sleeve(side,label)
    make_trouser(side,label)

def bound_mesh(name, vertices, faces, material, bone="spine_03", thickness=0):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent=rig
    g=obj.vertex_groups.new(name=bone)
    g.add(list(range(len(vertices))),1,"REPLACE")
    mod=obj.modifiers.new("Armature binding","ARMATURE");mod.object=rig
    mesh.materials.append(material)
    if thickness:
        mod2=obj.modifiers.new("Cloth thickness","SOLIDIFY");mod2.thickness=thickness
    return obj

# Shirt bib below the open lapels, skinned to the upper spine.
bound_mesh("White dress shirt front",
    [(-.065,-.157,1.505),(.065,-.157,1.505),(.035,-.17,1.26),(-.035,-.17,1.26)],
    [(0,1,2,3)],shirt_mat,thickness=.002)

# Structured lapels and a collar: hand-authored reusable polygons over the jacket.
for s in (-1,1):
    lapel=[
        (s*.188,-.132,1.442),
        (s*.089,-.150,1.449),
        (s*.063,-.163,1.330),
        (s*.151,-.16,1.252),
        (s*.165,-.138,1.355)]
    bound_mesh("05 · Suit notched lapel "+str(s),lapel,[(0,1,2),(0,2,4),(4,2,3)],lapel_mat,thickness=.003)
    collar=[
        (s*.045,-.122,1.535),
        (s*.095,-.140,1.490),
        (s*.054,-.153,1.455)]
    bound_mesh("06 · Shirt collar "+str(s),collar,[(0,1,2)],shirt_mat,thickness=.002)

# The tie is one skinned mesh bound to the upper spine.
bound_mesh("07 · Burgundy necktie",
  [(-.039,-.155,1.477),(.039,-.155,1.477),(.019,-.184,1.435),(-.019,-.184,1.435),
   (-.018,-.179,1.43),(.018,-.179,1.43),(.032,-.190,1.30),(0,-.190,1.245),(-.032,-.19,1.30)],
  [(0,1,2,3),(4,5,6,7,8)],tie_mat,thickness=.003)

def uvball(name,pos,scale,material,bone="spine_02"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=pos)
    o=bpy.context.object; o.name=name
    o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=rig
    g=o.vertex_groups.new(name=bone)
    g.add(list(range(len(o.data.vertices))),1,"REPLACE")
    am=o.modifiers.new("Armature","ARMATURE");am.object=rig
    o.data.materials.append(material)
    return o

for z in [1.09,1.16,1.23,1.30]:
    uvball("Waistcoat brass button",(.018,-.155,z),(.009,.004,.009),metal)
for s in (-1,1):
    uvball("Jacket front button",(s*.154,-.155,1.09),(.009,.005,.009),metal)

# Close-cropped hair from the same head topology; eliminates the floating "hat".
hair=mat("Hair · silvery gray",(0.20,.20,.19))
hair_cap=cut_from_body("Close-cropped gray hair",
    lambda c: c.z>1.724 and abs(c.x)<.15, .018,hair,.0)
for s in (-1,1):
    uvball("Gray moustache "+str(s),(s*.025,-.092,1.636),(.029,.014,.008),hair,"Head")
# Cover toes with smooth skinned shoe-cap meshes, not toe-shaped body duplicates.
for sign,bone in [(-1,"foot_r"),(1,"foot_l")]:
    uvball("Leather shoe "+bone,(sign*.114,-.016,.073),(.112,.171,.079),dark,bone)

# Hide the body under the full suit while retaining visible face, neck and hands.
# Removes skin/flesh protrusions at shoulder, waist and legs in seated poses.
bm=bmesh.new();bm.from_mesh(body.data)
discard=[]
for face in bm.faces:
    c=face.calc_center_median()
    visible_head = (c.z>1.565 and abs(c.x)<.16) or (c.z>1.515 and abs(c.x)<.105)
    visible_hands = abs(c.x)>.685 and c.z>1.19
    if not (visible_head or visible_hands):
        discard.append(face)
bmesh.ops.delete(bm,geom=discard,context="FACES")
bm.to_mesh(body.data);bm.free()
# Restyle originally pale green character skin to a warmer complexion.
skin=mat("Visible skin · warm beige",(0.66,.46,.34))
body.data.materials.clear()
body.data.materials.append(skin)

# Static meeting chair, aligned to the seat position in the source animation.
def cube(name,loc,size,material,bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.name=name
    o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    if bevel:
        be=o.modifiers.new("Soft edges","BEVEL");be.width=bevel;be.segments=2
        o.modifiers.new("Normals","WEIGHTED_NORMAL")
    return o

# Seated action's pelvis z≈0.584 and y≈0.337. Cushion top z≈0.54.
cube("Chair · seat wood",(0,.35,.475),(.64,.61,.10),wood)
cube("Chair · padded seat",(0,.34,.535),(.58,.55,.035),leather)
cube("Chair · high upholstered back",(0,.668,.95),(.59,.09,.79),wood)
cube("Chair · back upholstery",(0,.611,.98),(.51,.042,.62),leather)
for s in (-1,1):
    cube("Chair · front leg",(s*.265,.095,.24),(.065,.07,.48),wood)
    cube("Chair · rear leg",(s*.265,.60,.245),(.065,.08,.49),wood)
    cube("Chair · armrest",(s*.355,.31,.73),(.07,.60,.055),wood)
    cube("Chair · armrest support",(s*.355,.55,.64),(.055,.07,.18),wood)

# Bring in the compatible seated Quaternius clips, then strip mannequin scene objects.
old_objs=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/"universal-animation-library.glb"))
for obj in list(bpy.data.objects):
    if obj not in old_objs:
        bpy.data.objects.remove(obj,do_unlink=True)
clips={
    "SeatedIdle":next(a for a in bpy.data.actions if "Sitting_Idle_Loop" in a.name),
    "SeatedTalking":next(a for a in bpy.data.actions if "Sitting_Talking_Loop" in a.name)}
rig.animation_data_create()
for name,act in clips.items():
    act.use_fake_user=True
    t=rig.animation_data.nla_tracks.new()
    t.name=name
    strip=t.strips.new(name,0,act)
    strip.action_frame_start=act.frame_range[0]
    strip.action_frame_end=act.frame_range[1]
    strip.repeat=1
print("NLA",[(t.name,[s.action.name for s in t.strips]) for t in rig.animation_data.nla_tracks])
# The source library contains unrelated actions; only keep the two seated test clips.
for other_action in list(bpy.data.actions):
    if other_action not in clips.values():
        bpy.data.actions.remove(other_action)

# Export only character, clothes, chair; no test lights and camera.
path=GODOT/"cases_suited_negotiator.glb"
bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
    export_animations=True,export_nla_strips=True,
    export_apply=False,export_yup=True)
print("EXPORTED",str(path),path.stat().st_size)
# Save editable sources including all actions and procedural modeling.
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT/"cases_suited_negotiator.blend"))
print("SAVED BLEND")

# Preview render for the seated idle and talking states, without combining NLA layers.
for track in rig.animation_data.nla_tracks: track.mute=True
bpy.ops.object.camera_add(location=(1.7,-2.65,1.6))
camera=bpy.context.object;camera.name="Preview camera"
direction=Vector((0,.25,.92))-camera.location
camera.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
bpy.context.scene.camera=camera
bpy.ops.object.light_add(type="AREA",location=(1.4,-2.2,4.0))
light=bpy.context.object;light.data.energy=690;light.data.shape="DISK";light.data.size=4
floor=mat("Backdrop",(0.42,0.42,0.40))
cube("Preview ground",(0,0,-.064),(6,6,.09),floor,.0)
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE_NEXT"
scene.render.resolution_x=1100;scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.world.color=(.35,.35,.35)
for filename,action,frame in [("seated_idle.png",clips["SeatedIdle"],15),("seated_talking.png",clips["SeatedTalking"],22)]:
    rig.animation_data.action=action
    scene.frame_set(frame)
    scene.render.filepath=str(OUTPUT/filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED",scene.render.filepath)
print("DONE")
