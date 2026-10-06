extends RefCounted
## Vector pictograms for the minimap and the big map: a silhouette for every
## species (side view, facing left), the boss crown, the truck and arrows.
## Shapes live in a unit box (-1..1, y down) and are drawn as polygons, so they
## stay crisp at any size. Preloaded by path, like the other UI helpers.

const PASSIVE:=Color("4f9a5c")
const AGGRESSIVE:=Color("d0602f")
const BOSS:=Color("e3a526")
const GOLD:=Color("ffd25a")
const GOLD_DARK:=Color("8a5a0c")
const PARTY:=Color("5fb4ff")
const SELF:=Color("fff1c9")
const INK:=Color(0.06,0.07,0.06,0.9)

static func ellipse(center: Vector2, radii: Vector2, angle: float=0.0, segments: int=16) -> PackedVector2Array:
    var points:=PackedVector2Array()
    for i in segments:
        var t: float=TAU*float(i)/float(segments)
        points.append(center+Vector2(cos(t)*radii.x,sin(t)*radii.y).rotated(angle))
    return points

static func _place(points: PackedVector2Array, at: Vector2, size: float) -> PackedVector2Array:
    var placed:=PackedVector2Array()
    for point in points: placed.append(at+point*size*.5)
    return placed

static func _fill(canvas: CanvasItem, points: PackedVector2Array, at: Vector2, size: float, color: Color) -> void:
    canvas.draw_colored_polygon(_place(points,at,size),color)

static func _blob(canvas: CanvasItem, center: Vector2, radii: Vector2, at: Vector2, size: float, color: Color, angle: float=0.0) -> void:
    _fill(canvas,ellipse(center,radii,angle),at,size,color)

static func _line(canvas: CanvasItem, points: Array, width: float, at: Vector2, size: float, color: Color) -> void:
    var placed:=PackedVector2Array()
    for point in points: placed.append(at+Vector2(point)*size*.5)
    canvas.draw_polyline(placed,color,maxf(1.0,width*size*.5),true)

## A white silhouette of `kind` centred on `at`, `size` pixels across.
static func draw_species(canvas: CanvasItem, kind: StringName, at: Vector2, size: float, color: Color=Color.WHITE, accent: Color=INK) -> void:
    match kind:
        &"rabbit":
            _blob(canvas,Vector2(.15,.28),Vector2(.52,.4),at,size,color)
            _blob(canvas,Vector2(-.42,-.02),Vector2(.28,.25),at,size,color)
            _blob(canvas,Vector2(-.38,-.5),Vector2(.11,.36),at,size,color,-.25)
            _blob(canvas,Vector2(-.18,-.46),Vector2(.1,.33),at,size,color,.15)
            _blob(canvas,Vector2(.7,.12),Vector2(.15,.15),at,size,color)
            _blob(canvas,Vector2(.2,.66),Vector2(.42,.1),at,size,color)
            canvas.draw_circle(at+Vector2(-.5,-.06)*size*.5,maxf(.8,size*.035),accent)
        &"deer":
            _blob(canvas,Vector2(.2,.06),Vector2(.52,.26),at,size,color)
            _line(canvas,[Vector2(-.2,-.02),Vector2(-.46,-.42)],.24,at,size,color)
            _blob(canvas,Vector2(-.56,-.45),Vector2(.2,.12),at,size,color,.35)
            for x in [-.18,-.02,.44,.6]: _line(canvas,[Vector2(x,.2),Vector2(x+(.04 if x<0 else -.02),.9)],.09,at,size,color)
            _line(canvas,[Vector2(-.48,-.56),Vector2(-.4,-.82),Vector2(-.26,-.98)],.07,at,size,color)
            _line(canvas,[Vector2(-.42,-.76),Vector2(-.58,-.96)],.06,at,size,color)
            _line(canvas,[Vector2(-.6,-.55),Vector2(-.72,-.8),Vector2(-.88,-.9)],.07,at,size,color)
            _blob(canvas,Vector2(.72,-.04),Vector2(.08,.06),at,size,color)
        &"boar":
            _blob(canvas,Vector2(.14,.14),Vector2(.6,.4),at,size,color)
            _blob(canvas,Vector2(-.12,-.1),Vector2(.36,.3),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(-.42,-.25),Vector2(-.9,.04),Vector2(-.92,.24),Vector2(-.42,.38)]),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(-.4,-.24),Vector2(-.3,-.58),Vector2(-.18,-.22)]),at,size,color)
            for x in [-.3,-.08,.4,.6]: _line(canvas,[Vector2(x,.4),Vector2(x,.86)],.15,at,size,color)
            _line(canvas,[Vector2(-.74,.26),Vector2(-.82,.08),Vector2(-.7,-.04)],.07,at,size,accent)
            _line(canvas,[Vector2(.72,.0),Vector2(.86,.12)],.06,at,size,color)
        &"wolf":
            _blob(canvas,Vector2(.14,.1),Vector2(.52,.25),at,size,color)
            _blob(canvas,Vector2(-.28,.06),Vector2(.3,.3),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(-.42,-.28),Vector2(-.6,-.64),Vector2(-.66,-.36),Vector2(-.96,-.2),Vector2(-.92,-.06),Vector2(-.52,.04)]),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(-.48,-.3),Vector2(-.46,-.64),Vector2(-.36,-.3)]),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(.58,-.02),Vector2(.96,.2),Vector2(.9,.38),Vector2(.6,.18)]),at,size,color)
            for x in [-.32,-.14,.38,.54]: _line(canvas,[Vector2(x,.2),Vector2(x,.88)],.09,at,size,color)
            canvas.draw_circle(at+Vector2(-.66,-.22)*size*.5,maxf(.8,size*.03),accent)
        &"bear", &"ancient_bear":
            _blob(canvas,Vector2(.16,.14),Vector2(.66,.44),at,size,color)
            _blob(canvas,Vector2(-.16,-.08),Vector2(.4,.36),at,size,color)
            _blob(canvas,Vector2(-.6,.0),Vector2(.3,.26),at,size,color)
            _blob(canvas,Vector2(-.88,.08),Vector2(.14,.12),at,size,color)
            _blob(canvas,Vector2(-.54,-.26),Vector2(.1,.1),at,size,color)
            for x in [-.34,-.08,.44,.66]: _line(canvas,[Vector2(x,.4),Vector2(x,.88)],.2,at,size,color)
            canvas.draw_circle(at+Vector2(-.66,-.06)*size*.5,maxf(.8,size*.03),accent)
            if kind==&"ancient_bear":
                # Little firs on its back.
                for x in [-.2,.15,.45]:
                    _fill(canvas,PackedVector2Array([Vector2(x-.13,-.3),Vector2(x,-.72),Vector2(x+.13,-.3)]),at,size,Color("3f7a46"))
        &"frog":
            _blob(canvas,Vector2(0,.28),Vector2(.72,.44),at,size,color)
            _blob(canvas,Vector2(0,-.02),Vector2(.55,.3),at,size,color)
            _blob(canvas,Vector2(-.38,-.22),Vector2(.22,.22),at,size,color)
            _blob(canvas,Vector2(.38,-.22),Vector2(.22,.22),at,size,color)
            _blob(canvas,Vector2(-.74,.6),Vector2(.28,.13),at,size,color,.3)
            _blob(canvas,Vector2(.74,.6),Vector2(.28,.13),at,size,color,-.3)
            for x in [-.38,.38]: canvas.draw_circle(at+Vector2(x,-.22)*size*.5,maxf(.8,size*.05),accent)
        &"turtle":
            var shell:=PackedVector2Array()
            for i in 13:
                var angle: float=PI+PI*float(i)/12.0
                shell.append(Vector2(cos(angle)*.66,.28+sin(angle)*.62))
            _fill(canvas,shell,at,size,color)
            _blob(canvas,Vector2(-.82,.2),Vector2(.18,.14),at,size,color)
            _blob(canvas,Vector2(-.4,.42),Vector2(.13,.12),at,size,color)
            _blob(canvas,Vector2(.42,.42),Vector2(.13,.12),at,size,color)
            _line(canvas,[Vector2(-.3,-.05),Vector2(0,-.2),Vector2(.3,-.05)],.05,at,size,accent)
            _line(canvas,[Vector2(0,-.2),Vector2(0,.24)],.05,at,size,accent)
        &"snake":
            var body: Array=[]
            for i in 15:
                var t: float=float(i)/14.0
                body.append(Vector2(.86-1.56*t,.3*sin(t*TAU*1.25)*(1.0-.25*t)+.1))
            _line(canvas,body,.2,at,size,color)
            _blob(canvas,Vector2(-.76,.12),Vector2(.17,.13),at,size,color)
            _line(canvas,[Vector2(-.92,.14),Vector2(-1.0,.1)],.04,at,size,Color("e04848"))
        &"crocodile", &"ancient_crocodile", &"albino_crocodile":
            _blob(canvas,Vector2(.0,.12),Vector2(.6,.2),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(-.48,.0),Vector2(-.98,.08),Vector2(-.98,.2),Vector2(-.48,.26)]),at,size,color)
            _fill(canvas,PackedVector2Array([Vector2(.5,.0),Vector2(.99,.14),Vector2(.5,.26)]),at,size,color)
            _blob(canvas,Vector2(-.5,-.02),Vector2(.08,.07),at,size,color)
            for x in [-.3,.3]: _line(canvas,[Vector2(x,.26),Vector2(x+(-.06 if x<0 else .06),.44)],.09,at,size,color)
            for k in 5:
                var x: float=-.3+k*.18
                _fill(canvas,PackedVector2Array([Vector2(x-.05,-.04),Vector2(x,-.14),Vector2(x+.05,-.04)]),at,size,color)
            canvas.draw_circle(at+Vector2(-.5,-.04)*size*.5,maxf(.8,size*.025),Color("ff3048") if kind==&"albino_crocodile" else accent)
        _:
            _blob(canvas,Vector2(0,.28),Vector2(.38,.3),at,size,color)
            for toe in [Vector2(-.42,-.12),Vector2(-.15,-.38),Vector2(.15,-.38),Vector2(.42,-.12)]:
                _blob(canvas,toe,Vector2(.14,.17),at,size,color)

## A round badge with a species silhouette, as on the big map.
static func draw_badge(canvas: CanvasItem, definition, at: Vector2, radius: float, dead: bool=false) -> void:
    var fill: Color=BOSS if definition.boss else AGGRESSIVE if definition.aggressive else PASSIVE
    if dead: fill=Color(0.45,0.45,0.45)
    canvas.draw_circle(at+Vector2(0,radius*.12),radius+1.5,Color(0,0,0,.35))
    canvas.draw_circle(at,radius+1.5,Color(1,1,1,.9))
    canvas.draw_circle(at,radius,fill)
    draw_species(canvas,definition.id,at,radius*1.55,Color(1,1,1,.96) if not dead else Color(.85,.85,.85),fill.darkened(.55))
    if dead:
        canvas.draw_line(at+Vector2(-.5,-.5)*radius,at+Vector2(.5,.5)*radius,Color(1,1,1,.8),1.6,true)
    if definition.boss and not dead: draw_crown(canvas,at-Vector2(0,radius+radius*.55),radius*1.25)

## The boss crown: gold, three points, little jewels.
static func draw_crown(canvas: CanvasItem, at: Vector2, width: float) -> void:
    var shape:=PackedVector2Array([Vector2(-1,.5),Vector2(-1,-.32),Vector2(-.52,.08),Vector2(0,-.62),Vector2(.52,.08),Vector2(1,-.32),Vector2(1,.5)])
    var placed: PackedVector2Array=_place(shape,at,width)
    var shadow:=PackedVector2Array()
    for point in placed: shadow.append(point+Vector2(0,1.2))
    canvas.draw_colored_polygon(shadow,Color(0,0,0,.45))
    canvas.draw_colored_polygon(placed,GOLD)
    var outline: PackedVector2Array=placed.duplicate();outline.append(placed[0])
    canvas.draw_polyline(outline,GOLD_DARK,maxf(1.0,width*.07),true)
    for point in [Vector2(-1,-.32),Vector2(0,-.62),Vector2(1,-.32)]:
        canvas.draw_circle(at+point*width*.5,maxf(1.0,width*.09),Color("ff4a5e") if point.x==0 else Color("5fd0ff"))
    canvas.draw_rect(Rect2(at+Vector2(-.9,.28)*width*.5,Vector2(1.8,.18)*width*.5),GOLD_DARK)

## An arrow pointing up when `turn` is 0 (clockwise radians on screen).
static func draw_arrow(canvas: CanvasItem, at: Vector2, size: float, turn: float, color: Color, outline: Color=Color(0,0,0,.6)) -> void:
    var shape:=PackedVector2Array([Vector2(0,-1),Vector2(.72,.78),Vector2(0,.38),Vector2(-.72,.78)])
    var points:=PackedVector2Array()
    for point in shape: points.append(at+point.rotated(turn)*size*.5)
    var ring: PackedVector2Array=points.duplicate();ring.append(points[0])
    canvas.draw_polyline(ring,outline,maxf(2.0,size*.16),true)
    canvas.draw_colored_polygon(points,color)

## The truck from above, pointing up when `turn` is 0: green cab, log trailer.
static func draw_truck(canvas: CanvasItem, at: Vector2, size: float, turn: float) -> void:
    canvas.draw_set_transform(at,turn,Vector2.ONE*size*.5)
    canvas.draw_rect(Rect2(-.5,-1.08,1.0,2.16),Color(0,0,0,.55))
    canvas.draw_rect(Rect2(-.42,-.3,.84,1.3),Color("8a5a33"))
    for y in [-.05,.3,.65]: canvas.draw_rect(Rect2(-.42,y,.84,.06),Color("5a3a20"))
    canvas.draw_rect(Rect2(-.36,-1.0,.72,.62),Color("4f8a55"))
    canvas.draw_rect(Rect2(-.28,-.92,.56,.22),Color("cfe8ff"))
    canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
