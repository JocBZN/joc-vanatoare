extends RefCounted
## Plays the knife mini-games for tests and previews, through the real host API.
##
## Planning is pure: it reads the replicated state and returns blade samples
## (with the sender clock step that sets their speed) or a request to let time
## pass. Callers deliver them through whatever path they exercise:
## _accept_input, the network, or the host functions directly.
##
## Field modes: "perfect" hits every seam centre, "sloppy" cuts near the seam
## ends, "ruin" snags every seam thirty times first.
## Cleaner modes: "perfect" slices every piece of junk and dodges stones and the
## hide, "lazy" lets everything fall, "reckless" slices stones and the hide too.

const HOVER_MS: int=300
const FLICK_MS: int=12
const HOVER_STEP: float=.04
const FLICK_REACH: float=.07

static func quirks(state: Dictionary) -> PackedStringArray:
    return PackedStringArray(state.get("quirks",PackedStringArray()))

## Spasms and the jaw are timed hazards; a careful player simply waits them out.
static func unsafe(state: Dictionary) -> bool:
    var id: int=int(state.id)
    var time: float=float(state.get("move_time",0))
    var q: PackedStringArray=quirks(state)
    for probe in [0.0,.2]:
        if q.has("twitch") and HarvestPattern.spasm(id,time+probe,float(state.twitch_period))>0: return true
        if q.has("chomp") and HarvestPattern.jaw_state(id,time+probe,float(state.jaw_period))>0: return true
    return false

static func hover(from: Vector2, to: Vector2) -> Array:
    var ops: Array=[]
    var steps: int=maxi(1,int(ceil(HarvestPattern.metric(from).distance_to(HarvestPattern.metric(to))/HOVER_STEP)))
    for i in range(1,steps+1): ops.append({"kind":"blade","p":from.lerp(to,float(i)/float(steps)),"dt":HOVER_MS})
    return ops

static func _norm(point: Vector2) -> Vector2:
    return Vector2(point.x/HarvestPattern.ASPECT,point.y)

static func _wait(blade: Vector2) -> Array:
    # Park the knife in the middle of the board, clear of any jaw, then wait.
    var ops: Array=hover(blade,Vector2(.5,.5)) if blade.distance_to(Vector2(.5,.5))>.01 else []
    ops.append({"kind":"wait"})
    return ops

# ------------------------------------------------------------------ field ---

## Ops for one seam of the current slash wave.
static func next_ops(state: Dictionary, blade: Vector2, mode: String="perfect") -> Array:
    if not bool(state.get("active",false)): return []
    if unsafe(state): return _wait(blade)
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
    return _wait(blade)

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

# ---------------------------------------------------------------- cleaner ---

## Ops for one slice at the camp cleaner, or a short wait for the next volley.
static func clean_ops(state: Dictionary, blade: Vector2, mode: String="perfect") -> Array:
    if not bool(state.get("active",false)): return []
    if mode=="lazy": return [{"kind":"wait"}]
    var all: Array=CleaningPattern.pieces(int(state.seed),float(state.difficulty),bool(state.fatty))
    var time: float=float(state.time)
    var done: int=int(state.done)
    for index in all.size():
        var piece: Dictionary=all[index]
        if done&(1<<index) or not CleaningPattern.airborne(piece,time): continue
        var kind: int=int(piece.kind)
        if CleaningPattern.is_junk(kind)==(mode=="reckless"): continue
        # Only slice what is well inside the board and not about to land.
        var at: Vector2=CleaningPattern.position(piece,time)
        if at.y>.8 or at.x<.05 or at.x>.95 or float(piece.t)+CleaningPattern.flight(piece)-time<.05: continue
        var centre: Vector2=HarvestPattern.metric(at)
        for turn in 8:
            var direction:=Vector2.from_angle(float(turn)*PI/8.0)
            var start: Vector2=centre-direction*.09
            var finish: Vector2=centre+direction*.09
            if mode=="perfect" and not _clear_of_hazards(all,done,time,start,finish): continue
            var ops: Array=hover(blade,_norm(start))
            ops.append({"kind":"blade","p":_norm(finish),"dt":FLICK_MS})
            return ops
    return [{"kind":"wait"}]

static func _clear_of_hazards(all: Array, done: int, time: float, a: Vector2, b: Vector2) -> bool:
    for index in all.size():
        var piece: Dictionary=all[index]
        if done&(1<<index) or CleaningPattern.is_junk(int(piece.kind)): continue
        for probe in CleaningPattern.LAG_PROBES:
            var t: float=time-float(probe)
            if not CleaningPattern.airborne(piece,t): continue
            var reach: float=float(CleaningPattern.RADIUS[int(piece.kind)])+.04
            if HarvestPattern.segment_distance(a,b,HarvestPattern.metric(CleaningPattern.position(piece,t)))<=reach: return false
    return true

# ---------------------------------------------------------------- running ---

## Plays one field wave (or, with `cleaning`, one whole cleaner session) to the
## end. `blade_sink(point, stamp)` delivers a sample, `wait_sink(seconds)`
## advances host time and `read()` returns the latest state.
static func play_step(read: Callable, blade_sink: Callable, wait_sink: Callable, clock: Dictionary, mode: String="perfect", cleaning: bool=false) -> void:
    var state: Dictionary=read.call()
    if not bool(state.get("active",false)): return
    var round_index: int=int(state.get("round",0))
    if int(clock.get("token",-1))!=int(state.token):
        # A fresh job starts from wherever the host last saw this hunter's blade.
        clock.token=int(state.token);clock.blade=Vector2(state.get("blade",Vector2(.5,.5)))
    for attempt in 4000:
        state=read.call()
        if not bool(state.get("active",false)) or int(state.get("round",0))!=round_index: return
        var plan: Array=clean_ops(state,Vector2(clock.blade),mode) if cleaning else next_ops(state,Vector2(clock.blade),mode)
        for op in plan:
            if String(op.kind)=="wait": wait_sink.call(.05 if cleaning else .1)
            else:
                clock.stamp=int(clock.get("stamp",1000))+int(op.dt)
                clock.blade=op.p
                blade_sink.call(op.p,int(clock.stamp))
            var now: Dictionary=read.call()
            if not bool(now.get("active",false)) or int(now.get("round",0))!=round_index: return
