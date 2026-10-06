class_name WildlifeAnimal
extends CharacterBody3D
var animal_id: int
var definition: AnimalDefinition
var health: int
var dead: bool = false
var harvested: bool = false
var harvest_owner: int = 0
var harvest_completed: int = 0
var harvest_mistakes: int = 0
## Continuous damage from traced cuts, in permille, kept on the corpse so a
## cancelled or handed-over hide is never silently repaired.
var harvest_wear: int = 0
var state: String = "Idle"
var target_position := Vector3.ZERO
var target_yaw: float = 0.0
var home := Vector3.ZERO
var heading := Vector3.ZERO
var flee_until: float = 0.0
var target_peer: int = 0
var alert_clock: float = 0.0
var avoid_side: float = 1.0
var attack_clock: float = 0.0
var wander_clock: float = 0.0
var death_clock: float = 0.0
var model: Node3D
var animation: AnimationPlayer
var clips: Dictionary = {}
var label: Label3D
var rng := RandomNumberGenerator.new()
var behavior: String="Graze"
var look_target:=Vector3.ZERO
var last_seen:=Vector3.ZERO
var noise_position:=Vector3.ZERO
var noise_clock: float=0
var motion_clock: float=0
var movement_speed: float=0
var body_pitch: float=0
var ground_clock: float=0
var attack_windup: float=-1
var attack_victim: int=0
var attack_sequence: int=0
static var painted_materials: Dictionary={}
static var painted_coats: Dictionary={}
var motion: SkeletonModifier3D


func _ready() -> void:
    health = definition.max_health
    behavior="Rest" if definition.aggressive else "Graze"
    home = global_position
    target_position = global_position
    rng.seed = animal_id * 137
    look_target=global_position+Vector3.FORWARD*10
    motion_clock=animal_id*.713
    avoid_side=1.0 if animal_id%2==0 else -1.0
    collision_layer = 4
    collision_mask = 1
    add_to_group("wildlife")
    model = load(definition.model_path).instantiate()
    add_child(model)
    var animations := model.find_children("*","AnimationPlayer",true,false)
    if not animations.is_empty():
        animation = animations[0]
        for candidate in animations:
            if candidate.has_animation("Run"): animation=candidate;break
        if definition.id==&"boar": _boar_states()
        _resolve_clips()
        for key in ["Idle","Walk","Run","Graze","Alert"]:
            if clips.has(key): animation.get_animation(clips[key]).loop_mode=Animation.LOOP_LINEAR
        for key in ["Attack","Die"]:
            if clips.has(key): animation.get_animation(clips[key]).loop_mode=Animation.LOOP_NONE
    var c := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size=Vector3(definition.width if definition.width>0 else definition.height*.5,definition.height,definition.length if definition.length>0 else definition.height*1.25)
    c.shape=shape
    c.position.y=definition.height*.5
    add_child(c)
    label=Label3D.new()
    label.position.y=definition.height+.4
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size=32
    label.pixel_size=.009
    label.outline_size=10
    label.modulate=Color("f2d49f") if definition.aggressive else Color("cae4c4")
    label.visibility_range_end=75
    add_child(label)
    LocaleSettings.changed.connect(_localize)
    _localize()
    _animate("Idle")
    var skeletons:=model.find_children("*","Skeleton3D",true,false)
    if not skeletons.is_empty() and definition.id in [&"rabbit",&"deer",&"boar",&"wolf",&"bear"]:
        motion=load("res://actors/animals/animal_motion.gd").new()
        skeletons[0].add_child(motion);motion.configure(self)

    _dress_model()
    var harvest_interaction = load("res://world/interactables/animal_harvest_interactable.gd").new()
    harvest_interaction.name = "HarvestInteraction"
    add_child(harvest_interaction)

func _resolve_clips() -> void:
    var aliases: Dictionary={
        "Idle":["idle","basic","default","rest","breathe"],
        "Walk":["walk","walking","slither","crawl"],
        "Run":["run","running","gallop","hop","jump"],
        "Attack":["attack","bite","headbutt","strike"],
        "Die":["die","death","dying_000","dying.000","dead"],
        "Graze":["graze","eating"],"Alert":["alert","guard"]}
    var names:=animation.get_animation_list()
    # Exact canonical names win over Idle_HitReact and jump transition clips.
    for key in aliases:
        for clip in names:
            if str(clip).get_slice("/",str(clip).get_slice_count("/")-1).to_lower()==str(key).to_lower():
                clips[key]=clip;break
        if clips.has(key): continue
        for alias in aliases[key]:
            for clip in names:
                var lower:=str(clip).to_lower()
                if alias in lower and "reset" not in lower and "hitreact" not in lower and "toidle" not in lower:
                    clips[key]=clip;break
            if clips.has(key): break
    if definition.id==&"rabbit" and not clips.has("Walk"):
        for clip in names:
            if "jump" in str(clip).to_lower(): clips.Walk=clip;break

func _dress_model() -> void:
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        if not mesh.mesh: continue
        # The source rabbit's alpha fur cards are photographic; the skinned body remains.
        if definition.id==&"rabbit" and str(mesh.name).to_lower()=="fur": mesh.hide();continue
        for surface in mesh.mesh.get_surface_count():
            var base: Material=mesh.get_active_material(surface)
            if not base is StandardMaterial3D: continue
            var key: String=str(definition.id)+":"+str(mesh.name)+":"+str(surface)+":"+base.resource_name
            if not painted_materials.has(key):
                var material:=ShaderMaterial.new();material.shader=load("res://art/animal_surface.gdshader")
                material.set_shader_parameter("has_coat",base.albedo_texture!=null)
                if base.albedo_texture: material.set_shader_parameter("coat",_painted_coat(base.albedo_texture))
                var tint: Color=base.albedo_color
                if definition.id==&"bear" and base.albedo_texture: tint=Color("98623c")
                elif definition.id==&"turtle": tint=Color("a2b18e")
                elif definition.id in [&"crocodile",&"ancient_crocodile"]: tint=Color("768c65") if definition.id==&"crocodile" else Color("657952")
                material.set_shader_parameter("tint",tint)
                material.set_shader_parameter("back_darkening",.06)
                painted_materials[key]=material
            mesh.material_override=null
            mesh.set_surface_override_material(surface,painted_materials[key])

func _painted_coat(source: Texture2D) -> Texture2D:
    if definition.id not in [&"rabbit",&"boar"]: return source
    var key: String=str(definition.id)+":"+str(source.get_instance_id())
    if painted_coats.has(key): return painted_coats[key]
    var image: Image=source.get_image()
    if image.is_compressed(): image.decompress()
    image.convert(Image.FORMAT_RGBA8)
    image.generate_mipmaps()
    image.resize(96,96,Image.INTERPOLATE_TRILINEAR)
    for y in image.get_height():
        for x in image.get_width():
            var original: Color=image.get_pixel(x,y)
            var value: float=original.r*.30+original.g*.59+original.b*.11
            var color: Color
            if definition.id==&"rabbit":
                color=Color("c8b99d") if value>.65 else Color("a8987c") if value>.40 else Color("766e60") if value>.18 else Color("36352f")
            else:
                color=Color("ddd6c0") if value>.65 else Color("896349") if value>.28 else Color("75523b") if value>.12 else Color("604632")
            color.a=original.a
            image.set_pixel(x,y,color)
    image.generate_mipmaps()
    var texture:=ImageTexture.create_from_image(image)
    painted_coats[key]=texture
    return texture

func _localize() -> void:
    label.text=tr(definition.display_name)

func _physics_process(delta: float) -> void:
    if not NetworkSession.is_host():
        global_position=global_position.lerp(target_position,1-exp(-12*delta))
        rotation.y=lerp_angle(rotation.y,target_yaw,1-exp(-12*delta))
        return
    if dead:
        if NetworkSession.phase=="hunt" and harvest_owner==0: death_clock+=delta
        if death_clock>600: NetworkSession.remove_animal(animal_id)
        return
    if NetworkSession.phase!="hunt": velocity=Vector3.ZERO;return
    noise_clock=maxf(0,noise_clock-delta)
    attack_clock=maxf(0,attack_clock-delta)
    wander_clock-=delta
    flee_until=maxf(0,flee_until-delta)
    alert_clock=maxf(0,alert_clock-delta)
    var nearest: Hunter
    var distance: float=INF
    for p in NetworkSession.players.values():
        if not _eligible(p): continue
        var d: float=global_position.distance_to(p.global_position)
        if d<distance: nearest=p;distance=d
    var next_state := "Idle"
    var speed: float=definition.walk_speed
    var prey=_pursuit_target(nearest,distance) if definition.aggressive else null
    if prey:
        behavior="Pursue"
        look_target=prey.global_position+Vector3.UP*.8
        var reach: float=global_position.distance_to(prey.global_position)
        var destination: Vector3=prey.global_position if _can_see(prey) else last_seen
        if _can_see(prey): last_seen=prey.global_position
        # Wolves in a nearby pack spread out before closing to melee distance.
        if definition.id==&"wolf" and reach>7:
            for ally in NetworkSession.animals.values():
                if ally!=self and not ally.dead and ally.definition.id==&"wolf" and ally.target_peer==target_peer and global_position.distance_squared_to(ally.global_position)<144:
                    destination+=Vector3((prey.global_position-global_position).z,0,-(prey.global_position-global_position).x).normalized()*avoid_side*3
                    behavior="Flank";break
        heading=(destination-global_position).slide(Vector3.UP).normalized()
        speed=definition.run_speed
        next_state="Run"
        if reach<_melee_range():
            heading=Vector3.ZERO
            velocity.x=0;velocity.z=0
            next_state="Attack"
            behavior="Attack"
            if attack_clock<=0 and attack_windup<0:
                attack_clock=1.5;attack_windup=.38 if definition.id!=&"bear" else .55
                attack_victim=prey.peer_id
                attack_sequence+=1
                if animation and clips.has("Attack"): _animate("Attack",true)
    elif not definition.aggressive and nearest and (flee_until>0 or distance<9):
        behavior="Flee";look_target=nearest.global_position+Vector3.UP
        heading=(global_position-nearest.global_position).normalized()
        speed=definition.run_speed
        next_state="Run"
    elif noise_clock>0:
        look_target=noise_position+Vector3.UP
        heading=(noise_position-global_position).slide(Vector3.UP).normalized()
        if global_position.distance_to(noise_position)>3: behavior="Investigate";next_state="Walk"
        else: behavior="Alert";heading=Vector3.ZERO
    else:
        if wander_clock<=0:
            wander_clock=rng.randf_range(2,5)
            heading=Vector3(sin(rng.randf()*TAU),0,cos(rng.randf()*TAU)) if rng.randf()<.7 else Vector3.ZERO
            if global_position.distance_to(home)>22: heading=(home-global_position).normalized()
        if heading.length_squared()>.01:
            next_state="Walk";behavior="Patrol";look_target=global_position+heading*10
        else:
            behavior="Graze" if not definition.aggressive else "Rest"
            look_target=global_position+(-global_basis.z).rotated(Vector3.UP,sin(motion_clock*.35)*.3)*10
    _finish_attack(delta)
    heading.y=0
    if heading.length_squared()>.01: heading=_avoid_obstacle(heading.normalized())
    if is_on_wall(): heading=heading.rotated(Vector3.UP,delta*3)
    velocity.x=move_toward(velocity.x,heading.x*speed,delta*10)
    velocity.z=move_toward(velocity.z,heading.z*speed,delta*10)
    velocity.y=0 if is_on_floor() else velocity.y-18*delta
    if definition.aquatic and NetworkSession.world_id=="swamp" and global_position.y<.35 and NetworkSession.forest.water_depth(global_position)>.2:
        velocity.y=0;global_position.y=lerpf(global_position.y,-.08,1-exp(-9*delta))
    move_and_slide()
    if heading.length_squared()>.01: rotation.y=lerp_angle(rotation.y,atan2(-heading.x,-heading.z),1-exp(-7*delta))
    global_position.x=clampf(global_position.x,-590,590)
    global_position.z=clampf(global_position.z,-590,590)
    _animate(next_state)

func _melee_range() -> float:
    return maxf(definition.height*.65+1.2,definition.length*.45+.8)

func _eligible(hunter) -> bool:
    return is_instance_valid(hunter) and hunter.world_ready and hunter.health>0 and hunter.seat_index<0

func _pursuit_target(nearest, distance: float):
    var prey=NetworkSession.players.get(target_peer)
    if not _eligible(prey) or global_position.distance_to(prey.global_position)>definition.pursuit_range:
        target_peer=0;prey=null
    if prey and global_position.distance_to(prey.global_position)<=definition.aggro_range and _can_see(prey):
        alert_clock=definition.aggro_memory;last_seen=prey.global_position
    if alert_clock<=0: target_peer=0;prey=null
    if not prey and nearest and distance<=definition.aggro_range and _can_see(nearest):
        target_peer=nearest.peer_id;alert_clock=definition.aggro_memory;prey=nearest;last_seen=nearest.global_position
    return prey

func _avoid_obstacle(direction: Vector3) -> Vector3:
    var origin:=global_position+Vector3.UP*maxf(.65,definition.height*.5)
    var space:=get_world_3d().direct_space_state
    var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*2.4,1,[get_rid()])
    if space.intersect_ray(query).is_empty(): return direction
    for angle in [.75*avoid_side,-.75*avoid_side,1.3*avoid_side,-1.3*avoid_side]:
        var candidate:=direction.rotated(Vector3.UP,float(angle))
        query.to=origin+candidate*2.4
        if space.intersect_ray(query).is_empty():
            avoid_side=1.0 if angle>0 else -1.0
            return candidate
    return direction

func _animate(next: String, restart: bool=false) -> void:
    var previous: String=state
    state=next
    if not animation: return
    var presentation: String=next
    if next=="Idle" and behavior=="Graze" and clips.has("Graze"): presentation="Graze"
    elif next=="Idle" and behavior=="Alert" and clips.has("Alert"): presentation="Alert"
    var fallback: String="Run" if next=="Walk" else "Walk" if next=="Run" else "Idle"
    var chosen: String=str(clips.get(presentation,clips.get(fallback,clips.get("Idle",""))))
    if chosen.is_empty(): return
    if not restart and animation.assigned_animation==chosen and (animation.is_playing() or (previous==next and next in ["Die","Attack"])): return
    animation.speed_scale=.5 if next=="Walk" and not clips.has("Walk") else 2.2 if next=="Run" and not clips.has("Run") else 1.0
    animation.play(chosen,.2)

func _boar_states() -> void:
    var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
    var library:=AnimationLibrary.new()
    for key in ["Idle","Die"]:
        var clip:=Animation.new()
        clip.length=2.4 if key=="Idle" else 1.0
        clip.loop_mode=Animation.LOOP_LINEAR if key=="Idle" else Animation.LOOP_NONE
        for index in skeleton.get_bone_count():
            var bone:=skeleton.get_bone_name(index)
            var track:=clip.add_track(Animation.TYPE_ROTATION_3D)
            clip.track_set_path(track,NodePath(str(animation.get_parent().get_path_to(skeleton))+":"+bone))
            var base:=skeleton.get_bone_pose_rotation(index)
            for frame in 9:
                var t: float=frame/8.0
                var angle: float=0
                if key=="Idle" and bone=="head": angle=sin(t*TAU)*.045
                elif key=="Idle" and bone=="body": angle=sin(t*TAU)*.012
                elif key=="Die" and bone=="Hips": angle=smoothstep(0,.8,t)*1.4
                clip.rotation_track_insert_key(track,t*clip.length,base*Quaternion(Vector3.FORWARD if key=="Die" else Vector3.UP,angle))
        library.add_animation(key,clip)
    animation.add_animation_library("forest",library)

func take_damage(amount: int, source: Vector3, source_peer: int=0) -> bool:
    if not NetworkSession.is_host() or dead or amount<=0: return false
    health=maxi(0,health-amount)
    if definition.aggressive:
        flee_until=0
        var attacker=NetworkSession.players.get(source_peer)
        if not _eligible(attacker):
            var closest: float=INF
            for hunter in NetworkSession.players.values():
                if not _eligible(hunter): continue
                var distance: float=hunter.global_position.distance_to(source)
                if distance<closest: attacker=hunter;closest=distance
        if _eligible(attacker): target_peer=attacker.peer_id;alert_clock=definition.aggro_memory;last_seen=attacker.global_position
    else: flee_until=8
    if health==0:
        dead=true
        collision_layer=0
        velocity=Vector3.ZERO
        _animate("Die")
        NetworkSession.animal_died()
    return true

func snapshot() -> Dictionary:
    return {"attack_sequence":attack_sequence,"look":look_target,"behavior":behavior,"pace":movement_speed,"pitch":body_pitch,"clock":motion_clock,"id":animal_id,"kind":String(definition.id),"p":global_position,"r":rotation.y,"hp":health,"dead":dead,"state":state,"harvested":harvested,"harvest_owner":harvest_owner,"harvest_completed":harvest_completed,"harvest_mistakes":harvest_mistakes,"harvest_wear":harvest_wear}

func apply_snapshot(data: Dictionary) -> void:
    look_target=data.get("look",data.p+Vector3.FORWARD*10)
    behavior=str(data.get("behavior","Rest"));movement_speed=float(data.get("pace",0));body_pitch=float(data.get("pitch",0));motion_clock=float(data.get("clock",motion_clock))
    target_position=data.p
    target_yaw=data.r
    health=data.hp
    dead=data.dead
    harvested=bool(data.get("harvested",false));harvest_owner=int(data.get("harvest_owner",0))
    harvest_completed=int(data.get("harvest_completed",0));harvest_mistakes=int(data.get("harvest_mistakes",0))
    harvest_wear=clampi(int(data.get("harvest_wear",0)),0,1000)
    collision_layer=0 if dead else 4
    var sequence: int=int(data.get("attack_sequence",attack_sequence))
    var attack_changed: bool=sequence!=attack_sequence and str(data.state)=="Attack"
    attack_sequence=sequence
    _animate(data.state,attack_changed)

func _can_see(hunter) -> bool:
    if not _eligible(hunter): return false
    var origin:=global_position+Vector3.UP*maxf(.4,definition.height*.65)
    var end: Vector3=hunter.global_position+Vector3.UP*.8
    var query:=PhysicsRayQueryParameters3D.create(origin,end,1|16,[get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func hear_noise(point: Vector3, radius: float) -> void:
    if not NetworkSession.is_host() or dead or global_position.distance_squared_to(point)>radius*radius: return
    noise_position=point;noise_clock=8;look_target=point+Vector3.UP
    if not definition.aggressive:
        flee_until=8
        heading=(global_position-point).slide(Vector3.UP).normalized()

func _finish_attack(delta: float) -> void:
    if attack_windup<0: return
    attack_windup-=delta
    if attack_windup>0: return
    attack_windup=-1
    var victim=NetworkSession.players.get(attack_victim)
    if _eligible(victim) and global_position.distance_to(victim.global_position)<_melee_range()+.3 and _can_see(victim):
        victim.take_damage(definition.attack_damage)

func _process(delta: float) -> void:
    if not is_instance_valid(model): return
    motion_clock+=delta
    if dead: return
    if NetworkSession.is_host():
        movement_speed=Vector2(velocity.x,velocity.z).length()
        ground_clock-=delta
        if ground_clock<=0:
            ground_clock=.16
            var forward: Vector3=-global_basis.z
            var space:=get_world_3d().direct_space_state
            var positions: Array[float]=[]
            for side in [-1,1]:
                var origin: Vector3=global_position+forward*side*definition.height*.45+Vector3.UP*2
                var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*4,1,[get_rid()]))
                if not hit.is_empty(): positions.append(hit.position.y)
            if positions.size()==2: body_pitch=clampf(atan2(positions[1]-positions[0],definition.height*.9),-.3,.3)
    model.rotation.x=lerp_angle(model.rotation.x,body_pitch,1-exp(-5*delta))
    if animation and state in ["Walk","Run"]:
        var expected: float=definition.walk_speed if state=="Walk" else definition.run_speed
        var fallback_scale: float=.5 if state=="Walk" and not clips.has("Walk") else 2.2 if state=="Run" and not clips.has("Run") else 1.0
        animation.speed_scale=clampf(movement_speed/maxf(.1,expected),.35,1.4)*fallback_scale
