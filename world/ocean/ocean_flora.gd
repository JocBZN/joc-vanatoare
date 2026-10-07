extends RefCounted
## Procedural low-poly sea life, island trees and landmarks for the ocean map.
## Every builder returns an ArrayMesh with vertex colours (use `solid_material`
## or `leaf_material`); nothing here needs an external asset. Preloaded by path.

## Collects triangles with a flat colour each; normals are generated flat.
class Builder:
    var st:=SurfaceTool.new()
    func _init() -> void: st.begin(Mesh.PRIMITIVE_TRIANGLES)
    func tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
        for v in [a,b,c]:
            st.set_color(color);st.add_vertex(v)
    ## A triangle with a colour and a (u, v) per corner, facing `outward`. The sea models use
    ## u = angle round the body and v = position along it, so one shader can paint stripes,
    ## bars and spots that stay on the animal.
    func tri_uv(a: Vector3,b: Vector3,c: Vector3,ca: Color,cb: Color,cc: Color,ua: Vector2,ub: Vector2,uc: Vector2,outward: Vector3) -> void:
        var order: Array=[[a,ca,ua],[b,cb,ub],[c,cc,uc]]
        if (c-a).cross(b-a).dot(outward)<0.0: order=[[a,ca,ua],[c,cc,uc],[b,cb,ub]]
        for entry in order:
            st.set_color(entry[1]);st.set_uv(entry[2]);st.add_vertex(entry[0])
    ## Same as tri_out with a colour per corner, so a tube can fade from root to tip.
    func tri_out_c(a: Vector3,b: Vector3,c: Vector3,ca: Color,cb: Color,cc: Color,outward: Vector3) -> void:
        var order: Array=[[a,ca],[b,cb],[c,cc]]
        if (c-a).cross(b-a).dot(outward)<0.0: order=[[a,ca],[c,cc],[b,cb]]
        for entry in order:
            st.set_color(entry[1]);st.add_vertex(entry[0])
    ## Triangle whose front face looks along `outward` (Godot fronts are clockwise).
    func tri_out(a: Vector3,b: Vector3,c: Vector3,color: Color,outward: Vector3) -> void:
        if (c-a).cross(b-a).dot(outward)<0.0: tri(a,c,b,color)
        else: tri(a,b,c,color)
    func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
        tri(a,b,c,color);tri(a,c,d,color)
    ## Tapered tube from a to b.
    func tube(a: Vector3,b: Vector3,ra: float,rb: float,sides: int,color: Color,color_tip: Color=Color(-1,0,0)) -> void:
        var axis: Vector3=b-a
        if axis.length()<.0001: return
        var up: Vector3=axis.normalized()
        var side: Vector3=up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT))<.9 else Vector3.FORWARD).normalized()
        var other: Vector3=up.cross(side)
        var tip: Color=color if color_tip.r<0.0 else color_tip
        for i in sides:
            var t0: float=TAU*i/float(sides);var t1: float=TAU*(i+1)/float(sides)
            var d0: Vector3=side*cos(t0)+other*sin(t0);var d1: Vector3=side*cos(t1)+other*sin(t1)
            var a0: Vector3=a+d0*ra;var a1: Vector3=a+d1*ra;var b0: Vector3=b+d0*rb;var b1: Vector3=b+d1*rb
            var mid: Vector3=(d0+d1)
            tri_out_c(a0,a1,b0,color,color,tip,mid)
            tri_out_c(a1,b1,b0,color,tip,tip,mid)
        if rb>.0001:
            for i in sides:
                var t0: float=TAU*i/float(sides);var t1: float=TAU*(i+1)/float(sides)
                tri_out(b,b+(side*cos(t0)+other*sin(t0))*rb,b+(side*cos(t1)+other*sin(t1))*rb,tip,up)
    func box(center: Vector3,size: Vector3,euler: Vector3,color: Color) -> void:
        var basis:=Basis.from_euler(euler)
        var h: Vector3=size*.5
        var corners: Array[Vector3]=[]
        for x in [-1,1]:
            for y in [-1,1]:
                for z in [-1,1]: corners.append(center+basis*Vector3(x*h.x,y*h.y,z*h.z))
        var faces: Array=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
        for face in faces:
            var o: Vector3=(corners[face[0]]+corners[face[1]]+corners[face[2]]+corners[face[3]])*.25-center
            tri_out(corners[face[0]],corners[face[1]],corners[face[2]],color,o)
            tri_out(corners[face[0]],corners[face[2]],corners[face[3]],color,o)
    ## A squashed, optionally lumpy sphere (`bumps` ridges around and over it).
    func blob(center: Vector3,radius: Vector3,color: Color,seg: int=10,rings: int=6,bumps: float=0.0,ridge: int=7,color_top: Color=Color(-1,0,0),cut_below: float=-1.0) -> void:
        var top: Color=color if color_top.r<0.0 else color_top
        var grid: Array=[]
        for r in rings+1:
            var lat: float=PI*r/float(rings)
            var row: Array[Vector3]=[]
            for s in seg+1:
                var lon: float=TAU*s/float(seg)
                var wobble: float=1.0+bumps*sin(lon*ridge)*sin(lat*(ridge+2))
                var dir:=Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))
                row.append(center+Vector3(dir.x*radius.x,maxf(dir.y,cut_below)*radius.y,dir.z*radius.z)*wobble)
            grid.append(row)
        for r in rings:
            for s in seg:
                var shade: Color=color.lerp(top,1.0-float(r)/float(rings))
                var a: Vector3=grid[r][s];var b: Vector3=grid[r][s+1];var c: Vector3=grid[r+1][s+1];var d: Vector3=grid[r+1][s]
                var o: Vector3=(a+b+c+d)*.25-center
                tri_out(a,b,c,shade,o);tri_out(a,c,d,shade,o)
    func finish() -> ArrayMesh:
        st.generate_normals()
        return st.commit()

## Reef, rock and palm material (flora.gdshader): sRGB vertex colours with a touch of glow.
static func shader_material(glow: float=.3,saturation: float=1.15) -> ShaderMaterial:
    var m:=ShaderMaterial.new();m.shader=load("res://world/ocean/flora.gdshader")
    m.set_shader_parameter("glow",glow);m.set_shader_parameter("saturation",saturation)
    return m

static func solid_material(emission: float=0.0) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true;m.roughness=.78;m.metallic_specular=.25
    if emission>0.0:
        m.emission_enabled=true;m.emission_operator=BaseMaterial3D.EMISSION_OP_ADD
        m.emission_energy_multiplier=emission;m.emission_texture=null
        m.emission=Color(1,1,1)
    return m

static func leaf_material() -> StandardMaterial3D:
    var m:=solid_material();m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m

static func _hsv(h: float,s: float,v: float) -> Color: return Color.from_hsv(fposmod(h,1.0),clampf(s,0,1),clampf(v,0,1))

## Builds a variant by kind name, so the map can drive them from one table.
static func make(kind: String,seed_value: int) -> ArrayMesh:
    match kind:
        "branching": return branching(seed_value)
        "brain": return brain(seed_value)
        "fan": return fan(seed_value)
        "table": return table(seed_value)
        "tubes": return tubes(seed_value)
        "anemone": return anemone(seed_value)
        "urchin": return urchin(seed_value)
        "starfish": return starfish(seed_value)
        "clam": return clam(seed_value)
        "rock": return rock(seed_value)
        "kelp": return kelp(seed_value)
        "seagrass": return seagrass(seed_value)
        _: return palm(seed_value)

# --- Corals ---------------------------------------------------------------------------------

const CORAL_HUES: Array[float]=[.02,.07,.92,.85,.12,.55,.62,.45]

static func branching(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var hue: float=CORAL_HUES[rng.randi()%CORAL_HUES.size()]
    var base_color: Color=_hsv(hue,.65,.85);var tip_color: Color=_hsv(hue+.04,.35,1.0)
    for stem in rng.randi_range(2,3):
        var start:=Vector3(rng.randf_range(-.25,.25),0,rng.randf_range(-.25,.25))
        _branch(b,start,Vector3(rng.randf_range(-.3,.3),1,rng.randf_range(-.3,.3)).normalized(),rng.randf_range(.55,.9),.09,2,rng,base_color,tip_color)
    return b.finish()

static func _branch(b: Builder,from: Vector3,dir: Vector3,length: float,radius: float,depth: int,rng: RandomNumberGenerator,base: Color,tip: Color) -> void:
    var to: Vector3=from+dir*length
    b.tube(from,to,radius,radius*.62,5,base,tip if depth==0 else base)
    if depth<=0: return
    for k in rng.randi_range(2,3):
        var bend:=Vector3(rng.randf_range(-.85,.85),rng.randf_range(.0,.55),rng.randf_range(-.85,.85))
        _branch(b,to,(dir+bend).normalized(),length*.72,radius*.62,depth-1,rng,base.lerp(tip,.4),tip)

static func brain(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var hue: float=CORAL_HUES[rng.randi()%CORAL_HUES.size()]
    var b:=Builder.new()
    b.blob(Vector3(0,.18,0),Vector3(.6,.5,.6),_hsv(hue,.45,.72),12,8,.07,rng.randi_range(6,9),_hsv(hue+.03,.3,.95),0.0)
    for k in rng.randi_range(1,3):
        b.blob(Vector3(rng.randf_range(-.6,.6),.08,rng.randf_range(-.6,.6)),Vector3(.3,.25,.3),_hsv(hue,.5,.7),8,5,.08,5,_hsv(hue+.03,.3,.9),0.0)
    return b.finish()

static func fan(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var hue: float=[.82,.0,.1,.7][rng.randi()%4]
    var b:=Builder.new()
    var inner: Color=_hsv(hue,.7,.7);var outer: Color=_hsv(hue+.02,.45,1.0)
    b.tube(Vector3.ZERO,Vector3(0,.35,0),.06,.05,5,inner)
    var ribs: int=11
    var spread: float=rng.randf_range(1.0,1.35)
    var points: Array[Vector3]=[]
    for i in ribs:
        var angle: float=lerpf(-spread,spread,float(i)/(ribs-1))
        var length: float=1.15+.35*cos(angle*1.2)+rng.randf_range(-.05,.05)
        var rim:=Vector3(sin(angle)*length,.35+cos(angle)*length,0)
        points.append(rim)
        b.tube(Vector3(0,.35,0),rim,.025,.012,4,inner,outer)
    for i in ribs-1:
        b.tri(Vector3(0,.35,0),points[i],points[i+1],inner.lerp(outer,.5))
    return b.finish()

static func table(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var hue: float=CORAL_HUES[rng.randi()%CORAL_HUES.size()]
    var b:=Builder.new()
    var height: float=rng.randf_range(.5,.95);var radius: float=rng.randf_range(.9,1.5)
    b.tube(Vector3.ZERO,Vector3(0,height,0),.2,.14,7,_hsv(hue,.5,.6))
    var segs: int=14
    var rim: Array[Vector3]=[]
    for i in segs:
        var angle: float=TAU*i/float(segs)
        var wobble: float=1.0+.14*sin(angle*5.0+hue*20.0)
        rim.append(Vector3(cos(angle)*radius*wobble,height-.06+.1*sin(angle*3.0),sin(angle)*radius*wobble))
    for i in segs:
        var a: Vector3=rim[i];var c: Vector3=rim[(i+1)%segs]
        b.tri_out(Vector3(0,height+.1,0),a,c,_hsv(hue+.03,.35,1.0),Vector3.UP)
        b.tri_out(Vector3(0,height-.12,0),a,c,_hsv(hue,.6,.55),Vector3.DOWN)
    return b.finish()

static func tubes(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var hue: float=[.12,.95,.58,.78][rng.randi()%4]
    var b:=Builder.new()
    for i in rng.randi_range(5,9):
        var at:=Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4))
        var top: Vector3=at+Vector3(rng.randf_range(-.15,.15),rng.randf_range(.5,1.5),rng.randf_range(-.15,.15))
        b.tube(at,top,.11,.085,7,_hsv(hue,.6,.85),_hsv(hue+.05,.3,1.0))
        b.tube(top,top+Vector3(0,.012,0),.07,.06,7,Color(.08,.04,.1))
    return b.finish()

static func anemone(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var hue: float=[.92,.5,.08,.75][rng.randi()%4]
    var b:=Builder.new()
    b.tube(Vector3.ZERO,Vector3(0,.22,0),.2,.16,8,_hsv(hue,.4,.55))
    for i in 16:
        var angle: float=TAU*i/16.0+rng.randf_range(-.1,.1)
        var lean: float=rng.randf_range(.25,.7)
        var start:=Vector3(cos(angle)*.1,.22,sin(angle)*.1)
        var tip: Vector3=start+Vector3(cos(angle)*lean*.5,rng.randf_range(.3,.55),sin(angle)*lean*.5)
        b.tube(start,tip,.03,.012,4,_hsv(hue,.55,.9),_hsv(hue+.08,.2,1.0))
    return b.finish()

static func urchin(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var color:=Color(.16,.07,.22).lerp(Color(.4,.12,.1),rng.randf()*.6)
    b.blob(Vector3(0,.2,0),Vector3(.2,.18,.2),color,8,5,0.0,5,color,0.0)
    for i in 26:
        var dir:=Vector3(rng.randf_range(-1,1),rng.randf_range(.1,1),rng.randf_range(-1,1)).normalized()
        b.tube(Vector3(0,.2,0)+dir*.16,Vector3(0,.2,0)+dir*(.48+rng.randf()*.12),.014,.003,3,color.lightened(.1))
    return b.finish()

static func starfish(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var color:=_hsv(rng.randf_range(.0,.1),.8,.95)
    var center:=Vector3(0,.06,0)
    for i in 5:
        var angle: float=TAU*i/5.0
        var tip:=Vector3(cos(angle)*.5,.025,sin(angle)*.5)
        var l:=Vector3(cos(angle-.38)*.13,.06,sin(angle-.38)*.13)
        var r:=Vector3(cos(angle+.38)*.13,.06,sin(angle+.38)*.13)
        b.tri_out(center,l,tip,color,Vector3.UP);b.tri_out(center,tip,r,color,Vector3.UP)
        b.tri_out(center,tip,l,color.darkened(.3),Vector3.DOWN);b.tri_out(center,r,tip,color.darkened(.3),Vector3.DOWN)
    return b.finish()

static func clam(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var shell:=Color(.78,.72,.6)
    b.blob(Vector3(0,.35,.18),Vector3(.7,.38,.5),shell,12,6,.06,9,shell.lightened(.12),0.0)
    b.blob(Vector3(0,.3,-.12),Vector3(.7,.22,.5),shell.darkened(.1),12,5,.06,9,shell,-0.0)
    b.blob(Vector3(0,.33,0),Vector3(.55,.14,.38),Color(.1,.55,.65),10,4,.1,6,Color(.3,.9,.8),0.0)
    return b.finish()

static func rock(seed_value: int,tint: Color=Color(.45,.43,.4)) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var base:=tint.lerp(Color(.3,.34,.36),rng.randf()*.5)
    b.blob(Vector3(0,.5,0),Vector3(rng.randf_range(.9,1.4),rng.randf_range(.6,1.0),rng.randf_range(.9,1.4)),base,9,6,rng.randf_range(.08,.2),rng.randi_range(3,6),base.lightened(.12),-0.35)
    for k in rng.randi_range(1,3):
        b.blob(Vector3(rng.randf_range(-.9,.9),.25,rng.randf_range(-.9,.9)),Vector3.ONE*rng.randf_range(.3,.55),base.darkened(.1),7,4,.18,4,base,-0.3)
    return b.finish()

# --- Ribbons: kelp and seagrass (swayed by kelp.gdshader; UV.y is height 0..1) ---------------

static func _ribbon(b: Builder,base: Vector3,height: float,width: float,segments: int,lean: Vector3,color: Color,tip: Color) -> void:
    var points: Array[Vector3]=[];var widths: Array[float]=[]
    for i in segments+1:
        var f: float=float(i)/segments
        points.append(base+Vector3(lean.x*f*f,height*f,lean.z*f*f))
        widths.append(width*(1.0-.55*f))
    var side:=Vector3(cos(lean.y),0,sin(lean.y))
    for i in segments:
        var f0: float=float(i)/segments;var f1: float=float(i+1)/segments
        var a: Vector3=points[i]-side*widths[i];var c: Vector3=points[i]+side*widths[i]
        var d: Vector3=points[i+1]-side*widths[i+1];var e: Vector3=points[i+1]+side*widths[i+1]
        var c0: Color=color.lerp(tip,f0);var c1: Color=color.lerp(tip,f1)
        b.st.set_color(c0);b.st.set_uv(Vector2(0,f0));b.st.add_vertex(a)
        b.st.set_color(c0);b.st.set_uv(Vector2(1,f0));b.st.add_vertex(c)
        b.st.set_color(c1);b.st.set_uv(Vector2(0,f1));b.st.add_vertex(d)
        b.st.set_color(c0);b.st.set_uv(Vector2(1,f0));b.st.add_vertex(c)
        b.st.set_color(c1);b.st.set_uv(Vector2(1,f1));b.st.add_vertex(e)
        b.st.set_color(c1);b.st.set_uv(Vector2(0,f1));b.st.add_vertex(d)

static func kelp(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var base:=Color(.16,.46,.14);var tip:=Color(.56,.82,.26)
    if rng.randf()<.35: base=Color(.4,.3,.08);tip=Color(.85,.62,.18)
    for i in rng.randi_range(3,5):
        _ribbon(b,Vector3(rng.randf_range(-.45,.45),0,rng.randf_range(-.45,.45)),rng.randf_range(7.0,13.0),rng.randf_range(.22,.4),12,
            Vector3(rng.randf_range(-1.2,1.2),rng.randf()*TAU,rng.randf_range(-1.2,1.2)),base,tip)
    b.st.generate_normals()
    return b.st.commit()

static func seagrass(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var base:=Color(.12,.35,.14);var tip:=Color(.45,.7,.28)
    for i in 9:
        _ribbon(b,Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4)),rng.randf_range(.5,1.3),rng.randf_range(.04,.08),3,
            Vector3(rng.randf_range(-.4,.4),rng.randf()*TAU,rng.randf_range(-.4,.4)),base,tip)
    b.st.generate_normals()
    return b.st.commit()

# --- Island trees ------------------------------------------------------------------------------

static func palm(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var height: float=rng.randf_range(6.5,10.0)
    var bend:=Vector3(rng.randf_range(-2.0,2.0),0,rng.randf_range(-2.0,2.0))
    var trunk:=Color(.5,.38,.24);var trunk_dark:=Color(.38,.27,.17)
    var previous:=Vector3.ZERO
    var top:=Vector3.ZERO
    for i in 8:
        var f: float=float(i+1)/8.0
        var point:=Vector3(bend.x*f*f,height*f,bend.z*f*f)
        b.tube(previous,point,.3-.13*(float(i)/8.0),.3-.13*f,6,trunk if i%2==0 else trunk_dark)
        previous=point
    top=previous
    var leaf_dark:=Color(.12,.4,.14);var leaf_light:=Color(.4,.68,.22)
    for k in 9:
        var angle: float=TAU*k/9.0+rng.randf_range(-.2,.2)
        var dir:=Vector3(cos(angle),0,sin(angle))
        var length: float=rng.randf_range(3.2,4.4)
        var rib: Array[Vector3]=[]
        for i in 6:
            var f: float=float(i)/5.0
            rib.append(top+dir*length*f+Vector3(0,length*(.42*sin(f*PI*.9)-.55*f*f),0)+Vector3(0,.4,0))
        for i in 5:
            var f: float=float(i)/5.0
            b.tube(rib[i],rib[i+1],.05,.04,3,leaf_dark)
            var side:=dir.cross(Vector3.UP)
            var width: float=.95*sin((f+.1)*PI*.85)+.15
            var c: Color=leaf_dark.lerp(leaf_light,f)
            b.tri(rib[i]-side*width,rib[i]+side*width,rib[i+1]-dir*.05+Vector3(0,-.25,0),c)
            b.tri(rib[i],rib[i+1],rib[i]-side*width+Vector3(0,-.5,0)+dir*.5,c.darkened(.15))
            b.tri(rib[i],rib[i+1],rib[i]+side*width+Vector3(0,-.5,0)+dir*.5,c.darkened(.15))
    for k in 3:
        var angle: float=TAU*k/3.0
        b.blob(top+Vector3(cos(angle)*.3,-.35,sin(angle)*.3),Vector3.ONE*.2,Color(.32,.22,.1),6,4,0.0,3,Color(.4,.3,.14),-1.0)
    return b.finish()

# --- Landmarks ---------------------------------------------------------------------------------

static func shipwreck(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var plank:=Color(.36,.24,.14);var dark:=Color(.22,.15,.1);var moss:=Color(.2,.36,.2)
    var length: float=24.0;var half: float=4.2
    # A keel, ribs bowed outward like a skeleton, and planking that stops half way up.
    b.box(Vector3(0,.2,0),Vector3(.5,.5,length),Vector3.ZERO,dark)
    var ribs: int=11
    for i in ribs:
        var z: float=lerpf(-length*.5+2.0,length*.5-2.0,float(i)/(ribs-1))
        var taper: float=1.0-pow(absf(z)/(length*.5),2.5)
        var w: float=half*taper+.4
        var tall: float=4.8*taper+1.2
        for side in [-1.0,1.0]:
            var steps: int=6
            var last:=Vector3(0,.3,z)
            for s in steps:
                var f: float=float(s+1)/steps
                var point:=Vector3(side*w*sin(f*PI*.5),.3+tall*f,z)
                b.tube(last,point,.14,.12,4,dark)
                last=point
        if rng.randf()<.8: b.box(Vector3(0,.8,z),Vector3(w*1.6,.2,.3),Vector3.ZERO,dark)
    for row in 5:
        for z_i in 7:
            if rng.randf()<.3: continue
            var z: float=lerpf(-length*.5+2.5,length*.5-2.5,float(z_i)/6.0)+rng.randf_range(-.3,.3)
            var taper: float=1.0-pow(absf(z)/(length*.5),2.5)
            var f: float=(row+1)/6.0
            for side in [-1.0,1.0]:
                var x: float=side*(half*taper+.4)*sin(f*PI*.5)
                b.box(Vector3(x,.3+(4.8*taper+1.2)*f,z),Vector3(.12,.9,1.6),Vector3(0,0,side*.35*(1.0-f)),plank.lerp(moss,rng.randf()*.4))
    # Broken mast, a fallen yard, cannons and a coil of chain.
    b.tube(Vector3(0,.8,2.0),Vector3(1.5,8.5,2.5),.28,.2,6,plank)
    b.tube(Vector3(1.4,7.2,2.4),Vector3(-4.0,6.1,5.5),.14,.1,5,plank)
    for k in 4:
        var z: float=-6.0+k*3.0
        b.tube(Vector3(-2.2,1.8,z),Vector3(-3.4,1.9,z),.28,.2,6,Color(.12,.12,.14))
    b.blob(Vector3(.8,.4,-9.0),Vector3(.9,.45,.9),Color(.18,.18,.2),8,5,.1,5,Color(.3,.3,.32),0.0)
    return b.finish()

static func chest() -> ArrayMesh:
    var b:=Builder.new()
    var wood:=Color(.42,.26,.12);var band:=Color(.85,.68,.2)
    b.box(Vector3(0,.35,0),Vector3(1.2,.7,.8),Vector3.ZERO,wood)
    b.box(Vector3(0,.8,-.1),Vector3(1.2,.3,.8),Vector3(-.5,0,0),wood)
    for x in [-.45,.45]: b.box(Vector3(x,.5,0),Vector3(.1,.95,.86),Vector3.ZERO,band)
    b.blob(Vector3(0,.78,.12),Vector3(.5,.12,.3),Color(1,.82,.25),7,3,.2,5,Color(1,.95,.5),0.0)
    return b.finish()

static func ruins(seed_value: int) -> ArrayMesh:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var b:=Builder.new()
    var stone:=Color(.62,.62,.55);var dark:=Color(.45,.47,.42)
    b.box(Vector3(0,.35,0),Vector3(16,.7,12),Vector3.ZERO,dark)
    b.box(Vector3(0,.9,0),Vector3(14,.4,10),Vector3.ZERO,stone)
    for i in 6:
        for side in [-1.0,1.0]:
            var at:=Vector3(-6.0+i*2.4,1.1,side*4.2)
            var h: float=rng.randf_range(2.5,6.5)
            b.tube(at,at+Vector3(rng.randf_range(-.2,.2),h,rng.randf_range(-.2,.2)),.6,.52,8,stone,stone.darkened(.12))
            b.box(at+Vector3(0,.15,0),Vector3(1.6,.3,1.6),Vector3.ZERO,dark)
    # A fallen column and an arch fragment.
    b.tube(Vector3(-4,1.5,-.5),Vector3(3.5,1.2,1.2),.55,.5,8,stone)
    b.box(Vector3(5.5,4.0,-1.0),Vector3(.9,5.5,.9),Vector3.ZERO,stone)
    b.box(Vector3(7.8,4.0,-1.0),Vector3(.9,5.5,.9),Vector3.ZERO,stone)
    b.box(Vector3(6.65,6.6,-1.0),Vector3(3.6,.8,1.1),Vector3(0,0,.04),dark)
    return b.finish()

static func whale_bones() -> ArrayMesh:
    var b:=Builder.new()
    var bone:=Color(.86,.82,.7)
    for i in 22:
        var z: float=-14.0+i*1.3
        var size: float=.6+.25*sin(PI*float(i)/21.0)
        b.blob(Vector3(0,.9+.2*sin(i*.3),z),Vector3(size,size*.7,.5),bone,7,4,0.0,4,bone.lightened(.08),-1.0)
        var rib_len: float=3.2*sin(PI*float(i)/21.0)+.3
        if i>3 and i<18:
            for side in [-1.0,1.0]:
                var last:=Vector3(0,1.1,z)
                for s in 5:
                    var f: float=float(s+1)/5.0
                    var point:=Vector3(side*rib_len*sin(f*PI*.55),1.1+rib_len*.9*(1.0-cos(f*PI*.55))*-.5+rib_len*.45*f,z)
                    b.tube(last,point,.14,.1,4,bone)
                    last=point
    b.blob(Vector3(0,1.0,-17.0),Vector3(2.0,1.2,3.0),bone,10,6,.04,6,bone.lightened(.1),0.0)
    return b.finish()

static func lighthouse() -> ArrayMesh:
    var b:=Builder.new()
    var white:=Color(.95,.94,.9);var red:=Color(.78,.16,.14)
    var y: float=0.0
    for i in 6:
        var r0: float=3.2-i*.32;var r1: float=3.2-(i+1)*.32
        b.tube(Vector3(0,y,0),Vector3(0,y+4.0,0),r0,r1,12,red if i%2==0 else white)
        y+=4.0
    b.tube(Vector3(0,y,0),Vector3(0,y+.5,0),2.8,2.8,12,Color(.2,.2,.22))
    b.tube(Vector3(0,y+.5,0),Vector3(0,y+3.2,0),1.6,1.6,10,Color(.3,.55,.7,1.0))
    for k in 8:
        var a: float=TAU*k/8.0
        b.tube(Vector3(cos(a)*1.65,y+.5,sin(a)*1.65),Vector3(cos(a)*1.65,y+3.2,sin(a)*1.65),.08,.08,4,Color(.15,.15,.17))
    b.tube(Vector3(0,y+3.2,0),Vector3(0,y+5.0,0),2.1,.05,12,red)
    b.tube(Vector3(0,y+.5,0),Vector3(0,y+.58,0),3.3,3.3,12,Color(.15,.15,.17))
    return b.finish()

static func pier(length: float) -> ArrayMesh:
    var b:=Builder.new()
    var wood:=Color(.55,.38,.22);var post:=Color(.34,.24,.15)
    var count: int=int(length/.6)
    for i in count:
        b.box(Vector3(0,.0,-i*.6),Vector3(3.4,.14,.5),Vector3.ZERO,wood.lerp(post,float(i%3)*.15))
    for i in int(length/4.0)+1:
        for side in [-1.0,1.0]:
            b.tube(Vector3(side*1.75,-3.5,-i*4.0),Vector3(side*1.75,1.2,-i*4.0),.16,.13,6,post)
        if i%2==0: b.tube(Vector3(1.75,1.2,-i*4.0),Vector3(1.75,2.5,-i*4.0),.05,.05,4,post)
    for side in [-1.0,1.0]: b.box(Vector3(side*1.75,.9,-length*.5),Vector3(.1,.12,length),Vector3.ZERO,post)
    return b.finish()

# --- Swimmers for ambient schools -----------------------------------------------------------------

## A little fish pointing along -Z, tail at +Z (the school shader wiggles it).
static func fish_body() -> ArrayMesh:
    var b:=Builder.new()
    var back:=Color(.25,.45,.75);var belly:=Color(.95,.95,.9);var fin:=Color(.95,.7,.2)
    b.blob(Vector3.ZERO,Vector3(.14,.2,.55),back,8,5,0.0,3,belly,-1.0)
    b.tri(Vector3(0,0,.42),Vector3(0,.28,.82),Vector3(0,-.28,.82),fin)
    b.tri(Vector3(0,0,.42),Vector3(0,-.28,.82),Vector3(0,.28,.82),fin)
    b.tri(Vector3(0,.18,-.05),Vector3(0,.4,.25),Vector3(0,.16,.3),fin)
    b.tri(Vector3(0,.18,-.05),Vector3(0,.16,.3),Vector3(0,.4,.25),fin)
    return b.finish()

## Small reef fish for the swimming schools (fish_school.gdshader wiggles the tail, +Z).
## 0 blue tang with a yellow tail, 1 angelfish with trailing filaments, 2 clownfish with white
## bands, 3 silver sardine, 4 a yellow butterflyfish.
static func reef_fish(variant: int) -> ArrayMesh:
    var b:=Builder.new()
    match variant:
        0:
            var body:=Color("2f72e8");var fin:=Color("ffd53c")
            b.blob(Vector3.ZERO,Vector3(.09,.3,.5),body,10,6,0.0,3,body.lightened(.2),-1.0)
            for flip in [1.0,-1.0]:
                b.tri(Vector3(0,0,.42),Vector3(0,.3*flip,.88),Vector3(0,-.3*flip,.88),fin)
                b.tri(Vector3(0,.26*flip,-.22),Vector3(0,.46*flip,.08),Vector3(0,.24*flip,.38),Color("1e4fb0"))
            b.blob(Vector3(.07,.06,-.3),Vector3(.025,.025,.025),Color("050505"),5,3,0.0,3,Color("050505"),-1.0)
            b.blob(Vector3(-.07,.06,-.3),Vector3(.025,.025,.025),Color("050505"),5,3,0.0,3,Color("050505"),-1.0)
        1:
            var body:=Color("f2d34a");var accent:=Color("3a78d8")
            b.blob(Vector3.ZERO,Vector3(.07,.42,.4),body,10,7,0.0,3,body.lightened(.15),-1.0)
            b.blob(Vector3(0,.0,-.1),Vector3(.075,.2,.16),accent,8,5,0.0,3,accent,-1.0)
            for flip in [1.0,-1.0]:
                b.tri(Vector3(0,.34*flip,-.1),Vector3(0,.78*flip,.5),Vector3(0,.3*flip,.3),accent)
                b.tri(Vector3(0,.34*flip,-.1),Vector3(0,.3*flip,.3),Vector3(0,.78*flip,.5),accent)
            b.tri(Vector3(0,0,.34),Vector3(0,.22,.72),Vector3(0,-.22,.72),Color("ffe58a"))
            b.tri(Vector3(0,0,.34),Vector3(0,-.22,.72),Vector3(0,.22,.72),Color("ffe58a"))
        2:
            var body:=Color("ff7a1a");var white:=Color("fbf6ea")
            b.blob(Vector3.ZERO,Vector3(.1,.17,.38),body,10,6,0.0,3,body,-1.0)
            for z in [-.18,.05,.27]:
                b.blob(Vector3(0,0,z),Vector3(.108,.172,.045),white,8,4,0.0,3,white,-1.0)
            b.tri(Vector3(0,0,.3),Vector3(0,.16,.58),Vector3(0,-.16,.58),Color("ff9a3c"))
            b.tri(Vector3(0,0,.3),Vector3(0,-.16,.58),Vector3(0,.16,.58),Color("ff9a3c"))
            b.tri(Vector3(0,.15,-.15),Vector3(0,.26,.1),Vector3(0,.15,.28),Color("ff9a3c"))
            b.tri(Vector3(0,.15,-.15),Vector3(0,.15,.28),Vector3(0,.26,.1),Color("ff9a3c"))
        3:
            var body:=Color("c9d8e6")
            b.blob(Vector3.ZERO,Vector3(.07,.1,.45),body,8,5,0.0,3,Color("5a7fa8"),-1.0)
            for flip in [1.0,-1.0]:
                b.tri(Vector3(0,0,.38),Vector3(0,.18*flip,.7),Vector3(0,.02*flip,.52),Color("90a4b8"))
                b.tri(Vector3(0,0,.38),Vector3(0,.02*flip,.52),Vector3(0,.18*flip,.7),Color("90a4b8"))
        _:
            var body:=Color("ffe14a");var black:=Color("1a1a1e")
            b.blob(Vector3.ZERO,Vector3(.08,.3,.36),body,10,6,0.0,3,body.lightened(.1),-1.0)
            b.blob(Vector3(0,.0,-.2),Vector3(.085,.1,.05),black,6,4,0.0,3,black,-1.0)
            b.tri(Vector3(0,0,.3),Vector3(0,.18,.62),Vector3(0,-.18,.62),Color("fff3a8"))
            b.tri(Vector3(0,0,.3),Vector3(0,-.18,.62),Vector3(0,.18,.62),Color("fff3a8"))
    return b.finish()

static func manta() -> ArrayMesh:
    var b:=Builder.new()
    var back:=Color(.12,.16,.22);var belly:=Color(.92,.92,.9)
    b.tri(Vector3(0,0,-1.1),Vector3(-2.8,.0,.3),Vector3(0,.12,.5),back)
    b.tri(Vector3(0,0,-1.1),Vector3(0,.12,.5),Vector3(2.8,.0,.3),back)
    b.tri(Vector3(0,-.05,-1.1),Vector3(0,.0,.5),Vector3(-2.8,-.05,.3),belly)
    b.tri(Vector3(0,-.05,-1.1),Vector3(2.8,-.05,.3),Vector3(0,.0,.5),belly)
    b.tube(Vector3(0,.04,.4),Vector3(0,.02,3.2),.07,.01,4,back)
    return b.finish()
