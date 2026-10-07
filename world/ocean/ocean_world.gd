extends Node3D
## The ocean expedition: a bright tropical sky, a sun, and an atmosphere that
## changes the moment the camera slips under the surface (teal fog that thickens
## and darkens with depth, a dim blue sun, marine snow, a wobbling blue-green
## grade). Everything else lives in OceanMap.
signal build_progress(value: float)
## Tropical water: clear and turquoise near the surface, then ever darker with depth as
## the light is absorbed (about 1/e every 38 m), ending in near-black navy.
const FOG_SHALLOW:=Color("17b3c2")
const FOG_MID:=Color("07587c")
const FOG_DEEP:=Color("02203c")
const FOG_ABYSS:=Color("00060f")
const LIGHT_SCALE: float=38.0
const AIR_FOG:=Color("b4e4f0")
@onready var ocean: OceanMap=$Ocean
var retained_assets: Array[Resource]=[]
var environment: Environment
var sun: DirectionalLight3D
var overlay: ColorRect
var overlay_material: ShaderMaterial
var snow: GPUParticles3D
var rays: Array[MeshInstance3D]=[]
## 0 above the waves, 1 fully submerged; follows the camera smoothly.
var under: float=0.0
var depth_dark: float=0.0
var _sky_material: ProceduralSkyMaterial

func _ready() -> void:
    _sky_material=ProceduralSkyMaterial.new()
    _sky_material.sky_top_color=Color("2f86d6");_sky_material.sky_horizon_color=Color("c4e6f2")
    _sky_material.ground_horizon_color=Color("a3d2de");_sky_material.ground_bottom_color=Color("2b6f8c")
    _sky_material.sun_angle_max=30.0;_sky_material.sun_curve=.12
    var sky:=Sky.new();sky.sky_material=_sky_material
    environment=Environment.new()
    environment.background_mode=Environment.BG_SKY;environment.sky=sky
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;environment.ambient_light_energy=.9
    environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled=true;environment.fog_light_color=AIR_FOG;environment.fog_density=.0009
    environment.fog_sky_affect=.4
    GameArt.cinematic(environment)
    var holder:=WorldEnvironment.new();holder.environment=environment;add_child(holder)
    sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.light_color=Color("fff0d2");sun.light_energy=1.35
    sun.shadow_enabled=true;sun.directional_shadow_max_distance=150;add_child(sun)
    _build_overlay()
    _build_snow()
    LocaleSettings.changed.connect(func() -> void: GameArt.cinematic(environment))

func build() -> void:
    ocean.build_progress.connect(func(value: float) -> void: build_progress.emit(value*.9))
    await ocean.build()
    if ocean.cancelled or not is_inside_tree(): return
    for entry: AnimalDefinition in AnimalCatalog.OCEAN_ANIMALS+AnimalCatalog.bosses_for("ocean"):
        retained_assets.append(load(entry.model_path));build_progress.emit(.95)
        await get_tree().process_frame
        if ocean.cancelled or not is_inside_tree(): return
    await get_tree().physics_frame
    build_progress.emit(1.0)

func _build_overlay() -> void:
    var layer:=CanvasLayer.new();layer.layer=0;layer.name="UnderwaterGrade";add_child(layer)
    overlay=ColorRect.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var shader:=Shader.new()
    shader.code="""shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float deep : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
void fragment() {
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 22.0 + TIME * 1.7), cos(uv.x * 17.0 + TIME * 1.3)) * 0.0022 * amount;
	vec3 c = texture(screen_tex, uv).rgb;
	vec3 grade = mix(vec3(0.78, 0.97, 1.0), vec3(0.2, 0.45, 0.8), deep);
	c = mix(c, c * grade, amount * (0.45 + deep * 0.4));
	float edge = smoothstep(1.15, 0.3, length(SCREEN_UV - 0.5) * 1.55);
	c *= mix(1.0, edge, amount * (0.25 + deep * 0.5));
	COLOR = vec4(c, 1.0);
}
"""
    overlay_material=ShaderMaterial.new();overlay_material.shader=shader;overlay.material=overlay_material
    overlay.visible=false
    layer.add_child(overlay)

func _build_snow() -> void:
    snow=GPUParticles3D.new();snow.name="MarineSnow";snow.amount=420;snow.lifetime=9.0;snow.preprocess=6.0;snow.emitting=false
    snow.visibility_aabb=AABB(Vector3(-30,-20,-30),Vector3(60,40,60));snow.local_coords=false
    var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(26,16,26)
    process.gravity=Vector3(0,-.05,0);process.initial_velocity_min=.05;process.initial_velocity_max=.25;process.direction=Vector3(.3,.1,0);process.spread=180
    process.scale_min=.02;process.scale_max=.06;snow.process_material=process
    var mesh:=SphereMesh.new();mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=5;mesh.rings=3
    var glow:=StandardMaterial3D.new();glow.albedo_color=Color(.85,.95,1.0,.7);glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh.material=glow;snow.draw_pass_1=mesh;add_child(snow)

## Whether a world point is below the surface (for cameras and effects).
func is_submerged(point: Vector3) -> bool:
    return point.y<OceanMap.WATER_LEVEL-.05 and ocean.water_depth(point)>0.0

func _process(delta: float) -> void:
    var camera:=get_viewport().get_camera_3d()
    if camera==null: return
    var sunk: bool=is_submerged(camera.global_position)
    under=move_toward(under,1.0 if sunk else 0.0,delta*(6.0 if sunk else 3.5))
    var meters: float=maxf(0.0,-camera.global_position.y) if sunk else 0.0
    depth_dark=lerpf(depth_dark,1.0-exp(-meters/LIGHT_SCALE),1.0-exp(-3.0*delta))
    var mix_value: float=smoothstep(0.0,1.0,under)
    var light: float=1.0-depth_dark
    var fog_under: Color=FOG_SHALLOW.lerp(FOG_MID,smoothstep(0.0,18.0,meters))
    fog_under=fog_under.lerp(FOG_DEEP,smoothstep(14.0,45.0,meters)).lerp(FOG_ABYSS,smoothstep(45.0,110.0,meters))
    environment.fog_light_color=AIR_FOG.lerp(fog_under,mix_value)
    # Clear near the surface (you see far), thicker and darker as you sink.
    environment.fog_density=lerpf(.0009,.0035+meters*.00045,mix_value)
    environment.fog_sky_affect=lerpf(.4,1.0,mix_value)
    environment.background_mode=Environment.BG_COLOR if mix_value>.5 else Environment.BG_SKY
    environment.background_color=fog_under
    environment.ambient_light_energy=lerpf(.9,.08+.95*light,mix_value)
    sun.light_energy=lerpf(1.35,.02+1.3*light,mix_value)
    sun.light_color=Color("fff0d2").lerp(Color("9fe6ff").lerp(Color("4a8fd0"),depth_dark),mix_value)
    overlay.visible=mix_value>.01
    overlay_material.set_shader_parameter("amount",mix_value)
    overlay_material.set_shader_parameter("deep",depth_dark)
    snow.emitting=mix_value>.5
    snow.global_position=camera.global_position
    if ocean.has_meta("lighthouse_beam"):
        var beam: Node=ocean.get_meta("lighthouse_beam")
        if is_instance_valid(beam): beam.rotation.y+=delta*.55
