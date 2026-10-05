extends Node3D
signal build_progress(value: float)
var retained_assets: Array[Resource]=[]
@onready var forest: ForestMap=$Forest

func _ready() -> void:
    var sky_material:=ProceduralSkyMaterial.new()
    sky_material.sky_top_color=Color("609bc3")
    sky_material.sky_horizon_color=Color("d6e4df")
    sky_material.ground_horizon_color=Color("aebbaf")
    sky_material.ground_bottom_color=Color("3b4841")
    var sky:=Sky.new();sky.sky_material=sky_material
    var environment:=WorldEnvironment.new()
    environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_SKY
    environment.environment.sky=sky
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color("b8ccd9")
    environment.environment.ambient_light_energy=.62
    environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    environment.environment.fog_enabled=true
    environment.environment.fog_light_color=Color("bbcfd0")
    environment.environment.fog_density=.0016
    GameArt.cinematic(environment.environment)
    add_child(environment)
    var sunlight:=DirectionalLight3D.new()
    sunlight.rotation_degrees=Vector3(-38,-28,0)
    sunlight.light_color=Color("ffe4bd")
    sunlight.light_energy=1.15
    sunlight.shadow_enabled=true
    sunlight.directional_shadow_max_distance=130
    add_child(sunlight)
    var sign:=Label3D.new()
    sign.text=tr("RALLY_POINT");sign.position=Vector3(6,2,5)
    sign.font_size=40;sign.pixel_size=.008
    sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    sign.visibility_range_end=40
    add_child(sign)
    LocaleSettings.changed.connect(func() -> void: sign.text=tr("RALLY_POINT");GameArt.cinematic(environment.environment))

func build() -> void:
    forest.build_progress.connect(func(value: float) -> void: build_progress.emit(value*.85))
    await forest.build()
    if forest.cancelled or not is_inside_tree(): return
    for index in AnimalCatalog.ANIMALS.size():
        retained_assets.append(load(AnimalCatalog.ANIMALS[index].model_path))
        build_progress.emit(.85+.14*(index+1)/float(AnimalCatalog.ANIMALS.size()))
        await get_tree().process_frame
        if forest.cancelled or not is_inside_tree(): return
    await get_tree().physics_frame
    build_progress.emit(1.0)
