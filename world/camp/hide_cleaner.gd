extends LobbyInteractable
## The camp hide cleaner: a wooden frame holding a big tumbling drum, a feed
## chute and a lantern. Built procedurally in the camp's toon style; it faces
## the campfire on its own. The drum spins faster while someone is using it.

const FIRE:=Vector3(0,0,-1.8)

var _drum: Node3D
var _spin: float=.6

func _ready() -> void:
    interaction_kind="cleaner"
    interaction_range=3.0
    var target:=Vector3(FIRE.x,global_position.y,FIRE.z)
    if global_position.distance_to(target)>.5: look_at(target,Vector3.UP)
    var wood:=_material(Color("7a5434"),.9)
    var dark_wood:=_material(Color("4f3622"),.92)
    var steel:=_material(Color("7f8b88"),.45,.6)
    var copper:=_material(Color("b0703c"),.5,.4)
    var body:=StaticBody3D.new();body.name="Body";add_child(body)
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.6,1.9,1.6)
    shape.shape=box;shape.position=Vector3(0,.95,0);body.add_child(shape)
    # Frame: four posts, two rails and a plank floor.
    for x in [-1.2,1.2]:
        for z in [-.65,.65]: _box(Vector3(.16,1.9,.16),Vector3(x,.95,z),wood)
        _box(Vector3(.14,.14,1.46),Vector3(x,1.75,0),dark_wood)
    _box(Vector3(2.6,.12,1.5),Vector3(0,.06,0),dark_wood)
    # The drum on its axle: wooden staves with copper hoops.
    _drum=Node3D.new();_drum.name="Drum";_drum.position=Vector3(0,1.05,0);add_child(_drum)
    var barrel:=MeshInstance3D.new();var cylinder:=CylinderMesh.new()
    cylinder.top_radius=.62;cylinder.bottom_radius=.62;cylinder.height=2.1;cylinder.radial_segments=14
    barrel.mesh=cylinder;barrel.rotation.z=PI*.5;barrel.material_override=wood;_drum.add_child(barrel)
    for x in [-.8,0.0,.8]:
        var hoop:=MeshInstance3D.new();var torus:=TorusMesh.new()
        torus.inner_radius=.6;torus.outer_radius=.68;torus.rings=16;torus.ring_segments=6
        hoop.mesh=torus;hoop.rotation.z=PI*.5;hoop.position.x=x;hoop.material_override=copper;_drum.add_child(hoop)
    for k in 4:
        # Staves that make the rotation readable from across the camp.
        var stave:=MeshInstance3D.new();var plank:=BoxMesh.new();plank.size=Vector3(2.12,.08,.16)
        stave.mesh=plank;stave.material_override=dark_wood
        var angle: float=float(k)*PI*.5
        stave.position=Vector3(0,cos(angle)*.6,sin(angle)*.6);stave.rotation.x=angle
        _drum.add_child(stave)
    var axle:=MeshInstance3D.new();var rod:=CylinderMesh.new();rod.top_radius=.06;rod.bottom_radius=.06;rod.height=2.7
    axle.mesh=rod;axle.rotation.z=PI*.5;axle.position=Vector3(0,1.05,0);axle.material_override=steel;add_child(axle)
    # Crank wheel and feed chute on the side facing the player.
    var wheel:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=.32;disc.bottom_radius=.32;disc.height=.08
    wheel.mesh=disc;wheel.rotation.z=PI*.5;wheel.position=Vector3(1.38,1.05,0);wheel.material_override=steel;_drum.add_child(wheel)
    var chute:=_box(Vector3(.9,.08,.9),Vector3(-.4,1.55,-.75),steel)
    chute.rotation.x=-.5
    # Sign and lantern.
    var sign:=_box(Vector3(1.7,.42,.06),Vector3(0,2.15,-.7),dark_wood)
    sign.name="Sign"
    var title:=Label3D.new();title.name="Title";title.position=Vector3(0,2.15,-.74);title.rotation.y=PI
    title.font_size=42;title.outline_size=8;title.pixel_size=.0045;title.modulate=Color("f5dfaf");add_child(title)
    var lamp:=OmniLight3D.new();lamp.position=Vector3(1.25,2.0,-.75);lamp.light_color=Color("ffcf8a");lamp.light_energy=1.4;lamp.omni_range=5.0
    add_child(lamp)
    var glow:=MeshInstance3D.new();var bulb:=SphereMesh.new();bulb.radius=.09;bulb.height=.18
    var hot:=_material(Color("ffd890"),.3);hot.emission_enabled=true;hot.emission=Color("ffbe63");hot.emission_energy_multiplier=2.0
    glow.mesh=bulb;glow.material_override=hot;glow.position=lamp.position;add_child(glow)
    var point:=Marker3D.new();point.name="InteractionPoint";point.position=Vector3(0,0,-1.5);add_child(point)
    super._ready()

func localized_name() -> String:
    var hunter=NetworkSession.local_hunter() if NetworkSession.has_method("local_hunter") else null
    var count: int=0
    if is_instance_valid(hunter):
        for item in hunter.inventory.items: count+=1 if item.raw else 0
    return LocaleSettings.text("CLEAN_PROMPT",{"n":count})

func _localize_signs() -> void:
    var title:=get_node_or_null("Title") as Label3D
    if title: title.text=tr("CLEAN_TITLE").to_upper()

func _process(delta: float) -> void:
    var busy: bool=false
    for hunter in NetworkSession.players.values():
        if is_instance_valid(hunter) and hunter.cleaning: busy=true
    _spin=lerpf(_spin,4.5 if busy else .6,clampf(delta*2.0,0,1))
    if is_instance_valid(_drum): _drum.rotation.x+=_spin*delta

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
    var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size
    mesh.mesh=shape;mesh.position=at;mesh.material_override=material;add_child(mesh)
    return mesh

func _material(color: Color, roughness: float, metallic: float=0.0) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=roughness;material.metallic=metallic
    return material
