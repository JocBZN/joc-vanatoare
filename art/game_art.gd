class_name GameArt
extends RefCounted
## Shared stylized assets; static caches prevent one copy per instance.
const ROOT="res://assets/art/"
static var meshes: Dictionary={}
static var materials: Dictionary={}
static var prop_meshes: Dictionary={}
static var retained: Array[Resource]=[]
static func keep(resource: Resource) -> void:
    if resource and not retained.has(resource): retained.append(resource)

static func refine_scene(root: Node3D,id: String) -> void:
    var path: String=ROOT+"props/"+id+".glb"
    if not ResourceLoader.exists(path): return
    if not prop_meshes.has(id):
        var scene: Node3D=load(path).instantiate()
        var parts: Dictionary={}
        for mesh in scene.find_children("*","MeshInstance3D",true,false): parts[str(mesh.name)]=mesh.mesh
        prop_meshes[id]=parts;scene.free()
    for mesh in root.find_children("*","MeshInstance3D",true,false):
        if prop_meshes[id].has(str(mesh.name)): mesh.mesh=prop_meshes[id][str(mesh.name)]

static func texture(asset: String, suffix: String) -> Texture2D:
    return load(ROOT+"materials/"+asset+"/"+asset+"_"+suffix+"_2k.jpg")

static func painted_texture(asset: String) -> Texture2D:
    var key: String="paint_"+asset
    if materials.has(key): return materials[key]
    var color:=Color("718e58")
    if asset=="rocky_trail": color=Color("bb986c")
    elif asset=="rough_wood": color=Color("8d6847")
    elif asset=="bark": color=Color("775840")
    elif asset=="stylized_rock": color=Color("606b72")
    elif asset=="fabric_pattern_07": color=Color("e6e3d7")
    elif asset=="rust_coarse_01": color=Color("d1d8dc")
    var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
    for y in 128:
        for x in 128:
            var wave: float=sin(x*TAU/128.0*2.0+sin(y*TAU/128.0*3.0)*.6)+cos(y*TAU/128.0*2.0)*.4
            if asset in ["rough_wood","bark"]:
                wave=sin(y*TAU/128.0*4.0+sin(x*TAU/128.0*2.0)*.55)
            elif asset=="fabric_pattern_07":
                wave=sin(x*TAU/128.0*8.0)*cos(y*TAU/128.0*8.0)*.2
            var tone: Color=color.lightened(.075) if wave>.55 else color.darkened(.075) if wave<-.65 else color
            image.set_pixel(x,y,tone)
    image.generate_mipmaps()
    var result:=ImageTexture.create_from_image(image)
    materials[key]=result
    return result

static func pbr(asset: String, repeats: float=1.0) -> StandardMaterial3D:
    var key:=asset+str(repeats)
    if materials.has(key): return materials[key]
    var material:=StandardMaterial3D.new()
    material.albedo_texture=painted_texture(asset)
    material.roughness=.92;material.metallic_specular=.18
    material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
    material.uv1_scale=Vector3(repeats,repeats,1)
    materials[key]=material
    return material

static func nature_mesh(id: String) -> ArrayMesh:
    if meshes.has(id): return meshes[id]
    if id.begins_with("grass") or id.begins_with("fern"):
        var plant:=painted_undergrowth(id)
        meshes[id]=plant
        return plant
    var scene: Node3D=load(ROOT+"nature/"+id+".glb").instantiate()
    var result: ArrayMesh
    for instance in scene.find_children("*","MeshInstance3D",true,false):
        result=instance.mesh.duplicate() as ArrayMesh
        for surface in instance.mesh.get_surface_count():
            var base: Material=instance.get_active_material(surface)
            var material: Material=base
            if base is StandardMaterial3D and (id.begins_with("grass") or id.begins_with("fern") or "twig" in base.resource_name or (id=="swamp_tree" and base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)):
                material=foliage_material(base,id)
            elif base is StandardMaterial3D and not id.ends_with("_far"):
                var painted: StandardMaterial3D=base.duplicate()
                painted.albedo_texture=painted_texture("stylized_rock" if id.begins_with("rock") else "bark")
                painted.albedo_color=Color.WHITE
                painted.normal_enabled=false;painted.roughness_texture=null;painted.roughness=1.0
                painted.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;painted.metallic_specular=.14
                material=painted
            result.surface_set_material(surface,material)
        break
    scene.free();meshes[id]=result
    return result

static func foliage_material(base: StandardMaterial3D,id: String) -> ShaderMaterial:
    var material:=ShaderMaterial.new();material.shader=load("res://art/foliage.gdshader")
    material.set_shader_parameter("color_map",base.albedo_texture)
    material.set_shader_parameter("normal_map",base.normal_texture)
    material.set_shader_parameter("rough_map",base.roughness_texture)
    material.set_shader_parameter("packed_rough",not id.begins_with("fir"))
    if id.begins_with("grass") or id.begins_with("fern"):
        material.set_shader_parameter("use_mask",true)
        material.set_shader_parameter("mask_map",load(ROOT+"nature/"+("grass_medium_01" if id.begins_with("grass") else "fern_02")+"_alpha_1k.png"))
        material.set_shader_parameter("wind_strength",.11 if id.begins_with("grass") else .06)
    else: material.set_shader_parameter("wind_strength",.035)
    return material

static func painted_undergrowth(id: String) -> ArrayMesh:
    # Keep each imported asset's footprint so placement and existing LOD ranges stay valid.
    var source: Node3D=load(ROOT+"nature/"+id+".glb").instantiate()
    var bounds:=AABB(Vector3(-.05,0,-.05),Vector3(.1,.12,.1))
    for instance in source.find_children("*","MeshInstance3D",true,false):
        bounds=instance.mesh.get_aabb()
        break
    source.free()
    var rng:=RandomNumberGenerator.new();rng.seed=absi(id.hash())
    var fern: bool=id.begins_with("fern")
    var radius: float=maxf(bounds.size.x,bounds.size.z)*.46
    var height: float=bounds.end.y
    var count: int=7 if fern else 9 if "patch" in id else 5
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var palette: Array[Color]=[Color("597e51"),Color("6f914f"),Color("859d58")]
    for blade in count:
        var angle: float=TAU*blade/float(count)+rng.randf_range(-.15,.15)
        var forward:=Vector3(cos(angle),0,sin(angle))
        var side:=Vector3(-sin(angle),0,cos(angle))
        var origin:=forward*radius*rng.randf_range(.05,.22)
        var leaf_height: float=height*rng.randf_range(.72,1.0)
        var lean: float=radius*rng.randf_range(.7,1.0) if fern else radius*rng.randf_range(.32,.75)
        var width: float=radius*.30 if fern else minf(radius*.40,height*.22)
        var middle:=origin+forward*lean*.5+Vector3.UP*leaf_height*.60
        var tip:=origin+forward*lean+Vector3.UP*leaf_height*(.68 if fern else 1.0)
        var ridge:=middle+Vector3.UP*width*.35
        var color: Color=palette[blade%palette.size()].srgb_to_linear()
        _leaf_triangle(surface,origin-side*width*.45,middle-side*width,ridge,color.darkened(.06))
        _leaf_triangle(surface,origin-side*width*.45,ridge,origin+side*width*.45,color)
        _leaf_triangle(surface,origin+side*width*.45,ridge,middle+side*width,color)
        _leaf_triangle(surface,middle-side*width,tip,ridge,color)
        _leaf_triangle(surface,ridge,tip,middle+side*width,color.lightened(.025))
        if fern:
            # Broad paired leaflets make a legible fern silhouette instead of alpha cards.
            for leaflet in 3:
                var fraction: float=.3+leaflet*.17
                var center:=origin.lerp(tip,fraction)+Vector3.UP*leaf_height*.20
                var leaf_width: float=width*(1.2-fraction)
                for sign in [-1,1]:
                    var edge: Vector3=center+side*sign*leaf_width*1.8+forward*lean*.10
                    _leaf_triangle(surface,center-forward*width*.23,edge,center+forward*width*.32,color)
    surface.generate_normals()
    var material:=ShaderMaterial.new();material.shader=load("res://art/foliage.gdshader")
    material.set_shader_parameter("solid_leaf",true)
    material.set_shader_parameter("wind_strength",.14 if fern else .22)
    surface.set_material(material)
    return surface.commit()

static func _leaf_triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
    surface.set_color(color)
    surface.set_uv(Vector2(0,0));surface.add_vertex(a)
    surface.set_uv(Vector2(1,0));surface.add_vertex(b)
    surface.set_uv(Vector2(.5,1));surface.add_vertex(c)

static func impostor(id: String) -> ArrayMesh:
    var key:=id+"_far"
    if meshes.has(key): return meshes[key]
    var result:=nature_mesh(id+"_far")
    for surface in result.get_surface_count():
        var material: StandardMaterial3D=result.surface_get_material(surface).duplicate()
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.32
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
        if material.albedo_texture:
            var image:=material.albedo_texture.get_image()
            if image.is_compressed(): image.decompress()
            image.resize(256,256,Image.INTERPOLATE_BILINEAR)
            image.convert(Image.FORMAT_RGBA8)
            for y in image.get_height():
                for x in image.get_width():
                    var original:=image.get_pixel(x,y)
                    var value: float=original.r*.3+original.g*.5+original.b*.2
                    var color:=Color("769858") if value>.42 else Color("4b7353") if value>.22 else Color("2d5147")
                    color.a=original.a;image.set_pixel(x,y,color)
            image.generate_mipmaps()
            material.albedo_texture=ImageTexture.create_from_image(image)
        material.albedo_color=Color.WHITE
        material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
        result.surface_set_material(surface,material)
    meshes[key]=result;return result

static func ground_material() -> ShaderMaterial:
    if materials.has("ground"): return materials.ground
    var material:=ShaderMaterial.new();material.shader=load("res://world/forest/forest_ground.gdshader")
    materials.ground=material;return material

static func dress_scene(root: Node3D,kind: String="prop") -> void:
    if kind in ["weapon","backpack"]: refine_scene(root,root.scene_file_path.get_file().get_basename())
    elif kind=="vehicle": refine_scene(root,"jeep")
    for mesh in root.find_children("*","MeshInstance3D",true,false):
        if not mesh.mesh or mesh.name.begins_with("Sight"): continue
        for surface in mesh.mesh.get_surface_count():
            var base: Material=mesh.get_active_material(surface)
            if base is ShaderMaterial:
                if base.shader and base.shader.resource_path.ends_with("camo.gdshader"):
                    var camo: ShaderMaterial=base.duplicate()
                    if mesh.material_override: mesh.material_override=camo
                    else: mesh.set_surface_override_material(surface,camo)
                keep(base)
                continue
            if not base is StandardMaterial3D or base.emission_enabled or base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
            if kind=="weapon" and base.albedo_texture!=null:
                # Sourced weapon art already carries real surface detail; keep it, just match the toon shading everywhere else.
                var toon: StandardMaterial3D=base.duplicate()
                toon.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
                toon.roughness=maxf(toon.roughness,.55)
                if mesh.material_override: mesh.material_override=toon
                else: mesh.set_surface_override_material(surface,toon)
                keep(toon)
                continue
            if kind=="prop":
                var painted: StandardMaterial3D=base.duplicate()
                painted.albedo_texture=null;painted.normal_enabled=false;painted.roughness_texture=null
                painted.roughness=.92;painted.metallic=0.0;painted.metallic_specular=.18
                painted.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
                var name_lower:=str(mesh.name).to_lower()
                if "plank" in name_lower or "log" in name_lower or "table" in name_lower:
                    painted.albedo_texture=painted_texture("rough_wood");painted.albedo_color=Color.WHITE
                if mesh.material_override: mesh.material_override=painted
                else: mesh.set_surface_override_material(surface,painted)
                keep(painted)
                continue
            var node_name:=str(mesh.name).to_lower()
            var mat: StandardMaterial3D=base.duplicate()
            var wood: bool="plank" in node_name or "log" in node_name or "table" in node_name or "wood" in base.resource_name.to_lower() or "stock" in node_name
            var cloth: bool=kind in ["hunter","backpack"] or "seat" in node_name or "tent" in node_name or "strap" in node_name
            var asset: String="rough_wood" if wood else "fabric_pattern_07" if cloth else "rust_coarse_01"
            mat.normal_enabled=false;mat.normal_texture=null;mat.roughness_texture=null
            mat.albedo_texture=painted_texture(asset)
            mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
            mat.uv1_scale=Vector3(2,2,1)
            mat.roughness=.92 if wood or cloth else .68
            mat.metallic_specular=.18 if wood or cloth else .35
            mat.metallic=0.0 if wood or cloth else .25
            if wood: mat.albedo_color=Color.WHITE
            if mesh.material_override: mesh.material_override=mat
            else: mesh.set_surface_override_material(surface,mat)
            keep(mat)

static func cinematic(environment: Environment) -> void:
    var compatibility: bool=RenderingServer.get_current_rendering_method()=="gl_compatibility"
    environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR if compatibility else Environment.TONE_MAPPER_FILMIC
    environment.ssao_enabled=not compatibility and LocaleSettings.graphics!="low" and LocaleSettings.cinematic
    environment.ssao_radius=.8;environment.ssao_intensity=.55
    environment.glow_enabled=not compatibility and LocaleSettings.cinematic
    environment.glow_intensity=.25;environment.glow_hdr_threshold=2.0
