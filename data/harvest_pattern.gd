class_name HarvestPattern
extends RefCounted
## Deterministic skinning "moves" shared by host and clients.
##
## Skinning is a short arcade routine instead of one long held drag:
##   SLASH  — flick the knife across stitched seams, Fruit-Ninja style.
##   SCRAPE — scrub fat blobs off the hide against a clock.
##   YANK   — click the flap, stretch it like a slingshot, click to let it fly.
## Every species adds its own twist (quirk): ticks, bees, spasms, a snapping jaw…
##
## The host judges every blade sample against this geometry and the client only
## redraws it, so both sides must derive identical shapes from the same seed.
## Every function here is pure: seeded generators and explicit time only.

const MOVE_SLASH: int = 0
const MOVE_SCRAPE: int = 1
const MOVE_YANK: int = 2
## Hide space is normalised 0..1 on both axes, but distances, speeds and
## crossings are measured in metric space where the hide is ASPECT wide and 1
## tall, so a diagonal swipe means the same on screen, on the host and in 3D.
const ASPECT: float = 1.75
## Below this blade speed (metric units per second) the knife only hovers: it can
## be repositioned over seams, ticks and bees without touching anything.
const HOVER_SPEED: float = .45
## Successful cuts closer together than this keep the combo counter running.
const COMBO_WINDOW: float = .8
const YANK_REACH: float = .40
const YANK_SWEET: float = .70
const YANK_RIP: float = 1.2
const GRAB_RADIUS: float = .11
## Fat health removed per metric unit of blade travel over a blob.
const SCRAPE_RATE: float = 1.5
const HAZARD_RADIUS: float = .05
const JAW_EDGE: float = .24
const SPASM_SECONDS: float = .55
const SPASM_WARNING: float = .70
const CHOMP_SECONDS: float = .30
const CHOMP_WARNING: float = .80

static func metric(point: Vector2) -> Vector2:
    return Vector2(point.x*ASPECT,point.y)

static func total_steps(strokes: int) -> int:
    return maxi(3,clampi(strokes,2,16))

## Splits a species' workload into slash waves, fat scrapes and closing yanks.
## Bigger animals gain steps in every move they use, never just one.
static func plan(strokes: int, quirks: PackedStringArray = PackedStringArray()) -> Array:
    var total: int=total_steps(strokes)
    var yanks: int=1 if total<=4 else 2 if total<=10 else 3
    var scrapes: int=0
    if quirks.has("fat"): scrapes=1 if total<=8 else 2
    return [maxi(1,total-yanks-scrapes),scrapes,yanks]

static func move_of(completed: int, strokes: int, quirks: PackedStringArray = PackedStringArray()) -> int:
    var split: Array=plan(strokes,quirks)
    if completed<int(split[0]): return MOVE_SLASH
    if completed<int(split[0])+int(split[1]): return MOVE_SCRAPE
    return MOVE_YANK

static func moves_of(move: int, strokes: int, quirks: PackedStringArray = PackedStringArray()) -> int:
    return int(plan(strokes,quirks)[clampi(move,0,2)])

## Control points come from a generator seeded by body, move and global step,
## so a resumed corpse rebuilds exactly what the previous hunter was working on.
static func _rng(seed_value: int, move: int, step: int) -> RandomNumberGenerator:
    var rng:=RandomNumberGenerator.new()
    rng.seed=absi(seed_value)*7919+move*131+step*17+3
    return rng

static func jaw_side(seed_value: int) -> int:
    return -1 if absi(seed_value)%2==0 else 1

## Seams of one slash wave in their rest pose: centre (normalised), angle, and
## the side they must be crossed from. With a jaw, the first seam is always
## planted inside the bite zone so the player has to time it.
static func seams(seed_value: int, step: int, count: int, length: float, jaw: int = 0) -> Array:
    var rng:=_rng(seed_value,MOVE_SLASH,step)
    var result: Array=[]
    var tries: int=0
    while result.size()<count and tries<120:
        tries+=1
        var centre:=Vector2(rng.randf_range(.17,.83),rng.randf_range(.22,.78))
        var angle: float=rng.randf_range(0.0,PI)
        var side: int=1 if rng.randf()<.5 else -1
        if result.is_empty() and jaw!=0: centre.x=.17 if jaw<0 else .83
        var clear: bool=true
        for other in result:
            if metric(centre).distance_to(metric(other.c))<length*1.05: clear=false;break
        if clear: result.append({"c":centre,"a":angle,"dir":side})
    return result

## Live offset of a seam: frogs slide around, snakes still wiggle.
static func drift(quirks: PackedStringArray, seed_value: int, time: float, centre: Vector2) -> Vector2:
    var offset:=Vector2.ZERO
    var phase: float=float(absi(seed_value)%97)*.37
    if quirks.has("slippery"): offset+=Vector2(sin(time*.85+phase)*.065,cos(time*1.15+phase)*.07)
    if quirks.has("wiggle"): offset.y+=sin(time*2.3+centre.x*7.0+phase)*.085
    return offset

## Metric endpoints of a seam with its live offset applied.
static func seam_ends(seam: Dictionary, length: float, offset: Vector2) -> Array:
    var centre: Vector2=metric(Vector2(seam.c)+offset)
    var half: Vector2=Vector2(cos(float(seam.a)),sin(float(seam.a)))*length*.5
    return [centre-half,centre+half]

## The side a directional seam has to be crossed towards, in metric space.
static func seam_normal(seam: Dictionary) -> Vector2:
    return Vector2(-sin(float(seam.a)),cos(float(seam.a)))*float(seam.dir)

## Where a blade motion (metric a→b) crosses a seam. Returns [] when it misses,
## otherwise [position along the seam from -1 to 1, 0 being the centre].
static func crossing(a: Vector2, b: Vector2, ends: Array) -> Array:
    var p: Vector2=ends[0]
    var r: Vector2=Vector2(ends[1])-p
    var s: Vector2=b-a
    var denom: float=r.cross(s)
    if absf(denom)<.000001: return []
    var q: Vector2=a-p
    var along: float=q.cross(s)/denom
    var travel: float=q.cross(r)/denom
    if along<0.0 or along>1.0 or travel<0.0 or travel>1.0: return []
    return [along*2.0-1.0]

static func segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
    var span: Vector2=b-a
    var length_sq: float=span.length_squared()
    if length_sq<=.0000001: return a.distance_to(point)
    return point.distance_to(a+span*clampf((point-a).dot(span)/length_sq,0.0,1.0))

## Deer ticks crawl lazily across the hide. Cutting one bursts it.
static func ticks(seed_value: int, step: int, time: float, count: int) -> PackedVector2Array:
    var rng:=_rng(seed_value,40,step)
    var result:=PackedVector2Array()
    for i in count:
        var home:=Vector2(rng.randf_range(.28,.72),rng.randf_range(.3,.7))
        var p1: float=rng.randf_range(0,TAU);var p2: float=rng.randf_range(0,TAU)
        var speed: float=rng.randf_range(.35,.55)
        result.append(home+Vector2(sin(time*speed+p1)*.22,sin(time*speed*1.3+p2)*.2))
    return result

## Bees drawn to the bear's honey-matted fur zip around in figure eights.
static func bees(seed_value: int, step: int, time: float, count: int) -> PackedVector2Array:
    var rng:=_rng(seed_value,41,step)
    var result:=PackedVector2Array()
    for i in count:
        var home:=Vector2(rng.randf_range(.35,.65),rng.randf_range(.38,.62))
        var p1: float=rng.randf_range(0,TAU);var p2: float=rng.randf_range(0,TAU)
        var speed: float=rng.randf_range(1.0,1.45)
        var jitter:=Vector2(sin(time*17.0+p1),cos(time*13.0+p2))*.012
        result.append(home+Vector2(sin(time*speed+p1)*.30,sin(time*speed*2.0+p2)*.24)+jitter)
    return result

## Nerve spasms: 0 calm, 1 warning, 2 the corpse is kicking.
static func spasm(seed_value: int, time: float, period: float) -> int:
    var phase: float=fposmod(time+float(absi(seed_value)%13)*.31,maxf(1.5,period))
    if phase>period-SPASM_SECONDS: return 2
    if phase>period-SPASM_SECONDS-SPASM_WARNING: return 1
    return 0

## Crocodile reflex: 0 resting, 1 jaws opening, 2 SNAP.
static func jaw_state(seed_value: int, time: float, period: float) -> int:
    var phase: float=fposmod(time+float(absi(seed_value)%7)*.41+1.2,maxf(1.5,period))
    if phase>period-CHOMP_SECONDS: return 2
    if phase>period-CHOMP_SECONDS-CHOMP_WARNING: return 1
    return 0

static func jaw_cycle(seed_value: int, time: float, period: float) -> int:
    return int(floor((time+float(absi(seed_value)%7)*.41+1.2)/maxf(1.5,period)))

static func in_jaw(point: Vector2, side: int) -> bool:
    return point.x<JAW_EDGE if side<0 else point.x>1.0-JAW_EDGE

## Fat blobs to scrub off before they set.
static func fat(seed_value: int, step: int, count: int, radius: float) -> PackedVector2Array:
    var rng:=_rng(seed_value,MOVE_SCRAPE,step)
    var result:=PackedVector2Array()
    var tries: int=0
    while result.size()<count and tries<120:
        tries+=1
        var point:=Vector2(rng.randf_range(.16,.84),rng.randf_range(.22,.78))
        var clear: bool=true
        for other in result:
            if metric(point).distance_to(metric(other))<radius*2.3: clear=false;break
        if clear: result.append(point)
    return result

## Where the flap is grabbed and which way it has to be ripped.
static func yank(seed_value: int, step: int) -> Dictionary:
    var rng:=_rng(seed_value,MOVE_YANK,step)
    var ring:=Vector2(rng.randf_range(.40,.60),rng.randf_range(.40,.60))
    var angle: float=float(rng.randi_range(0,7))*PI*.25+rng.randf_range(-.2,.2)
    return {"ring":ring,"dir":Vector2(cos(angle),sin(angle))}

static func yank_tension(grab: Vector2, blade: Vector2, direction: Vector2) -> float:
    return clampf((metric(blade)-metric(grab)).dot(direction)/YANK_REACH,0.0,1.5)

## The hide fights back: heavy animals make the tension wobble around the
## player's hand, so a clean release is a timing call, not just a position.
static func yank_wobble(seed_value: int, time: float, amount: float) -> float:
    var phase: float=float(absi(seed_value)%11)
    return (sin(time*5.3+phase)*.7+sin(time*8.9+phase*.5)*.3)*amount

## Normalised point at a given yank tension along the pull direction.
static func yank_point(ring: Vector2, direction: Vector2, tension: float) -> Vector2:
    var point: Vector2=metric(ring)+direction*YANK_REACH*tension
    return Vector2(point.x/ASPECT,point.y)
