class_name ArcadeKit
extends RefCounted
## Shared bits of the knife mini-games (field skinning and the camp cleaner):
## procedural sounds, outlined text, the blade trail and the knife cursor.
## Everything is synthesised at startup; no audio or texture assets.

## Screen pixels of mouse travel per metric board unit (one board height).
## Deliberately not difficulty-dependent: animals get harder, the hand does not.
const BLADE_PIXELS: float = 330.0
const TRAIL_SECONDS: float = .16

## Moves the virtual blade by a captured-mouse motion, in normalised board space.
static func steer(blade: Vector2, relative: Vector2) -> Vector2:
    return Vector2(clampf(blade.x+relative.x/(BLADE_PIXELS*HarvestPattern.ASPECT),-.1,1.1),
        clampf(blade.y+relative.y/BLADE_PIXELS,-.1,1.1))

static func board_rect(size: Vector2, margin: float=28.0) -> Rect2:
    var room:=Vector2(maxf(60,size.x-margin),maxf(40,size.y-margin))
    var fitted:=Vector2(room.x,room.x/HarvestPattern.ASPECT)
    if fitted.y>room.y: fitted=Vector2(room.y*HarvestPattern.ASPECT,room.y)
    return Rect2((size-fitted)*.5,fitted)

static func text(canvas: CanvasItem, centre: Vector2, value: String, size: int, color: Color) -> void:
    var font: Font=ThemeDB.fallback_font
    var width: float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
    var at: Vector2=centre-Vector2(width*.5,-size*.35)
    canvas.draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,6,Color(0,0,0,color.a*.85))
    canvas.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

## Glowing streak while the knife moves fast enough to cut, faint while hovering.
static func draw_trail(canvas: CanvasItem, trail: Array, to_board: Callable) -> void:
    if trail.size()<2: return
    var now: float=float(Time.get_ticks_msec())/1000.0
    for i in range(1,trail.size()):
        var age: float=clampf((now-float(trail[i].t))/TRAIL_SECONDS,0,1)
        var fast: bool=bool(trail[i].fast)
        var color: Color=Color(1,.97,.85,(1.0-age)*.9) if fast else Color(.85,.9,.8,(1.0-age)*.25)
        canvas.draw_line(to_board.call(trail[i-1].p),to_board.call(trail[i].p),color,(9.0 if fast else 3.0)*(1.0-age)+1.0,true)

static func draw_knife(canvas: CanvasItem, at: Vector2, trail: Array, to_board: Callable, cutting: bool) -> void:
    var heading: Vector2=Vector2(1,-.6).normalized()
    if trail.size()>=2:
        var motion: Vector2=to_board.call(trail[trail.size()-1].p)-to_board.call(trail[0].p)
        if motion.length()>4: heading=motion.normalized()
    var side: Vector2=Vector2(-heading.y,heading.x)
    var steel: Color=Color("fff6dc") if cutting else Color(.9,.92,.88,.8)
    canvas.draw_colored_polygon(PackedVector2Array([at+heading*16,at+side*4,at-heading*4,at-side*1.5]),steel)
    canvas.draw_line(at-heading*4,at-heading*15,Color("4a3526"),5.0,true)

# ------------------------------------------------------------------ sound ---

static func wav() -> AudioStreamWAV:
    var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
    return stream

static func tone(first: float,second: float,duration: float) -> AudioStreamWAV:
    var stream:=wav()
    var bytes:=PackedByteArray()
    for i in int(duration*stream.mix_rate):
        var t: float=float(i)/stream.mix_rate
        var envelope: float=sin(PI*t/duration)*exp(-t*8)
        var sample_value: int=int((sin(TAU*first*t)+sin(TAU*second*t)*.35)*envelope*12000)
        bytes.append(sample_value&255);bytes.append((sample_value>>8)&255)
    stream.data=bytes
    return stream

## Filtered noise burst. `bright` sweeps the filter open for a blade swish.
static func noise(duration: float, smoothing: float, bright: bool) -> AudioStreamWAV:
    var stream:=wav();var count: int=int(duration*stream.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    var rng:=RandomNumberGenerator.new();rng.seed=int(duration*10000)+int(smoothing*100)
    var smooth: float=0;var previous: float=0
    for i in count:
        var t: float=float(i)/float(count)
        var amount: float=lerpf(smoothing,.95,t) if bright else smoothing
        smooth=lerpf(smooth,rng.randf_range(-1,1),amount)
        var value: float=(smooth-previous*.6) if bright else smooth
        previous=smooth
        bytes.encode_s16(i*2,int(clampf(value*sin(PI*t)*(1.0-t*.6)*20000.0,-32000,32000)))
    stream.data=bytes
    return stream

## Pitch slide; `bounce` adds a springy wobble.
static func sweep(start: float, end: float, duration: float, bounce: bool) -> AudioStreamWAV:
    var stream:=wav();var count: int=int(duration*stream.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    var phase: float=0
    for i in count:
        var t: float=float(i)/float(count)
        var frequency: float=lerpf(start,end,t)*(1.0+(.18*sin(t*TAU*7.0)*(1.0-t) if bounce else 0.0))
        phase+=TAU*frequency/stream.mix_rate
        bytes.encode_s16(i*2,int(sin(phase)*exp(-t*3.0)*sin(PI*minf(1.0,t*12.0))*15000.0))
    stream.data=bytes
    return stream

## Two sharp clicks over a thud: jaws snapping shut.
static func chomp() -> AudioStreamWAV:
    var stream:=wav();var count: int=int(.24*stream.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    var rng:=RandomNumberGenerator.new();rng.seed=909
    for i in count:
        var t: float=float(i)/stream.mix_rate
        var click: float=exp(-t*90.0)+exp(-maxf(0,t-.11)*90.0)*float(t>.11)
        var thud: float=sin(TAU*90.0*t)*exp(-t*14.0)
        bytes.encode_s16(i*2,int(clampf((rng.randf_range(-1,1)*click*.8+thud*.7)*22000.0,-32000,32000)))
    stream.data=bytes
    return stream

## A bright metallic ring: steel on stone.
static func clang() -> AudioStreamWAV:
    var stream:=wav();var count: int=int(.35*stream.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    for i in count:
        var t: float=float(i)/stream.mix_rate
        var ring: float=(sin(TAU*1870.0*t)*.5+sin(TAU*2630.0*t)*.3+sin(TAU*3410.0*t)*.2)*exp(-t*11.0)
        bytes.encode_s16(i*2,int(ring*16000.0))
    stream.data=bytes
    return stream

## Seamless loop of filtered noise blended with `hum` (Hz) for machines.
static func loop(seed_value: int, smoothing: float, hum: float, level: float) -> AudioStreamWAV:
    var stream:=wav();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    var length: int=11025
    var bytes:=PackedByteArray();bytes.resize(length*2)
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var smooth: float=0
    for i in length:
        smooth=lerpf(smooth,rng.randf_range(-1,1),smoothing)
        # Whole hum periods per loop, and a cross-fade, keep the seam inaudible.
        var t: float=float(i)/stream.mix_rate
        var blend: float=clampf(float(i)/float(length)*6.0-5.0,0,1)
        var sample: float=lerpf(smooth,smooth*.4,blend)+(sin(TAU*hum*t)*.5 if hum>0 else 0.0)
        bytes.encode_s16(i*2,int(clampf(sample*level,-32000,32000)))
    stream.data=bytes;stream.loop_end=length
    return stream

## A lazy buzz for the bear's bees: a detuned sawtooth pair.
static func buzz() -> AudioStreamWAV:
    var stream:=wav();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    var length: int=22050
    var bytes:=PackedByteArray();bytes.resize(length*2)
    for i in length:
        var t: float=float(i)/stream.mix_rate
        var saw: float=fposmod(t*210.0,1.0)*2.0-1.0
        var other: float=fposmod(t*214.0,1.0)*2.0-1.0
        bytes.encode_s16(i*2,int((saw+other)*.5*(.6+.4*sin(t*TAU*2.0))*5200.0))
    stream.data=bytes;stream.loop_end=length
    return stream
