extends Control
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hide()
func _draw() -> void:
    var center:=size*.5
    var radius: float=minf(size.x,size.y)*.39
    var outside: float=size.length()
    for i in 96:
        var a:=Vector2.from_angle(i*TAU/96.0);var b:=Vector2.from_angle((i+1)*TAU/96.0)
        draw_colored_polygon(PackedVector2Array([center+a*radius,center+a*outside,center+b*outside,center+b*radius]),Color(.012,.016,.013,.99))
    draw_arc(center,radius,0,TAU,96,Color("28332d"),12,true)
    draw_arc(center,radius-8,0,TAU,96,Color(.12,.16,.13,.8),3,true)
    var color:=Color(.06,.08,.06,.96)
    draw_line(center-Vector2(radius-12,0),center+Vector2(radius-12,0),color,1.5,true)
    draw_line(center-Vector2(0,radius-12),center+Vector2(0,radius-12),color,1.5,true)
    for i in [-3,-2,-1,1,2,3]:
        draw_line(center+Vector2(i*32,-5),center+Vector2(i*32,5),color,1,true)
        draw_line(center+Vector2(-5,i*32),center+Vector2(5,i*32),color,1,true)
    draw_circle(center,2,Color("c06545"))
