extends Control
## A small dynamic crosshair: four ticks that open up while moving or right
## after a shot, a centre dot, and an X hit marker that flashes on a hit.

var _spread: float=0.0
var _hit: float=0.0
var _kick: float=0.0

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE

func flash() -> void:
    _hit=1.0

func kick() -> void:
    _kick=1.0

func _process(delta: float) -> void:
    var hunter=NetworkSession.local_hunter()
    var moving: float=0.0
    if is_instance_valid(hunter): moving=clampf(Vector2(hunter.velocity.x,hunter.velocity.z).length()/8.5,0.0,1.0)
    var aiming: bool=is_instance_valid(hunter) and hunter.camera_rig.aiming
    var wanted: float=moving*5.0+_kick*6.0-(2.0 if aiming else 0.0)
    _spread=lerpf(_spread,wanted,1.0-exp(-12.0*delta))
    _hit=maxf(0.0,_hit-delta*5.0)
    _kick=maxf(0.0,_kick-delta*5.0)
    if visible: queue_redraw()

func _draw() -> void:
    var gap: float=5.0+_spread
    var length: float=6.0
    var shade:=Color(0,0,0,0.5)
    var color:=Color(1,0.98,0.9,0.95)
    for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
        draw_line(direction*gap,direction*(gap+length),shade,3.4,true)
        draw_line(direction*gap,direction*(gap+length),color,1.6,true)
    draw_circle(Vector2.ZERO,1.9,shade)
    draw_circle(Vector2.ZERO,1.2,color)
    if _hit>0.0:
        var hit_color:=Color(1,0.86,0.4,_hit)
        for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
            var d: Vector2=direction.normalized()
            draw_line(d*(gap+2.0),d*(gap+9.0),Color(0,0,0,_hit*.5),3.6,true)
            draw_line(d*(gap+2.0),d*(gap+9.0),hit_color,2.0,true)
