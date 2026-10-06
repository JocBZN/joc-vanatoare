extends RefCounted
## Plays the skinning routine for tests and previews, through the real host API.
##
## Planning is pure: it reads the replicated harvest state and returns blade
## samples (with the sender clock step that sets their speed), clicks, or a
## request to let time pass. Callers deliver them through whatever path they
## exercise: _accept_input, the network, or the host functions directly.
##
## Modes: "perfect" hits every centre, "sloppy" cuts near the seam ends and
## releases at the edge of the green, "ruin" snags, lets fat set and rips flaps.

const HOVER_MS: int=300
const FLICK_MS: int=12
const HOVER_STEP: float=.04
const FLICK_REACH: float=.07

## Ops for one unit of work on the current move.
static func next_ops(state: Dictionary, blade: Vector2, mode: String="perfect") -> Array:
    if not bool(state.get("active",false)): return []
    match int(state.get("move",0)):
        HarvestPattern.MOVE_SLASH: return _slash(state,blade,mode)
        HarvestPattern.MOVE_SCRAPE: return _scrape(state,blade,mode)
    return _yank(state,blade,mode)

static func quirks(state: Dictionary) -> PackedStringArray:
    return PackedStringArray(state.get("quirks",PackedStringArray()))

## Spasms and the jaw are timed hazards; a careful player simply waits them out.
static func unsafe(state: Dictionary) -> bool:
    var id: int=int(state.id)
    var time: float=float(state.get("move_time",0))
    var q: PackedStringArray=quirks(state)
    for probe in [0.0,.2]:
        if q.has("twitch") and int(state.move)==HarvestPattern.MOVE_SLASH and HarvestPattern.spasm(id,time+probe,float(state.twitch_period))>0: return true
        if q.has("chomp") and int(state.move)!=HarvestPattern.MOVE_YANK and HarvestPattern.jaw_state(id,time+probe,float(state.jaw_period))>0: return true
    return false

static func hover(from: Vector2, to: Vector2) -> Array:
    var ops: Array=[]
    var steps: int=maxi(1,int(ceil(HarvestPattern.metric(from).distance_to(HarvestPattern.metric(to))/HOVER_STEP)))
    for i in range(1,steps+1): ops.append({"kind":"blade","p":from.lerp(to,float(i)/float(steps)),"dt":HOVER_MS})
    return ops

static func _norm(point: Vector2) -> Vector2:
    return Vector2(point.x/HarvestPattern.ASPECT,point.y)

static func _bugs(state: Dictionary) -> PackedVector2Array:
    var q: PackedStringArray=quirks(state)
    var id: int=int(state.id);var step: int=int(state.step);var time: float=float(state.move_time)
    var all: PackedVector2Array=HarvestPattern.ticks(id,step,time,int(state.hazards)) if q.has("ticks") else HarvestPattern.bees(id,step,time,int(state.hazards)) if q.has("bees") else PackedVector2Array()
    var alive:=PackedVector2Array()
    for i in all.size():
        if not int(state.get("dead",0))&(1<<i): alive.append(HarvestPattern.metric(all[i]))
    return alive

static func _clear_of_bugs(state: Dictionary, a: Vector2, b: Vector2, margin: float) -> bool:
    for bug in _bugs(state):
        if HarvestPattern.segment_distance(a,b,bug)<=HarvestPattern.HAZARD_RADIUS+margin: return false
    return true

static func _wait(state: Dictionary, blade: Vector2) -> Array:
    # Park the knife in the middle of the hide, clear of any jaw, then wait.
    var ops: Array=hover(blade,Vector2(.5,.5)) if blade.distance_to(Vector2(.5,.5))>.01 else []
    ops.append({"kind":"wait"})
    return ops

static func _slash(state: Dictionary, blade: Vector2, mode: String) -> Array:
    if unsafe(state): return _wait(state,blade)
    var id: int=int(state.id)
    var q: PackedStringArray=quirks(state)
    var time: float=float(state.move_time)
    var length: float=float(state.seam_length)
    var jaw: int=HarvestPattern.jaw_side(id) if q.has("chomp") else 0
    var seams: Array=HarvestPattern.seams(id,int(state.step),int(state.seams),length,jaw)
    var hp: Array=state.hp
    var all_ends: Array=[]
    for seam in seams: all_ends.append(HarvestPattern.seam_ends(seam,length,HarvestPattern.drift(q,id,time,seam.c)))
    var edge: float=.85 if mode in ["sloppy","ruin"] else 0.0
    for i in seams.size():
        if int(hp[i])<=0: continue
        var ends: Array=all_ends[i]
        var along: Vector2=(Vector2(ends[1])-Vector2(ends[0])).normalized()
        var normal: Vector2=HarvestPattern.seam_normal(seams[i])
        var point: Vector2=(Vector2(ends[0])+Vector2(ends[1]))*.5+along*edge*length*.5
        for reach in [FLICK_REACH,.035]:
            var start: Vector2=point-normal*reach
            var finish: Vector2=point+normal*reach
            var crosses_other: bool=false
            for j in seams.size():
                if j!=i and int(hp[j])>0 and not HarvestPattern.crossing(start,finish,all_ends[j]).is_empty(): crosses_other=true
            if crosses_other or not _clear_of_bugs(state,start,finish,.03): continue
            var ops: Array=hover(blade,_norm(start))
            if mode=="ruin":
                # Dither across the seam just too slowly to cut: every pass snags.
                var slow: float=(HarvestPattern.HOVER_SPEED+float(state.min_speed))*.5
                var snag_ms: int=int(ceil(reach*2.0/slow*1000.0))
                for k in 30: ops.append({"kind":"blade","p":_norm(finish if k%2==0 else start),"dt":snag_ms})
                ops.append({"kind":"blade","p":_norm(start),"dt":HOVER_MS*4})
            ops.append({"kind":"blade","p":_norm(finish),"dt":FLICK_MS})
            return ops
    return _wait(state,blade)

static func _scrape(state: Dictionary, blade: Vector2, mode: String) -> Array:
    if mode=="ruin" or unsafe(state): return _wait(state,blade)
    var radius: float=float(state.fat_radius)
    var blobs: PackedVector2Array=HarvestPattern.fat(int(state.id),int(state.step),int(state.fat_count),radius)
    var health: Array=state.fat
    for i in blobs.size():
        if float(health[i])<=0.0: continue
        var centre: Vector2=HarvestPattern.metric(blobs[i])
        var left: Vector2=centre-Vector2(radius*.7,0);var right: Vector2=centre+Vector2(radius*.7,0)
        if not _clear_of_bugs(state,left,right,.05): continue
        var ops: Array=hover(blade,_norm(left))
        var strokes: int=int(ceil((float(health[i])+.01)/(HarvestPattern.SCRAPE_RATE*left.distance_to(right))))
        for k in strokes: ops.append({"kind":"blade","p":_norm(right if k%2==0 else left),"dt":20})
        return ops
    return _wait(state,blade)

static func _yank(state: Dictionary, blade: Vector2, mode: String) -> Array:
    var id: int=int(state.id)
    var flap: Dictionary=HarvestPattern.yank(id,int(state.step))
    if not bool(state.get("grabbed",false)):
        var ops: Array=hover(blade,flap.ring)
        ops.append({"kind":"click","p":flap.ring})
        return ops
    var width: float=float(state.sweet_width)
    var target: float=HarvestPattern.YANK_SWEET
    if mode=="sloppy": target+=width*.42
    if mode=="ruin": target=HarvestPattern.YANK_RIP+.08
    var wobble: float=float(state.wobble)
    if quirks(state).has("twitch") and HarvestPattern.spasm(id,float(state.move_time),float(state.twitch_period))==2: wobble+=.22
    var raw: float=target-HarvestPattern.yank_wobble(id,float(state.move_time),wobble)
    var point: Vector2=HarvestPattern.yank_point(flap.ring,flap.dir,raw)
    var ops: Array=hover(blade,point)
    ops.append({"kind":"click","p":point})
    return ops

## Plays the current move to completion. `blade_sink(point, stamp)` delivers a
## sample, `click_sink(value)` a click, `wait_sink(seconds)` advances host time
## and `read()` returns the latest state. Stops as soon as the step changes.
static func play_step(read: Callable, blade_sink: Callable, click_sink: Callable, wait_sink: Callable, clock: Dictionary, mode: String="perfect") -> void:
    var state: Dictionary=read.call()
    if not bool(state.get("active",false)): return
    var round_index: int=int(state.round)
    if int(clock.get("token",-1))!=int(state.token):
        # A fresh job starts from wherever the host last saw this hunter's blade.
        clock.token=int(state.token);clock.blade=Vector2(state.get("blade",Vector2(.5,.5)))
    for attempt in 400:
        state=read.call()
        if not bool(state.get("active",false)) or int(state.round)!=round_index: return
        for op in next_ops(state,Vector2(clock.get("blade",Vector2(.5,.5))),mode):
            match String(op.kind):
                "wait": wait_sink.call(.1)
                "blade":
                    clock.stamp=int(clock.get("stamp",1000))+int(op.dt)
                    clock.blade=op.p
                    blade_sink.call(op.p,int(clock.stamp))
                "click":
                    clock.click=maxi(int(clock.get("click",0)),int(state.get("clicks",0)))+1
                    click_sink.call("%d:%d:%d:%.5f:%.5f" % [int(state.id),int(state.token),int(clock.click),Vector2(op.p).x,Vector2(op.p).y])
            var now: Dictionary=read.call()
            if not bool(now.get("active",false)) or int(now.round)!=round_index: return
