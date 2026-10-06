extends RefCounted
## Collects flat-coloured low-poly primitives and merges them into one mesh per
## colour, the way the camp props are drawn. Every resulting MeshInstance3D is
## tagged "styled" so GameArt.dress_scene keeps its toon palette.
## Preloaded by path (no class_name) so builders work from a stale class cache.

static var _materials: Dictionary={}
var _tools: Dictionary={}

## Flat toon colour shared by the truck, the camp props and the crew.
static func toon(color: Color, glow: float=0.0, double_sided: bool=false) -> StandardMaterial3D:
    var key: String=color.to_html()+"|"+str(glow)+"|"+str(double_sided)
    if _materials.has(key): return _materials[key]
    var material:=StandardMaterial3D.new();material.albedo_color=color
    material.roughness=.9;material.metallic_specular=.2;material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
    if glow>0.0: material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=glow
    if double_sided: material.cull_mode=BaseMaterial3D.CULL_DISABLED
    _materials[key]=material
    return material

func mesh(shape: Mesh, transform_value: Transform3D, color: Color, glow: float=0.0, double_sided: bool=false) -> void:
    var key: String=color.to_html()+"|"+str(glow)+"|"+str(double_sided)
    if not _tools.has(key):
        var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        _tools[key]={"tool":tool,"color":color,"glow":glow,"double":double_sided}
    _tools[key].tool.append_from(shape,0,transform_value)

## Axis-aligned box between two corners.
func box(a: Vector3, b: Vector3, color: Color, glow: float=0.0) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var shape:=BoxMesh.new();shape.size=high-low
    mesh(shape,Transform3D(Basis.IDENTITY,(low+high)*.5),color,glow)

func box_at(center: Vector3, size: Vector3, euler: Vector3, color: Color, glow: float=0.0) -> void:
    var shape:=BoxMesh.new();shape.size=size
    mesh(shape,Transform3D(Basis.from_euler(euler),center),color,glow)

func cylinder(center: Vector3, top: float, bottom: float, height: float, color: Color, euler: Vector3=Vector3.ZERO, segments: int=8, glow: float=0.0, double_sided: bool=false) -> void:
    var shape:=CylinderMesh.new();shape.top_radius=top;shape.bottom_radius=bottom;shape.height=height;shape.radial_segments=segments;shape.rings=1
    mesh(shape,Transform3D(Basis.from_euler(euler),center),color,glow,double_sided)

## A cylinder running from point `a` to point `b` (branches, rails, struts).
func rod(a: Vector3, b: Vector3, radius: float, color: Color, segments: int=6, tip: float=-1.0) -> void:
    var along: Vector3=b-a
    var length: float=along.length()
    if length<.001: return
    var up: Vector3=along/length
    var side: Vector3=up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<.9 else Vector3.RIGHT).normalized()
    var basis:=Basis(side,up,side.cross(up)).orthonormalized()
    var shape:=CylinderMesh.new();shape.top_radius=radius if tip<0.0 else tip;shape.bottom_radius=radius;shape.height=length;shape.radial_segments=segments;shape.rings=1
    mesh(shape,Transform3D(basis,(a+b)*.5),color)

func sphere(center: Vector3, radius: float, color: Color, scale_value: Vector3=Vector3.ONE, glow: float=0.0, segments: int=7) -> void:
    var shape:=SphereMesh.new();shape.radius=radius;shape.height=radius*2;shape.radial_segments=segments;shape.rings=maxi(3,segments/2+1)
    mesh(shape,Transform3D(Basis.from_scale(scale_value),center),color,glow)

## Isosceles triangle prism (gables, roof ends) standing on its base.
func prism(center: Vector3, size: Vector3, euler: Vector3, color: Color) -> void:
    var shape:=PrismMesh.new();shape.size=size;shape.left_to_right=.5
    mesh(shape,Transform3D(Basis.from_euler(euler),center),color)

## A flat polygon facing +Z or -Z (log end rings), clipped from above at `cut_y`.
func disc(center: Vector3, radius: float, cut_y: float, color: Color, facing: float, segments: int=14, glow: float=0.0) -> void:
    var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var normal:=Vector3(0,0,signf(facing))
    var points: Array[Vector3]=[]
    for k in segments:
        var angle: float=float(k)*TAU/float(segments)
        points.append(Vector3(cos(angle)*radius,minf(sin(angle)*radius,cut_y),0))
    var middle:=Vector3(0,minf(0.0,cut_y),0)
    for k in segments:
        var a: Vector3=points[k];var b: Vector3=points[(k+1)%segments]
        tool.set_normal(normal)
        # Godot treats clockwise triangles as front faces.
        if facing>0: tool.add_vertex(middle);tool.add_vertex(b);tool.add_vertex(a)
        else: tool.add_vertex(middle);tool.add_vertex(a);tool.add_vertex(b)
    var built: ArrayMesh=tool.commit()
    mesh(built,Transform3D(Basis.IDENTITY,center),color,glow)

func is_empty() -> bool:
    return _tools.is_empty()

## Commits every colour batch under `parent` as one MeshInstance3D per colour.
func commit(parent: Node3D, prefix: String="Paint", shadows: bool=true) -> Array[MeshInstance3D]:
    var made: Array[MeshInstance3D]=[]
    for key in _tools:
        var entry: Dictionary=_tools[key]
        var node:=MeshInstance3D.new();node.name=prefix+str(made.size())
        node.mesh=entry.tool.commit();node.material_override=toon(entry.color,entry.glow,entry.double)
        if not shadows: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.set_meta("styled",true);parent.add_child(node);made.append(node)
    _tools.clear()
    return made
