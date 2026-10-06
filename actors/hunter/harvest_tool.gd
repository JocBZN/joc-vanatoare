extends Node3D
## Close-up skinning rig. The knife follows the player's own blade over the hide
## in real time, every seam the host accepts opens as a gash on the 3D hide, and
## the free hand drags the flap during the yank. Only the very last peel is a
## canned, host-acknowledged animation.
##
## Project convention: no Tween and no GPUParticles3D. Motion is computed per
## frame and debris is a handful of cheap meshes that expire on their own.
const STROKE_SECONDS: float=.64
const FINISH_SECONDS: float=.82
const HIDE_WIDTH: float=.30
const HIDE_HEIGHT: float=.22

var _stroke_left: float=0
var _stroke_duration: float=STROKE_SECONDS
var _last_stroke: String=""
var _feedback: String=""
var _stage: int=0
var _work_point:=Vector3(0,0,-1.05)
var _knife_hand: Node3D
var _support_hand: Node3D
var _surface: MeshInstance3D
var _fur: ShaderMaterial
var _sound: AudioStreamPlayer
var _cut_sound: AudioStreamWAV
var _miss_sound: AudioStreamWAV
var _shell: bool=false
## Authoritative snapshot of the current move, plus a local clock between updates.
var _interactive: bool=false
var _state: Dictionary={}
var _clock: float=0
var _clock_step: int=-1
var _blade:=Vector2(.5,.5)
var _last_blade:=Vector2(.5,.5)
var _speed: float=0
var _opened: float=0
var _drawn_opened: float=0
var _peel: float=0
var _seam_row: float=.5
var _ribbon: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _ribbon_material: StandardMaterial3D
var _debris: Array[Dictionary]=[]
var _debris_mesh: SphereMesh
var _debris_material: StandardMaterial3D
var _spawn_clock: float=0
## Camera punch applied to the dedicated harvest camera this rig hangs under.
var _camera_base: Vector3=Vector3.ZERO
var _camera_has_base: bool=false
var _kick: float=0
var _kick_seed: float=0

func _ready() -> void:
    var skin:=_material(Color("a67d62"),.9)
    var cloth:=_material(Color("435346"),.94)
    _knife_hand=Node3D.new();_knife_hand.name="KnifeHand";add_child(_knife_hand)
    var knife: Node3D=preload("res://assets/weapons/obur/gerber_lmf.glb").instantiate()
    var factor: float=.30/16.304686
    knife.name="GerberLMF";knife.set_meta("source_author","OBUR Games")
    knife.transform=Transform3D(Basis(Vector3(-factor,0,0),Vector3(0,0,factor),Vector3(0,factor,0)),Vector3(-.0124,.012,0))
    _knife_hand.add_child(knife);GameArt.dress_scene(knife,"weapon")
    _capsule(_knife_hand,Vector3(.075,-.023,.048),.034,.14,skin,-PI*.5)
    for i in 3: _capsule(_knife_hand,Vector3(.025+float(i)*.02,.012,.035),.011,.054,skin,-.18)
    _capsule(_knife_hand,Vector3(.12,-.039,.085),.033,.16,skin,-2.11)
    _capsule(_knife_hand,Vector3(.195,-.09,.15),.047,.20,cloth,-2.11)
    _support_hand=Node3D.new();_support_hand.name="PeelingHand";add_child(_support_hand)
    _capsule(_support_hand,Vector3(-.045,-.005,.03),.034,.115,skin,PI*.5)
    for i in 4: _capsule(_support_hand,Vector3(-.01-float(i)*.018,.025,.005),.010,.068,skin,.65)
    _capsule(_support_hand,Vector3(-.07,-.015,.055),.032,.17,skin,2.05)
    _capsule(_support_hand,Vector3(-.15,-.065,.12),.046,.21,cloth,2.05)
    _surface=MeshInstance3D.new();_surface.name="WorkedHide";add_child(_surface)
    _surface.mesh=_hide_mesh()
    _fur=ShaderMaterial.new();_fur.shader=preload("res://actors/hunter/harvest_hide.gdshader")
    _surface.material_override=_fur
    _surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _ribbon=MeshInstance3D.new();_ribbon.name="Incision";add_child(_ribbon)
    _ribbon_mesh=ImmediateMesh.new();_ribbon.mesh=_ribbon_mesh
    _ribbon_material=_material(Color(.26,.05,.05),.42)
    _ribbon_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _ribbon_material.vertex_color_use_as_albedo=true
    _ribbon.material_override=_ribbon_material
    _ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _debris_mesh=SphereMesh.new();_debris_mesh.radius=.0045;_debris_mesh.height=.009
    _debris_mesh.radial_segments=6;_debris_mesh.rings=3
    _debris_material=_material(Color(.42,.07,.07),.5)
    var light:=OmniLight3D.new();light.position=Vector3(0,.2,-.55)
    light.light_color=Color("f7e6ca");light.light_energy=.13;light.omni_range=1.2
    light.shadow_enabled=false;add_child(light)
    _sound=AudioStreamPlayer.new();_sound.volume_db=-23;add_child(_sound)
    _cut_sound=_scrape_sound(false);_miss_sound=_scrape_sound(true)
    _pose(0);hide()

func configure_surface(point: Vector3,kind: StringName) -> void:
    _work_point=point+Vector3(-.075,.035,.045)
    _shell=kind==&"turtle"
    var colors: Dictionary={&"rabbit":Color("86705c"),&"deer":Color("b27b4e"),&"boar":Color("5a4940"),&"wolf":Color("737977"),&"bear":Color("493d32"),&"frog":Color("63794b"),&"turtle":Color("635a36"),&"snake":Color("7a7953"),&"crocodile":Color("666747"),&"ancient_crocodile":Color("464f3a")}
    _fur.set_shader_parameter("coat_color",colors.get(kind,Color("86705c")))
    _fur.set_shader_parameter("scales",kind in [&"frog",&"turtle",&"snake",&"crocodile",&"ancient_crocodile"])
    _fur.set_shader_parameter("shell",_shell)
    _surface.position=_work_point;_ribbon.position=_work_point;_pose(0)

func set_active(value: bool) -> void:
    if value==visible: return
    visible=value
    if value:
        var camera:=get_parent() as Camera3D
        if camera: _camera_base=camera.position;_camera_has_base=true
    else:
        _restore_camera()
        _stroke_left=0;_last_stroke="";_feedback="";_interactive=false
        _state={};_opened=0;_drawn_opened=0;_peel=0;_speed=0;_kick=0;_clock_step=-1
        for entry in _debris:
            if is_instance_valid(entry.node): entry.node.queue_free()
        _debris.clear()
        _ribbon_mesh.clear_surfaces()
        _pose(0)

func is_finishing() -> bool:
    return visible and _feedback=="complete" and _stroke_left>0

func observe(state: Dictionary) -> void:
    if not visible: return
    _state=state
    var completed: int=int(state.get("completed",0))
    var required: int=maxi(2,int(state.get("required",2)))
    _fur.set_shader_parameter("progress",float(completed)/required)
    _fur.set_shader_parameter("damage",clampf(float(state.get("wear",0))/1000.0,0,1))
    _stage=int(state.get("move",0))
    _interactive=bool(state.get("active",false))
    if int(state.get("step",-1))!=_clock_step:
        _clock_step=int(state.get("step",-1));_clock=float(state.get("move_time",0));_drawn_opened=0
    # How much of the current move is done: seams opened or fat scraped away.
    _opened=0.0
    if _stage==HarvestPattern.MOVE_SLASH:
        var hp: Array=state.get("hp",[])
        var cut: int=0
        for value in hp: cut+=1 if int(value)<=0 else 0
        _opened=float(cut)/maxf(1.0,float(hp.size()))
    elif _stage==HarvestPattern.MOVE_SCRAPE:
        var fat: Array=state.get("fat",[])
        var left: float=0.0
        for value in fat: left+=maxf(0.0,float(value))
        _opened=1.0-left/maxf(1.0,float(fat.size()))
    # Each finished step peels a little more of the hide away from the carcass.
    _peel=clampf(float(completed)/float(required),0,1)
    _fur.set_shader_parameter("peel",_peel)
    var feedback: String=String(state.get("feedback",""))
    var key: String="%s:%s:%s" % [state.get("id",0),state.get("token",0),state.get("fx",0)]
    if key==_last_stroke or feedback.is_empty(): return
    _last_stroke=key;_feedback=feedback
    var bad: bool=feedback in ["snag","wrong_way","spasm","splat","sting","chomp","fat_left","boing","overpull","rip"]
    _stroke_duration=FINISH_SECONDS if feedback=="complete" else STROKE_SECONDS
    _stroke_left=_stroke_duration if feedback=="complete" else 0.0
    _kick=.9 if feedback in ["complete","chomp","rip"] else .7 if bad else .35
    _kick_seed=float(int(state.get("fx",0))%7)
    if feedback in ["grab","fumble"]: return
    _sound.stream=_miss_sound if bad else _cut_sound;_sound.play()
    _burst(14 if feedback in ["complete","flop_perfect","flop","rip"] else 9 if bad else 5,bad,Vector2(state.get("fx_pos",Vector2(.5,.5))))

func _process(delta: float) -> void:
    if not visible: return
    _stroke_left=maxf(0,_stroke_left-delta)
    if _interactive:
        _clock+=delta
        _blade=NetworkSession.local_blade
        var moved: float=HarvestPattern.metric(_blade).distance_to(HarvestPattern.metric(_last_blade))
        _speed=lerpf(_speed,moved/maxf(delta,.001),clampf(delta*20.0,0,1))
        _last_blade=_blade
        _drawn_opened=lerpf(_drawn_opened,_opened,clampf(delta*10.0,0,1))
        _fur.set_shader_parameter("trace",_drawn_opened)
        _fur.set_shader_parameter("seam_row",_seam_row)
        _trace_pose(delta)
        _rebuild_ribbon()
    else:
        _fur.set_shader_parameter("trace",0.0)
        _ribbon_mesh.clear_surfaces()
        _pose(1.0-_stroke_left/_stroke_duration if _stroke_left>0 else 0)
    _update_debris(delta)
    _update_kick(delta)

## Hide space (0..1 across, 0..1 down) to a point on the worked patch, matching
## the mesh built by _hide_mesh so the blade never floats off the surface.
func _hide_point(point: Vector2) -> Vector3:
    var rim: float=.82+.18*sin(PI*point.y)
    return Vector3((point.x-.5)*HIDE_WIDTH*rim,(.5-point.y)*HIDE_HEIGHT,-.018*pow((point.x-.5)*2.0,2))

## Continuous pose: the knife sits under the player's blade, biting into the
## hide while it moves fast enough to cut and lifted while it only hovers.
func _trace_pose(delta: float) -> void:
    var cutting: bool=_speed>=HarvestPattern.HOVER_SPEED
    var contact: Vector3=_work_point+_hide_point(_blade)
    var press: float=.004 if cutting else .036
    var jitter: float=0.0
    var quirks: PackedStringArray=PackedStringArray(_state.get("quirks",PackedStringArray()))
    var id: int=int(_state.get("id",0))
    if quirks.has("twitch") and HarvestPattern.spasm(id,_clock,float(_state.get("twitch_period",3)))==2:
        jitter=sin(float(Time.get_ticks_msec())*.05)*.006
    _knife_hand.position=_knife_hand.position.lerp(contact+Vector3(.022,-.016+jitter,.028+press),clampf(delta*18.0,0,1))
    var tilt: float=clampf(_blade.x-.5,-.5,.5)
    _knife_hand.rotation=Vector3(-.22 if cutting else -.05,.18*tilt,-.34-.10*tilt)
    var lift: float=_peel*.05
    if _stage==HarvestPattern.MOVE_YANK and bool(_state.get("grabbed",false)):
        # The free hand has the flap: it follows the pull and lifts the hide with it.
        var flap: Dictionary=HarvestPattern.yank(id,int(_state.get("step",0)))
        var tension: float=HarvestPattern.yank_tension(flap.ring,_blade,flap.dir)
        var held: Vector3=_work_point+_hide_point(_blade)
        _support_hand.position=_support_hand.position.lerp(held+Vector3(-.03,.01,.06+tension*.08),clampf(delta*12.0,0,1))
        _support_hand.rotation=Vector3(-.45-tension*.5,0,.25)
        lift+=tension*.10
    else:
        # Otherwise it keeps the hide taut just behind the blade.
        var hold: Vector3=_work_point+_hide_point(Vector2(clampf(_blade.x-.16,0,1),clampf(_blade.y-.10,0,1)))
        _support_hand.position=_support_hand.position.lerp(hold+Vector3(-.04,.01,.05+_peel*.09),clampf(delta*10.0,0,1))
        _support_hand.rotation=Vector3(-.30-_peel*.35,0,.18)
    _surface.position=_work_point;_ribbon.position=_work_point
    _fur.set_shader_parameter("lift",lift)
    _fur.set_shader_parameter("cut",_drawn_opened)
    _fur.set_shader_parameter("finish",_feedback=="complete" and _stroke_left>0)
    _spawn_clock-=delta
    if cutting and _stage!=HarvestPattern.MOVE_YANK and _spawn_clock<=0:
        _spawn_clock=.07
        _burst(1,false,_blade)

## Every seam the host has accepted is laid on the hide as a short gash, at the
## same live position the panel draws it, so frog and snake cuts slide too.
func _rebuild_ribbon() -> void:
    _ribbon_mesh.clear_surfaces()
    if _stage!=HarvestPattern.MOVE_SLASH: return
    var hp: Array=_state.get("hp",[])
    var quirks: PackedStringArray=PackedStringArray(_state.get("quirks",PackedStringArray()))
    var id: int=int(_state.get("id",0))
    var length: float=float(_state.get("seam_length",.3))
    var jaw: int=HarvestPattern.jaw_side(id) if quirks.has("chomp") else 0
    var seams: Array=HarvestPattern.seams(id,int(_state.get("step",0)),int(_state.get("seams",2)),length,jaw)
    var begun: bool=false
    for i in mini(seams.size(),hp.size()):
        if int(hp[i])>0: continue
        var ends: Array=HarvestPattern.seam_ends(seams[i],length,HarvestPattern.drift(quirks,id,_clock,seams[i].c))
        var a:=Vector2(Vector2(ends[0]).x/HarvestPattern.ASPECT,Vector2(ends[0]).y)
        var b:=Vector2(Vector2(ends[1]).x/HarvestPattern.ASPECT,Vector2(ends[1]).y)
        var normal: Vector2=b-a
        normal=Vector2(-normal.y,normal.x).normalized()*.02
        var mid: Vector2=(a+b)*.5
        var lips: Array=[_hide_point(a),_hide_point(mid+normal),_hide_point(b),_hide_point(mid-normal)]
        if not begun:
            _ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,_ribbon_material);begun=true
        for index in [0,1,2,0,2,3]:
            _ribbon_mesh.surface_set_color(Color(.30,.06,.06) if index%2==0 else Color(.55,.14,.12))
            _ribbon_mesh.surface_add_vertex(Vector3(lips[index])+Vector3(0,0,.0035))
    if begun: _ribbon_mesh.surface_end()

## Discrete pose, used for the final peel once the hide comes free.
func _pose(t: float) -> void:
    if not is_instance_valid(_knife_hand): return
    var reach: float=_ease(clampf(t/.22,0,1))*(1.0-_ease(clampf((t-.80)/.20,0,1))) if t>0 else 0
    var draw: float=_ease(clampf((t-.20)/.38,0,1))
    var pull: float=sin(PI*clampf((t-.43)/.55,0,1)) if t>.43 else 0
    var slip: float=sin(t*PI*8)*.035*reach if _feedback in ["miss","slip"] else 0
    var stage_pull: float=.035 if _stage==0 else .095 if _stage==1 else .15
    if _feedback=="complete": stage_pull=.24
    if _shell: stage_pull*=.45
    var rest: Vector3=_work_point+Vector3(.25,-.085,.20)
    var contact: Vector3=_work_point+Vector3(.25-.21*draw,.035-.065*draw+slip,.035)
    _knife_hand.position=rest.lerp(contact,reach)
    _knife_hand.rotation=Vector3(-.12*reach,.24*reach,-.20*reach-.18*draw*reach+slip*5)
    _support_hand.position=_work_point+Vector3(-.15,-.025+.03*reach,lerpf(.17,.035,reach)+pull*stage_pull)
    _support_hand.rotation=Vector3(-pull*.45,0,.15+pull*.22)
    _surface.position=_work_point;_ribbon.position=_work_point
    _fur.set_shader_parameter("lift",pull*stage_pull+_peel*.05)
    _fur.set_shader_parameter("cut",draw*reach)
    _fur.set_shader_parameter("finish",_feedback=="complete" and _stroke_left>0)

## Cheap expiring meshes instead of a particle system, matching the muzzle-flash
## and impact effects already used by the combat code.
func _burst(count: int,dark: bool,at: Vector2=Vector2(.5,.5)) -> void:
    var origin: Vector3=_work_point+_hide_point(at)
    for i in count:
        if _debris.size()>=48: break
        var speck:=MeshInstance3D.new()
        speck.mesh=_debris_mesh
        var material: StandardMaterial3D=_debris_material.duplicate()
        material.albedo_color=Color(.30,.04,.04) if dark else Color(.52,.11,.10)
        speck.material_override=material
        speck.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        speck.position=origin
        add_child(speck)
        var angle: float=float(i)*2.399+_kick_seed
        var spread: float=.18 if dark else .12
        _debris.append({"node":speck,"life":randf_range(.30,.55),
            "velocity":Vector3(cos(angle)*spread,sin(angle)*spread+.22,.30+randf()*.25)*randf_range(.5,1.0)})

func _update_debris(delta: float) -> void:
    var index: int=_debris.size()-1
    while index>=0:
        var entry: Dictionary=_debris[index]
        entry.life=float(entry.life)-delta
        var node: MeshInstance3D=entry.node
        if float(entry.life)<=0 or not is_instance_valid(node):
            if is_instance_valid(node): node.queue_free()
            _debris.remove_at(index)
        else:
            entry.velocity=Vector3(entry.velocity)+Vector3(0,-1.6*delta,0)
            node.position+=Vector3(entry.velocity)*delta
            node.scale=Vector3.ONE*clampf(float(entry.life)*2.4,.15,1.0)
        index-=1

## A short decaying shove on the harvest camera. The base position is captured on
## activation and always restored, so repeated harvests never drift the view.
func _update_kick(delta: float) -> void:
    if not _camera_has_base: return
    var camera:=get_parent() as Camera3D
    if not camera: return
    if _kick<=0:
        camera.position=_camera_base
        return
    _kick=maxf(0,_kick-delta*3.4)
    var t: float=float(Time.get_ticks_msec())*.001
    var shake: float=_kick*_kick*.012
    camera.position=_camera_base+Vector3(sin(t*47.0+_kick_seed)*shake,cos(t*39.0+_kick_seed)*shake,-shake*.5)

func _restore_camera() -> void:
    if not _camera_has_base: return
    var camera:=get_parent() as Camera3D
    if camera: camera.position=_camera_base
    _camera_has_base=false

func _ease(t: float) -> float: return t*t*(3-2*t)

func _hide_mesh() -> ArrayMesh:
    var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
    for y in 25:
        for x in 41:
            var uv:=Vector2(float(x)/40,float(y)/24)
            vertices.append(_hide_point(uv))
            normals.append(Vector3.BACK);uvs.append(uv)
    for y in 24:
        for x in 40:
            var a: int=y*41+x
            indices.append_array([a,a+1,a+41,a+1,a+42,a+41])
    var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
    var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _material(color: Color,roughness: float) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=roughness;return material

func _capsule(parent: Node3D,point: Vector3,radius: float,height: float,material: Material,roll: float) -> void:
    var instance:=MeshInstance3D.new();var mesh:=CapsuleMesh.new()
    mesh.radius=radius;mesh.height=height;mesh.radial_segments=12;mesh.rings=4
    instance.mesh=mesh;instance.position=point;instance.rotation.z=roll;instance.material_override=material
    instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(instance)

func _scrape_sound(missed: bool) -> AudioStreamWAV:
    var audio:=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=22050
    var bytes:=PackedByteArray();var length: int=6500 if missed else 7800;bytes.resize(length*2)
    var rng:=RandomNumberGenerator.new();rng.seed=716 if missed else 529
    var smooth: float=0
    for i in length:
        var t: float=float(i)/length
        smooth=lerpf(smooth,rng.randf_range(-1,1),.7 if missed else .22)
        var sample: float=(smooth*.52+sin(float(i)*.07)*.08)*sin(PI*t)*(1-t)
        bytes.encode_s16(i*2,int(sample*21000))
    audio.data=bytes;return audio
