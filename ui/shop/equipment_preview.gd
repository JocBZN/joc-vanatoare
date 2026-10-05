class_name EquipmentPreview
extends Control
## A separate lit 3D studio. Dragging never sends gameplay input.
var viewport: SubViewport
var pivot: Node3D
var model: Node3D
var dragging: bool=false
var manipulated: bool=false
var camera: Camera3D

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape=Control.CURSOR_DRAG
    viewport=SubViewport.new()
    viewport.size=Vector2i(800,600)
    viewport.own_world_3d=true
    viewport.transparent_bg=true
    viewport.msaa_3d=Viewport.MSAA_4X
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    add_child(viewport)
    var screen:=TextureRect.new()
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.texture=viewport.get_texture()
    screen.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    screen.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(screen)
    var environment:=WorldEnvironment.new()
    environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color(0,0,0,0)
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color("bed7d3")
    environment.environment.ambient_light_energy=.85
    viewport.add_child(environment)
    for data in [[Vector3(-35,-35,0),Color("ffe3b2"),1.8],[Vector3(-15,135,0),Color("80ddd1"),1.4]]:
        var light:=DirectionalLight3D.new()
        light.rotation_degrees=data[0]
        light.light_color=data[1]
        light.light_energy=data[2]
        viewport.add_child(light)
    pivot=Node3D.new()
    viewport.add_child(pivot)
    camera=Camera3D.new()
    camera.position=Vector3(0,.25,3.3)
    viewport.add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.fov=42
    camera.current=true
    visibility_changed.connect(func() -> void:
        dragging=false
        viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)

func show_model(path: String) -> void:
    if is_instance_valid(model):
        pivot.remove_child(model)
        model.queue_free()
    model=load(path).instantiate()
    pivot.add_child(model)
    GameArt.dress_scene(model,"backpack" if "backpack" in path else "weapon")
    var bounds:=AABB()
    var first:=true
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        var box: AABB=pivot.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        bounds=box if first else bounds.merge(box)
        first=false
    model.position-=bounds.get_center()
    var scale_factor:=2.4/maxf(.01,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
    model.position*=scale_factor
    model.scale*=scale_factor
    pivot.rotation=Vector3(-.15,-1.05,0)
    camera.fov=42
    manipulated=false
    dragging=false

func _process(delta: float) -> void:
    if is_visible_in_tree() and not manipulated: pivot.rotation.y+=delta*.17

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT:
            dragging=event.pressed
            manipulated=true
            accept_event()
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            camera.fov=clampf(camera.fov+(-2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2),28,55)
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        pivot.rotation.y+=event.relative.x*.009
        pivot.rotation.x=clampf(pivot.rotation.x+event.relative.y*.006,-1.1,1.1)
        accept_event()
