extends RefCounted
## Drawing helpers shared by the HUD and the maps: soft rounded panels, pills,
## key caps, outlined text and small vector icons (heart, coin, backpack...).
## Everything is drawn in code so the HUD stays light, round and resolution-free.

const PANEL:=Color(0.05,0.07,0.065,0.62)
const PANEL_SOLID:=Color(0.05,0.07,0.065,0.86)
const TEXT:=Color(0.96,0.94,0.88)
const MUTED:=Color(0.78,0.8,0.72,0.82)
const ACCENT:=Color("f2b84b")
const HEALTH:=Color("6fd36b")
const DANGER:=Color("ff5a4a")
const COIN:=Color("ffc94a")

static var _styles: Dictionary={}

static func font() -> Font:
    return ThemeDB.fallback_font

## A rounded panel with a soft drop shadow (cached per look).
static func panel(canvas: CanvasItem, rect: Rect2, color: Color=PANEL, radius: float=10.0, border: Color=Color(0,0,0,0), shadow: bool=true) -> void:
    var key: String="%s|%s|%s|%s" % [color.to_html(),radius,border.to_html(),shadow]
    if not _styles.has(key):
        var style:=StyleBoxFlat.new()
        style.bg_color=color
        style.set_corner_radius_all(int(radius))
        style.corner_detail=10
        style.anti_aliasing=true
        if border.a>0.0:
            style.border_color=border
            style.set_border_width_all(1)
        if shadow:
            style.shadow_color=Color(0,0,0,0.28)
            style.shadow_size=6
            style.shadow_offset=Vector2(0,2)
        _styles[key]=style
    canvas.draw_style_box(_styles[key],rect)

static func text_width(value: String, size: int) -> float:
    return font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x

## The largest font size, down to `smallest`, at which `value` fits in `width`.
static func fit_size(value: String, size: int, width: float, smallest: int=10) -> int:
    var fitted: int=size
    while fitted>smallest and text_width(value,fitted)>width: fitted-=1
    return fitted

## Whole words packed into lines no wider than `width` (a single long word stays whole).
static func wrap(value: String, size: int, width: float) -> PackedStringArray:
    var lines:=PackedStringArray()
    var line: String=""
    for word in value.split(" ",false):
        var longer: String=word if line.is_empty() else line+" "+word
        if line.is_empty() or text_width(longer,size)<=width: line=longer
        else:
            lines.append(line);line=word
    if not line.is_empty(): lines.append(line)
    return lines

## Text with a thin dark outline so it reads over any background.
## `at` is the left end of the baseline unless `align` says otherwise.
static func text(canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color=TEXT, align: int=HORIZONTAL_ALIGNMENT_LEFT, width: float=-1.0, outline: int=4) -> void:
    var f: Font=font()
    if outline>0: canvas.draw_string_outline(f,at,value,align,width,size,outline,Color(0,0,0,color.a*0.55))
    canvas.draw_string(f,at,value,align,width,size,color)

## A rounded key cap, e.g. [E]; returns its width.
static func key_cap(canvas: CanvasItem, center_left: Vector2, key: String, size: int=13, alpha: float=0.94) -> float:
    var w: float=maxf(22.0,text_width(key,size)+12.0)
    var rect:=Rect2(center_left+Vector2(0,-11),Vector2(w,22))
    panel(canvas,rect,Color(0.95,0.93,0.86,snappedf(alpha,.05)),6.0,Color(0,0,0,0),false)
    canvas.draw_rect(Rect2(rect.position+Vector2(2,rect.size.y-3),Vector2(rect.size.x-4,2)),Color(0,0,0,0.18*alpha))
    text(canvas,Vector2(rect.position.x,center_left.y+size*.36),key,size,Color(0.1,0.11,0.1,minf(1.0,alpha*1.06)),HORIZONTAL_ALIGNMENT_CENTER,w,0)
    return w

## A slim rounded bar; `ghost` is the trailing value shown in pale colour.
static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, color: Color, ghost: float=-1.0, back: Color=Color(0,0,0,0.42)) -> void:
    var radius: float=rect.size.y*.5
    panel(canvas,rect,back,radius,Color(0,0,0,0),false)
    if ghost>fraction:
        panel(canvas,Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*clampf(ghost,0,1)),rect.size.y)),Color(1,1,1,0.55),radius,Color(0,0,0,0),false)
    if fraction>0.0:
        panel(canvas,Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*clampf(fraction,0,1)),rect.size.y)),color,radius,Color(0,0,0,0),false)

static func heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
    var r: float=size*.27
    canvas.draw_circle(center+Vector2(-r*.95,-r*.35),r,color)
    canvas.draw_circle(center+Vector2(r*.95,-r*.35),r,color)
    canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-size*.5,-r*.1),center+Vector2(size*.5,-r*.1),center+Vector2(0,size*.48)]),color)

static func coin(canvas: CanvasItem, center: Vector2, size: float) -> void:
    canvas.draw_circle(center,size*.5,Color("b9831f"))
    canvas.draw_circle(center+Vector2(0,-size*.04),size*.42,COIN)
    canvas.draw_arc(center+Vector2(0,-size*.04),size*.27,0,TAU,16,Color("b9831f"),maxf(1.0,size*.08),true)

static func backpack(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
    var body:=Rect2(center+Vector2(-size*.36,-size*.3),Vector2(size*.72,size*.78))
    panel(canvas,body,color,size*.2,Color(0,0,0,0),false)
    canvas.draw_arc(center+Vector2(0,-size*.3),size*.2,PI,TAU,10,color,maxf(1.5,size*.11),true)
    canvas.draw_rect(Rect2(center+Vector2(-size*.22,size*.04),Vector2(size*.44,size*.2)),Color(0,0,0,0.25))

static func steering_wheel(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
    canvas.draw_arc(center,size*.42,0,TAU,20,color,maxf(1.5,size*.12),true)
    for angle in [PI*.5,PI*1.17,PI*1.83]: canvas.draw_line(center,center+Vector2.from_angle(angle)*size*.4,color,maxf(1.2,size*.1),true)
    canvas.draw_circle(center,size*.12,color)

static func skull(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
    canvas.draw_circle(center+Vector2(0,-size*.08),size*.38,color)
    canvas.draw_rect(Rect2(center+Vector2(-size*.22,size*.12),Vector2(size*.44,size*.28)),color)
    for x in [-1.0,1.0]: canvas.draw_circle(center+Vector2(x*size*.15,-size*.08),size*.1,Color(0,0,0,0.75))
