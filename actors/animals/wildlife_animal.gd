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
var scare_clock: float = 0.0

## The gramophone: for a few seconds even a predator bolts away from the hunters.
func scare(_from: Vector3,seconds: float) -> void:
    if definition.boss: seconds*=.35
    scare_clock=seconds;flee_until=seconds;leaping=false;leap_windup=-1;attack_windup=-1
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
## Swimmers (ocean): the pounce is a lunge, then the animal breaks off and circles.
var lunge_time: float=0
var lunge_dir:=Vector3.ZERO
var lunge_hit: bool=false
var retreat_clock: float=0
var circle_side: float=1.0
var swim_heading:=Vector3.ZERO
## Colossal squid: the tentacle combo still to come, and the ink cloud timers.
var attack_combo: int=0
var ink_clock: float=0
var ink_time: float=0
var leap_clock: float=0
var leap_windup: float=-1
var leaping: bool=false
var leap_time: float=0
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
    # Wildlife walks around the truck, not through it.
    collision_mask = 1|16
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
    c.position.y=0.0 if definition.swimmer else definition.height*.5
    add_child(c)
    circle_side=1.0 if animal_id%2==0 else -1.0
    label=Label3D.new()
    label.position.y=(definition.height*.6+.7) if definition.swimmer else definition.height+.4
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size=32
    label.pixel_size=.009
    label.outline_size=10
    label.modulate=Color("f2d49f") if definition.aggressive else Color("cae4c4")
    label.visibility_range_end=75
    if definition.boss:
        label.font_size=46;label.modulate=Color("ffd35a");label.outline_modulate=Color("3a1d05");label.visibility_range_end=160
        # Above the firs on the bear's back and the croc's harpoon.
        label.position.y=definition.height*(.7 if definition.swimmer else 1.0)+(2.4 if definition.id==&"ancient_bear" else 1.6)
    add_child(label)
    LocaleSettings.changed.connect(_localize)
    _localize()
    _animate("Idle")
    var skeletons:=model.find_children("*","Skeleton3D",true,false)
    if not skeletons.is_empty() and definition.id in [&"rabbit",&"deer",&"boar",&"wolf",&"bear",&"ancient_bear"]:
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
        # Boss pieces (moss, crystals, harpoon...) keep their own toon colours.
        if not mesh.mesh or mesh.has_meta("styled"): continue
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
                elif definition.id==&"ancient_bear": tint=Color("5a4838")
                elif definition.id==&"albino_crocodile": tint=Color("f6e4dc")
                elif definition.id==&"turtle": tint=Color("a2b18e")
                elif definition.id in [&"crocodile",&"ancient_crocodile"]: tint=Color("768c65") if definition.id==&"crocodile" else Color("657952")
                material.set_shader_parameter("tint",tint)
                material.set_shader_parameter("back_darkening",.06)
                # The albino keeps only a ghost of the crocodile's markings.
                material.set_shader_parameter("lift",.9 if definition.id==&"albino_crocodile" else 0.0)
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
        if definition.swimmer:
            # A dead sea creature rolls belly-up and drifts to the surface, where it can be skinned.
            var lift: float=clampf((-.75-global_position.y)*.7,-.2,1.2)
            velocity=Vector3(velocity.x*.9,lift,velocity.z*.9)
            if lift!=0.0 or velocity.length()>.02: move_and_slide()
            return
        # Shot out of a pounce: finish the fall instead of hanging in the air.
        if not is_on_floor():
            velocity.x=0;velocity.z=0;velocity.y-=18*delta
            move_and_slide()
        return
    if NetworkSession.phase!="hunt": velocity=Vector3.ZERO;return
    leap_clock=maxf(0,leap_clock-delta)
    if definition.swimmer:
        _swim_ai(delta)
        return
    if leaping or leap_windup>=0:
        _leap_step(delta)
        return
    noise_clock=maxf(0,noise_clock-delta)
    attack_clock=maxf(0,attack_clock-delta)
    wander_clock-=delta
    flee_until=maxf(0,flee_until-delta)
    scare_clock=maxf(0,scare_clock-delta)
    alert_clock=maxf(0,alert_clock-delta)
    var nearest: Hunter
    var distance: float=INF
    for p in NetworkSession.players.values():
        if not _eligible(p): continue
        var d: float=global_position.distance_to(p.global_position)
        if d<distance: nearest=p;distance=d
    var next_state := "Idle"
    var speed: float=definition.walk_speed
    var prey=_pursuit_target(nearest,distance) if definition.aggressive and scare_clock<=0.0 else null
    if prey:
        behavior="Pursue"
        look_target=prey.global_position+Vector3.UP*.8
        var reach: float=global_position.distance_to(prey.global_position)
        var sees: bool=_can_see(prey)
        var destination: Vector3=prey.global_position if sees else last_seen
        if sees:
            last_seen=prey.global_position
            # Cut the hunter off: run to where they are going, not where they were.
            if "velocity" in prey: destination+=Vector3(prey.velocity.x,0,prey.velocity.z)*clampf(reach/maxf(definition.run_speed,1.0),0.0,.9)*.8
        # Wolves in a nearby pack spread out before closing to melee distance.
        if definition.id==&"wolf" and reach>7:
            for ally in NetworkSession.animals.values():
                if ally!=self and not ally.dead and ally.definition.id==&"wolf" and ally.target_peer==target_peer and global_position.distance_squared_to(ally.global_position)<144:
                    destination+=Vector3((prey.global_position-global_position).z,0,-(prey.global_position-global_position).x).normalized()*avoid_side*3
                    behavior="Flank";break
        heading=(destination-global_position).slide(Vector3.UP).normalized()
        speed=definition.run_speed*(1.2 if health*2<definition.max_health else 1.0)
        next_state="Run"
        # Jinking charge: harder to line up a shot on something that weaves.
        if definition.leap_range>0 and behavior!="Flank" and reach>definition.leap_range*.8:
            heading=heading.rotated(Vector3.UP,sin(motion_clock*4.5+animal_id)*.3)
        if definition.leap_range>0 and sees and leap_clock<=0 and is_on_floor() and attack_windup<0 and reach>_melee_range()+1.0 and reach<=definition.leap_range and prey.global_position.y-global_position.y<4.0:
            leap_windup=rng.randf_range(.45,.6) if definition.boss else rng.randf_range(.22,.4)
            attack_victim=prey.peer_id
            return
        if reach<_melee_range():
            heading=Vector3.ZERO
            velocity.x=0;velocity.z=0
            next_state="Attack"
            behavior="Attack"
            if attack_clock<=0 and attack_windup<0:
                attack_clock=1.5;attack_windup=.6 if definition.boss else .55 if definition.id==&"bear" else .38
                attack_victim=prey.peer_id
                attack_sequence+=1
                if animation and clips.has("Attack"): _animate("Attack",true)
    elif (not definition.aggressive or scare_clock>0.0) and nearest and (flee_until>0 or distance<9):
        behavior="Flee";look_target=nearest.global_position+Vector3.UP
        heading=(global_position-nearest.global_position).normalized()
        speed=definition.run_speed
        next_state="Run"
    elif noise_clock>0:
        look_target=noise_position+Vector3.UP
        heading=(noise_position-global_position).slide(Vector3.UP).normalized()
        if global_position.distance_to(noise_position)>3:
            behavior="Investigate";next_state="Walk"
            # A predator hears a shot as dinner bell: it trots over, not strolls.
            if definition.aggressive: next_state="Run";speed=definition.run_speed*.6
        else: behavior="Alert";heading=Vector3.ZERO
    else:
        if wander_clock<=0:
            wander_clock=rng.randf_range(2,5)
            heading=Vector3(sin(rng.randf()*TAU),0,cos(rng.randf()*TAU)) if rng.randf()<.7 else Vector3.ZERO
            # Bosses keep a long leash and now and then wander off to a new haunt.
            if definition.boss and rng.randf()<.08: _roam()
            if global_position.distance_to(home)>(70.0 if definition.boss else 22.0): heading=(home-global_position).normalized()
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
    global_position.x=clampf(global_position.x,-ForestMap.LIMIT,ForestMap.LIMIT)
    global_position.z=clampf(global_position.z,-ForestMap.LIMIT,ForestMap.LIMIT)
    _animate(next_state)

## Host: a sea creature. It patrols its territory at its preferred depth, senses a
## swimmer from afar (and a shot or blood from further still), and hunts in 3D:
## it leads its target, circles at lunging range, strikes in a burst (sharks may
## break the surface), then breaks off for a moment before coming round again.
func _swim_ai(delta: float) -> void:
    noise_clock=maxf(0,noise_clock-delta)
    attack_clock=maxf(0,attack_clock-delta)
    alert_clock=maxf(0,alert_clock-delta)
    retreat_clock=maxf(0,retreat_clock-delta)
    flee_until=maxf(0,flee_until-delta)
    ink_clock=maxf(0,ink_clock-delta)
    ink_time=maxf(0,ink_time-delta)
    scare_clock=maxf(0,scare_clock-delta)
    wander_clock-=delta
    var map=NetworkSession.forest
    var nearest: Hunter
    var distance: float=INF
    for p in NetworkSession.players.values():
        if not _eligible(p): continue
        var d: float=global_position.distance_to(p.global_position)
        if d<distance: nearest=p;distance=d
    var prey=_pursuit_target(nearest,distance) if definition.aggressive and scare_clock<=0.0 else null
    var wish:=Vector3.ZERO
    var speed: float=definition.walk_speed
    var next_state:="Walk"
    var frenzy: float=1.2 if health*2<definition.max_health else 1.0
    # The colossal squid bolts, backwards in a cloud of ink, when it is badly hurt.
    if definition.id==&"colossal_squid" and prey and ink_clock<=0.0 and health*100<definition.max_health*55 and lunge_time<=0.0 and leap_windup<0.0:
        ink_clock=24.0;ink_time=1.8;retreat_clock=2.4
        lunge_dir=(global_position-prey.global_position).normalized();lunge_dir.y=clampf(lunge_dir.y,-.3,.3)
        lunge_time=.75;lunge_hit=true;attack_victim=0;attack_sequence+=1
        behavior="Ink";_animate("Leap",true)
        return
    if lunge_time>0.0:
        _lunge_step(delta,prey)
        return
    if leap_windup>=0.0:
        # Coiling for the strike: stop, aim, then burst.
        leap_windup-=delta
        var victim=NetworkSession.players.get(attack_victim)
        velocity=velocity.move_toward(Vector3.ZERO,30.0*delta)
        behavior="Pounce"
        if _eligible(victim):
            look_target=victim.global_position
            var aim: Vector3=victim.global_position-global_position
            if aim.slide(Vector3.UP).length_squared()>.01: rotation.y=lerp_angle(rotation.y,atan2(-aim.x,-aim.z),1-exp(-12*delta))
        move_and_slide()
        _animate("Idle")
        if leap_windup<0.0:
            leap_windup=-1.0
            if _eligible(victim): _start_lunge(victim)
            else: leap_clock=.6
        return
    if prey:
        behavior="Pursue"
        var reach: float=global_position.distance_to(prey.global_position)
        var sees: bool=_can_see(prey)
        if sees: last_seen=prey.global_position
        var target: Vector3=(prey.global_position if sees else last_seen)+Vector3.UP*.5
        if sees and "velocity" in prey: target+=prey.velocity*clampf(reach/maxf(definition.run_speed,1.0),0.0,.7)*.7
        var to: Vector3=target-global_position
        wish=to.normalized()
        speed=definition.run_speed*frenzy
        next_state="Run"
        if retreat_clock>0.0:
            # After a bite the animal swings away and loops back instead of grinding on.
            behavior="Retreat"
            wish=(-wish+wish.cross(Vector3.UP).normalized()*circle_side*.8).normalized()
            speed*=.75
        elif definition.shock_radius>0.0:
            if reach<=definition.shock_radius*.9 and attack_clock<=0.0 and attack_windup<0.0:
                attack_clock=2.2;attack_windup=.45;attack_victim=prey.peer_id;attack_sequence+=1
                if animation and clips.has("Attack"): _animate("Attack",true)
            if reach<definition.shock_radius*1.1:
                wish*=.2;next_state="Attack";behavior="Attack"
        else:
            if definition.leap_range>0.0 and leap_clock<=0.0 and sees and reach>_melee_range()+.8 and reach<=definition.leap_range and attack_windup<0.0:
                leap_windup=rng.randf_range(.18,.32) if not definition.boss else rng.randf_range(.35,.5)
                attack_victim=prey.peer_id
                return
            # Circle the prey while the strike recharges, closing in a spiral.
            if definition.leap_range>0.0 and leap_clock>0.0 and reach<definition.leap_range*1.6 and reach>_melee_range()+1.0:
                var side: Vector3=wish.cross(Vector3.UP).normalized()*circle_side
                wish=(wish*.5+side*.85).normalized()
                behavior="Circle"
            if reach<_melee_range():
                if attack_clock<=0.0 and attack_windup<0.0:
                    attack_clock=1.3;attack_windup=.3;attack_victim=prey.peer_id;attack_sequence+=1
                    if definition.id==&"colossal_squid": attack_clock=5.0;attack_windup=.7;attack_combo=2
                    if animation and clips.has("Attack"): _animate("Attack",true)
                next_state="Attack";behavior="Attack"
                wish*=.15
        if definition.id==&"jellyfish": speed*=.5+.5*maxf(0.0,sin(motion_clock*3.0))+.15
    elif (not definition.aggressive or scare_clock>0.0) and nearest and (flee_until>0.0 or distance<definition.aggro_range):
        # Peaceful sea life swims away from divers, and from a shot.
        behavior="Flee";look_target=nearest.global_position
        wish=(global_position-nearest.global_position).normalized()
        wish.y*=.5
        speed=definition.run_speed;next_state="Run"
    elif noise_clock>0.0 and definition.aggressive:
        behavior="Investigate"
        look_target=noise_position
        var toward: Vector3=noise_position-global_position
        if toward.length()>6.0: wish=toward.normalized();speed=definition.run_speed*.55;next_state="Run"
        else: behavior="Alert";next_state="Idle"
    else:
        # Patrol: drift about the territory at the preferred depth, now and then pausing.
        if wander_clock<=0.0:
            wander_clock=rng.randf_range(3.0,7.0)
            var angle: float=rng.randf()*TAU
            swim_heading=Vector3(sin(angle),rng.randf_range(-.25,.25),cos(angle)) if rng.randf()<(.35 if definition.id==&"moray" else .75) else Vector3.ZERO
            if global_position.distance_to(home)>definition.territory: swim_heading=(home-global_position).normalized()
        var want_y: float=-definition.swim_depth+sin(motion_clock*.15+animal_id)*1.5
        wish=swim_heading
        if wish.length_squared()>.01: wish.y=clampf(wish.y+(want_y-global_position.y)*.08,-.5,.5)
        behavior="Patrol" if wish.length_squared()>.01 else "Rest"
        next_state="Walk" if wish.length_squared()>.01 else "Idle"
        look_target=global_position+wish*10.0
    wish=_swim_avoid(wish,map)
    _finish_attack(delta)
    if ink_time>0.0: behavior="Ink"
    velocity=velocity.move_toward(wish*speed,18.0*delta)
    # Stay under the surface (except in a breach), and off the floor.
    if global_position.y>-.9 and velocity.y>0.0: velocity.y=minf(velocity.y,0.0)
    if global_position.y>-.1: velocity.y-=18.0*delta
    move_and_slide()
    var flat:=Vector2(velocity.x,velocity.z)
    if flat.length_squared()>.04: rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),1-exp(-6*delta))
    body_pitch=lerpf(body_pitch,clampf(atan2(velocity.y,maxf(.5,flat.length())),-.9,.9),1-exp(-5*delta))
    global_position.x=clampf(global_position.x,-ForestMap.LIMIT,ForestMap.LIMIT)
    global_position.z=clampf(global_position.z,-ForestMap.LIMIT,ForestMap.LIMIT)
    _animate(next_state)

## Steers a swimming direction around the seabed, rocks and shallows.
func _swim_avoid(direction: Vector3,map) -> Vector3:
    if direction.length_squared()<.01: return direction
    var dir: Vector3=direction.normalized()
    var out: Vector3=direction
    var reach: float=maxf(4.0,definition.length*.9)
    var space:=get_world_3d().direct_space_state
    var query:=PhysicsRayQueryParameters3D.create(global_position,global_position+dir*reach,1|16,[get_rid()])
    if not space.intersect_ray(query).is_empty():
        for candidate in [dir.rotated(Vector3.UP,.8*avoid_side)+Vector3.UP*.25,dir.rotated(Vector3.UP,-.8*avoid_side)+Vector3.UP*.25,dir+Vector3.UP*1.0,dir.rotated(Vector3.UP,1.6*avoid_side)]:
            query.to=global_position+candidate.normalized()*reach
            if space.intersect_ray(query).is_empty():
                out=candidate.normalized()*direction.length();break
    if is_instance_valid(map):
        var floor_y: float=map.height_at(global_position.x,global_position.z)
        if global_position.y<floor_y+1.0: out.y=maxf(out.y,.7)
        # Open water only: turn away from the shallows and the beach.
        var probe: Vector3=global_position+out.slide(Vector3.UP).normalized()*(reach+3.0)
        if map.water_depth(probe)<1.8:
            var back: Vector3=(home-global_position).slide(Vector3.UP).normalized()
            out=(back+out.slide(Vector3.UP).normalized().cross(Vector3.UP)*circle_side*.5).normalized()*maxf(.4,direction.length())
    return out

## Host: the strike. A burst of speed that homes in a little, hurts whoever it
## reaches, and may carry the animal out of the water for a moment.
func _start_lunge(victim) -> void:
    lunge_dir=((victim.global_position+Vector3.UP*.4)-global_position).normalized()
    lunge_time=.55 if not definition.boss else .8
    lunge_hit=false
    attack_victim=victim.peer_id
    attack_sequence+=1
    behavior="Leap"
    leap_clock=definition.leap_cooldown*rng.randf_range(.8,1.2)
    _animate("Leap",true)

func _lunge_step(delta: float,prey) -> void:
    lunge_time-=delta
    var victim=NetworkSession.players.get(attack_victim)
    if _eligible(victim):
        var aim: Vector3=((victim.global_position+Vector3.UP*.4)-global_position).normalized()
        lunge_dir=lunge_dir.slerp(aim,clampf(delta*2.2,0.0,1.0)).normalized()
    var burst: float=definition.run_speed*2.3
    velocity=lunge_dir*burst
    if global_position.y>-.1: velocity.y=minf(lunge_dir.y*burst,velocity.y)-18.0*delta*(.55-lunge_time)
    move_and_slide()
    var flat:=Vector2(velocity.x,velocity.z)
    if flat.length_squared()>.04: rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),1-exp(-12*delta))
    body_pitch=lerpf(body_pitch,clampf(atan2(velocity.y,maxf(.5,flat.length())),-.9,.9),1-exp(-8*delta))
    if not lunge_hit and _eligible(victim) and global_position.distance_to(victim.global_position)<_melee_range()+.7:
        lunge_hit=true
        victim.take_damage(definition.attack_damage)
        if definition.boss:
            for hunter in NetworkSession.players.values():
                if hunter!=victim and _eligible(hunter) and global_position.distance_to(hunter.global_position)<_melee_range()+1.5: hunter.take_damage(definition.attack_damage)
        lunge_time=minf(lunge_time,.12)
        retreat_clock=1.1
    if lunge_time<=0.0:
        velocity*=.3
        if not lunge_hit: retreat_clock=.5
    _animate("Leap")

func _melee_range() -> float:
    if definition.bite_reach>0.0: return definition.bite_reach
    if definition.swimmer: return maxf(1.3,definition.length*.42+.7)
    return maxf(definition.height*.65+1.2,definition.length*.45+.8)

func _eligible(hunter) -> bool:
    if not (is_instance_valid(hunter) and hunter.world_ready and hunter.health>0 and hunter.seat_index<0): return false
    if definition.swimmer:
        # Standing on the truck, a pier or the beach is safe; only swimmers and waders are prey.
        var map=NetworkSession.forest
        return is_instance_valid(map) and not hunter.riding and map.water_submersion(hunter.global_position)>.35
    return true

func _pursuit_target(nearest, distance: float):
    var prey=NetworkSession.players.get(target_peer)
    if not _eligible(prey) or global_position.distance_to(prey.global_position)>definition.pursuit_range:
        target_peer=0;prey=null
    if prey and _senses(prey,global_position.distance_to(prey.global_position)):
        alert_clock=definition.aggro_memory;last_seen=prey.global_position
    if alert_clock<=0: target_peer=0;prey=null
    if not prey and nearest and _senses(nearest,distance):
        target_peer=nearest.peer_id;alert_clock=definition.aggro_memory;prey=nearest;last_seen=nearest.global_position
        _call_pack(nearest)
    return prey

## Sight at full range, plus smell and hearing at close range: hiding behind a
## tree does not hide you from a predator that is already on top of you.
func _senses(hunter, distance: float) -> bool:
    if distance>definition.aggro_range: return false
    return distance<=definition.aggro_range*.3 or _can_see(hunter)

## One animal spotting a hunter drags every aggressive neighbour into the chase.
func _call_pack(prey) -> void:
    if definition.pack_radius<=0: return
    var limit: float=definition.pack_radius*definition.pack_radius
    for ally in NetworkSession.animals.values():
        if ally==self or ally.dead or not ally.definition.aggressive or ally.definition.aquatic!=definition.aquatic: continue
        if ally.target_peer!=0 or global_position.distance_squared_to(ally.global_position)>limit: continue
        ally.target_peer=prey.peer_id;ally.alert_clock=ally.definition.aggro_memory;ally.last_seen=prey.global_position

## Host: crouch, then launch in an arc at where the prey is heading. Whatever is
## still near the landing spot takes the hit, so a dodge has to be a real one.
func _leap_step(delta: float) -> void:
    if leap_windup>=0:
        var prey=NetworkSession.players.get(attack_victim)
        velocity.x=move_toward(velocity.x,0,delta*40);velocity.z=move_toward(velocity.z,0,delta*40)
        velocity.y=0 if is_on_floor() else velocity.y-18*delta
        move_and_slide()
        behavior="Pounce";_animate("Idle")
        # Prey downed or boarding the jeep mid-crouch: drop the pounce, pick a new target.
        if not _eligible(prey): leap_windup=-1;leap_clock=.5;return
        if _eligible(prey):
            var aim: Vector3=(prey.global_position-global_position).slide(Vector3.UP)
            look_target=prey.global_position+Vector3.UP*.8
            if aim.length_squared()>.01: rotation.y=lerp_angle(rotation.y,atan2(-aim.x,-aim.z),1-exp(-14*delta))
        leap_windup-=delta
        if leap_windup<0:
            if not _eligible(prey) or not _launch_leap(prey): leap_clock=.5
        return
    leap_time+=delta
    velocity.y-=18*delta
    move_and_slide()
    var flat:=Vector3(velocity.x,0,velocity.z)
    if flat.length_squared()>1: rotation.y=lerp_angle(rotation.y,atan2(-flat.x,-flat.z),1-exp(-10*delta))
    global_position.x=clampf(global_position.x,-ForestMap.LIMIT,ForestMap.LIMIT)
    global_position.z=clampf(global_position.z,-ForestMap.LIMIT,ForestMap.LIMIT)
    if (leap_time>.15 and is_on_floor()) or leap_time>2.2: _land_leap()

func _launch_leap(prey) -> bool:
    var to: Vector3=prey.global_position-global_position
    var flat:=Vector3(to.x,0,to.z)
    if flat.length()<.5: return false
    var t: float=clampf(flat.length()/definition.leap_speed,.3,.85)+definition.leap_hop*.1
    if "velocity" in prey: flat+=Vector3(prey.velocity.x,0,prey.velocity.z)*t*.6
    velocity.x=flat.x/t;velocity.z=flat.z/t
    velocity.y=9.0*t+clampf(to.y,-3.0,4.0)/t
    leaping=true;leap_time=0
    leap_clock=definition.leap_cooldown*rng.randf_range(.8,1.2)
    attack_sequence+=1
    body_pitch=.45;behavior="Leap"
    _animate("Leap",true)
    return true

func _land_leap() -> void:
    leaping=false;leap_time=0
    velocity.x*=.15;velocity.z*=.15
    attack_clock=maxf(attack_clock,.5)
    body_pitch=0;behavior="Pursue"
    var reach: float=_melee_range()+(2.4 if definition.boss else 1.4)
    for hunter in NetworkSession.players.values():
        if _eligible(hunter) and global_position.distance_to(hunter.global_position)<reach: hunter.take_damage(definition.attack_damage)
    _animate("Run")

func _avoid_obstacle(direction: Vector3) -> Vector3:
    var origin:=global_position+Vector3.UP*maxf(.65,definition.height*.5)
    var space:=get_world_3d().direct_space_state
    var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*maxf(2.4,definition.length*.6),1|16,[get_rid()])
    if space.intersect_ray(query).is_empty(): return direction
    for angle in [.75*avoid_side,-.75*avoid_side,1.3*avoid_side,-1.3*avoid_side]:
        var candidate:=direction.rotated(Vector3.UP,float(angle))
        query.to=origin+candidate*maxf(2.4,definition.length*.6)
        if space.intersect_ray(query).is_empty():
            avoid_side=1.0 if angle>0 else -1.0
            return candidate
    return direction

func _animate(next: String, restart: bool=false) -> void:
    var previous: String=state
    state=next
    if not animation: return
    var presentation: String=next
    if next=="Leap": presentation="Attack" if clips.has("Attack") else "Run"
    elif next=="Idle" and behavior=="Graze" and clips.has("Graze"): presentation="Graze"
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
        if _eligible(attacker):
            target_peer=attacker.peer_id;alert_clock=definition.aggro_memory;last_seen=attacker.global_position
            _call_pack(attacker)
    else: flee_until=8
    if health==0:
        dead=true
        leaping=false;leap_windup=-1;body_pitch=0;lunge_time=0;attack_combo=0
        collision_layer=0
        velocity=Vector3.ZERO
        _animate("Die")
        NetworkSession.animal_died()
        if definition.boss: NetworkSession.boss_defeated(self)
    return true

## Host: a boss picks a new haunt 150-320 m away, on dry ground or in water to suit it.
func _roam() -> void:
    var map=NetworkSession.forest
    if not is_instance_valid(map): return
    for attempt in 8:
        var angle: float=rng.randf()*TAU
        var point: Vector3=home+Vector3(sin(angle),0,cos(angle))*rng.randf_range(150,320)
        point.x=clampf(point.x,-ForestMap.LIMIT+40,ForestMap.LIMIT-40);point.z=clampf(point.z,-ForestMap.LIMIT+40,ForestMap.LIMIT-40)
        var wet: bool=map.water_depth(point)>.3
        if definition.aquatic!=wet: continue
        if not definition.aquatic and map.slope_at(point.x,point.z)>definition.max_slope: continue
        home=point
        return

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
    var attack_changed: bool=sequence!=attack_sequence and str(data.state) in ["Attack","Leap"]
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
    if definition.shock_radius>0.0:
        # An electric eel discharges into everyone in the water around it.
        for hunter in NetworkSession.players.values():
            if _eligible(hunter) and global_position.distance_to(hunter.global_position)<definition.shock_radius: hunter.take_damage(definition.attack_damage)
        return
    if definition.boss:
        # A boss's swipe or death roll hits everyone in reach, not just its target.
        for hunter in NetworkSession.players.values():
            if _eligible(hunter) and global_position.distance_to(hunter.global_position)<_melee_range()+.8 and _can_see(hunter):
                hunter.take_damage(definition.attack_damage)
        # The squid follows with two more lashes of the tentacles.
        if attack_combo>0:
            attack_combo-=1;attack_windup=.5;attack_sequence+=1
        return
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
        if ground_clock<=0 and not leaping and not definition.swimmer:
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
