class_name LootPickup
extends LobbyInteractable

const Toon:=preload("res://world/camp/toon_builder.gd")
@export var loot_definition: LootDefinition
var network_id: int = 0
var collected: bool = false
var trophy: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
    interaction_kind = "loot"
    interaction_range = 2.3
    super._ready()
    add_to_group("loot_pickups")
    if loot_definition and loot_definition.id in AnimalCatalog.TROPHY_IDS: _dress_trophy()

func _process(delta: float) -> void:
    _bob_time += delta
    $Pelt.position.y = 0.3 + sin(_bob_time * 2.0) * 0.045
    if trophy: $Pelt.rotation.y += delta * 1.4

## A boss trophy: its own little model, a gold glow and a beam of light that
## shows where it fell from far away.
func _dress_trophy() -> void:
    trophy = true
    var holder: MeshInstance3D = $Pelt
    holder.mesh = null
    holder.rotation = Vector3.ZERO
    var t = Toon.new()
    match String(loot_definition.id):
        "ancient_bear_claw":
            for k in 3:
                var x: float = (k - 1) * .09
                t.rod(Vector3(x, 0, .08), Vector3(x, .14, -.04), .035, Color("eadfc6"), 5, .025)
                t.rod(Vector3(x, .14, -.04), Vector3(x, .12, -.2), .025, Color("eadfc6"), 5, .004)
            t.box(Vector3(-.16, -.03, .02), Vector3(.16, .04, .14), Color("4a3a2c"))
        "ancient_bear_fang":
            t.rod(Vector3(0, -.05, 0), Vector3(0, .32, .06), .06, Color("f3ead6"), 6, .005)
            t.cylinder(Vector3(0, -.06, 0), .07, .07, .05, Color("8a5a33"), Vector3.ZERO, 8)
        "ancient_amber":
            t.sphere(Vector3(0, .1, 0), .13, Color("f28a1c"), Vector3(1, 1.25, .9), .55, 8)
            t.sphere(Vector3(0, .1, -.02), .035, Color("2a1405"), Vector3(1.3, .8, 1))
        "albino_croc_tooth":
            t.rod(Vector3(0, -.04, 0), Vector3(.02, .26, 0), .055, Color("f6e4dc"), 6, .004)
            t.sphere(Vector3(0, -.04, 0), .06, Color("e8b9b0"), Vector3(1, .5, 1))
        "croc_gastrolith":
            t.sphere(Vector3(-.06, .04, 0), .085, Color("8aa2b2"), Vector3(1.2, .8, 1), 0.0, 8)
            t.sphere(Vector3(.07, .03, .04), .065, Color("b7c3c9"), Vector3(1, .75, 1.2), 0.0, 8)
        "ancient_harpoon":
            t.rod(Vector3(-.5, .05, 0), Vector3(.45, .05, 0), .022, Color("7a5232"), 6)
            t.rod(Vector3(.45, .05, 0), Vector3(.62, .05, 0), .035, Color("8a4b2a"), 6, .002)
            for side in [-1.0, 1.0]: t.rod(Vector3(.5, .05, 0), Vector3(.44, .05, side * .07), .012, Color("8a4b2a"), 4)
            t.rod(Vector3(-.5, .05, 0), Vector3(-.62, -.02, .12), .014, Color("c9b48a"), 4)
    t.commit(holder, "Trophy")
    var glow: OmniLight3D = $Glow
    glow.light_color = Color("ffcf5a"); glow.light_energy = .45; glow.omni_range = 2.6; glow.position.y = 1.0
    var beam := MeshInstance3D.new(); beam.name = "Beam"
    var shape := CylinderMesh.new(); shape.top_radius = .02; shape.bottom_radius = .07; shape.height = 7.0; shape.radial_segments = 8; shape.rings = 1
    var light := StandardMaterial3D.new(); light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    light.albedo_color = Color(1.0, .78, .3, .12); light.cull_mode = BaseMaterial3D.CULL_DISABLED
    shape.material = light; beam.mesh = shape; beam.position.y = 3.6
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; beam.set_meta("styled", true)
    add_child(beam)

func collect_into(inventory: HunterInventory) -> bool:
    if collected or not inventory.collect(loot_definition):
        return false
    collected = true
    remove_from_group("lobby_interactables")
    remove_from_group("loot_pickups")
    hide()
    queue_free()
    return true

func localized_name() -> String:
    return loot_definition.localized_name() if loot_definition else tr("loot")
