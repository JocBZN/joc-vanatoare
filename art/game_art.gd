class_name GameArt
extends RefCounted
## Shared authored/scanned assets; static caches prevent one copy per instance.
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

static func pbr(asset: String, repeats: float=1.0) -> StandardMaterial3D:
    var key:=asset+str(repeats)
    if materials.has(key): return materials[key]
    var material:=StandardMaterial3D.new()
    material.albedo_texture=texture(asset,"col_1" if asset=="fabric_pattern_07" else "diff")
    material.normal_enabled=true;material.normal_texture=texture(asset,"nor_gl")
    material.roughness_texture=texture(asset,"rough" if asset in ["forest_ground_04","rough_wood","fabric_pattern_07"] else "arm")
    material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED if asset in ["forest_ground_04","rough_wood","fabric_pattern_07"] else BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    material.roughness=1;material.uv1_scale=Vector3(repeats,repeats,1)
    materials[key]=material
    return material

static func nature_mesh(id: String) -> ArrayMesh:
    if meshes.has(id): return meshes[id]
    var scene: Node3D=load(ROOT+"nature/"+id+".glb").instantiate()
    var result: ArrayMesh
    for instance in scene.find_children("*","MeshInstance3D",true,false):
        result=instance.mesh.duplicate() as ArrayMesh
        for surface in instance.mesh.get_surface_count():
            var base: Material=instance.get_active_material(surface)
            var material: Material=base
            if base is StandardMaterial3D and (id.begins_with("grass") or id.begins_with("fern") or "twig" in base.resource_name or (id=="swamp_tree" and base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)):
                material=foliage_material(base,id)
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

static func impostor(id: String) -> ArrayMesh:
    var key:=id+"_far"
    if meshes.has(key): return meshes[key]
    var result:=nature_mesh(id+"_far")
    for surface in result.get_surface_count():
        var material: StandardMaterial3D=result.surface_get_material(surface).duplicate()
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.32
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
        material.albedo_color=Color(.74,.8,.74)
        material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
        result.surface_set_material(surface,material)
    meshes[key]=result;return result

static func ground_material() -> ShaderMaterial:
    if materials.has("ground"): return materials.ground
    var material:=ShaderMaterial.new();material.shader=load("res://world/forest/forest_ground.gdshader")
    for kind in ["forest","trail"]:
        var asset: String="forest_ground_04" if kind=="forest" else "rocky_trail"
        material.set_shader_parameter(kind+"_color",texture(asset,"diff"))
        material.set_shader_parameter(kind+"_normal",texture(asset,"nor_gl"))
        material.set_shader_parameter(kind+"_rough",texture(asset,"rough" if kind=="forest" else "arm"))
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
                    camo.set_shader_parameter("weave_normal",texture("fabric_pattern_07","nor_gl"))
                    camo.set_shader_parameter("weave_rough",texture("fabric_pattern_07","rough"))
                    if mesh.material_override: mesh.material_override=camo
                    else: mesh.set_surface_override_material(surface,camo)
                keep(base)
                continue
            if not base is StandardMaterial3D or base.emission_enabled or base.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
            var node_name:=str(mesh.name).to_lower()
            var mat: StandardMaterial3D=base.duplicate()
            var wood: bool="plank" in node_name or "log" in node_name or "table" in node_name or "wood" in base.resource_name.to_lower() or "stock" in node_name
            var cloth: bool=kind in ["hunter","backpack"] or "seat" in node_name or "tent" in node_name or "strap" in node_name
            var asset: String="rough_wood" if wood else "fabric_pattern_07" if cloth else "rust_coarse_01"
            mat.normal_enabled=true;mat.normal_texture=texture(asset,"nor_gl");mat.normal_scale=.45 if cloth else .3
            mat.roughness_texture=texture(asset,"rough" if wood or cloth else "arm")
            mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED if wood or cloth else BaseMaterial3D.TEXTURE_CHANNEL_GREEN
            mat.uv1_scale=Vector3(2,2,1)
            mat.roughness=.88 if wood or cloth else .65
            if wood: mat.albedo_texture=texture(asset,"diff");mat.albedo_color=Color(.8,.75,.67)
            elif not cloth: mat.metallic=maxf(mat.metallic,.35 if kind=="vehicle" else .6)
            if mesh.material_override: mesh.material_override=mat
            else: mesh.set_surface_override_material(surface,mat)
            keep(mat)

static func cinematic(environment: Environment) -> void:
    environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    if RenderingServer.get_current_rendering_method()=="gl_compatibility": return
    environment.ssao_enabled=LocaleSettings.graphics!="low" and LocaleSettings.cinematic;environment.ssao_radius=1.1;environment.ssao_intensity=1.35
    environment.glow_enabled=LocaleSettings.cinematic;environment.glow_intensity=.6;environment.glow_hdr_threshold=1.8
