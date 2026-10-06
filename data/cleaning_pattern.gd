class_name CleaningPattern
extends RefCounted
## The camp hide cleaner. A drum tumbles the raw hide and flings off what is still
## stuck to it — flesh, fat, burrs, sinew — in high arcs. Slice the junk out of
## the air before it lands back on the hide, but leave the stones in the drum
## and the hide itself alone when it flops up. Fruit Ninja with a tanning drum.
##
## Like HarvestPattern everything here is pure and seeded: the host judges blade
## samples against these arcs and every client redraws the very same session.

const JUNK_FLESH: int = 0
const JUNK_FAT: int = 1
const JUNK_BURR: int = 2
const JUNK_SINEW: int = 3
const STONE: int = 4
const PELT: int = 5
## Normalised board units per second squared, y pointing down.
const GRAVITY: float = 2.4
const LAUNCH_Y: float = 1.06
## A slice needs a real flick; a slow drag only hovers over the junk.
const MIN_SPEED: float = .8
## Hit radius per kind, in metric board units (see HarvestPattern.metric).
const RADIUS: Dictionary = {JUNK_FLESH:.055,JUNK_FAT:.06,JUNK_BURR:.045,JUNK_SINEW:.05,STONE:.045,PELT:.13}
## The host also tests where each piece was this long ago, so a client that
## sees the arcs a little late still hits what was under its knife.
const LAG_PROBES: Array = [0.0,.06,.12,.18]
## Dirt points: junk that lands back on the hide, a chipped blade, a cut hide.
const DIRT_MISSED: int = 1
const DIRT_STONE: int = 1
const DIRT_PELT: int = 2

static func is_junk(kind: int) -> bool:
    return kind<=JUNK_SINEW

## The whole session's launch schedule. Harder animals bring more junk, faster
## volleys, tougher sinew, more stones and the hide flopping up more often;
## fatty animals (boar, bear) throw off mostly fat.
static func pieces(seed_value: int, difficulty: float, fatty: bool) -> Array:
    var rng:=RandomNumberGenerator.new()
    rng.seed=absi(seed_value)*104729+11
    var junk_total: int=int(round(lerpf(10.0,28.0,difficulty)))
    var result: Array=[]
    var time: float=1.2
    var junk: int=0
    var volley: int=0
    while junk<junk_total:
        var progress: float=float(junk)/float(junk_total)
        var size: int=mini(junk_total-junk,1+rng.randi_range(0,1+int(round(difficulty*2.0+progress))))
        for i in size:
            var roll: float=rng.randf()
            var kind: int=[JUNK_FLESH,JUNK_FAT,JUNK_BURR][rng.randi_range(0,2)]
            if fatty and roll<.4: kind=JUNK_FAT
            elif difficulty>=.45 and roll>.8: kind=JUNK_SINEW
            result.append(_launch(rng,time+float(i)*.14,kind))
            junk+=1
        if rng.randf()<lerpf(.15,.4,difficulty): result.append(_launch(rng,time+rng.randf_range(0.0,.35),STONE))
        volley+=1
        if volley%4==2 and difficulty>=.25: result.append(_launch(rng,time+.25,PELT))
        time+=lerpf(lerpf(1.3,.9,difficulty),lerpf(1.0,.62,difficulty),progress)
    return result

static func _launch(rng: RandomNumberGenerator, at: float, kind: int) -> Dictionary:
    var x: float=rng.randf_range(.18,.82)
    var apex: float=rng.randf_range(.32,.5) if kind==PELT else rng.randf_range(.12,.42)
    var lift: float=sqrt(2.0*GRAVITY*(LAUNCH_Y-apex))
    var landing: float=clampf(x+rng.randf_range(-.35,.35),.1,.9)
    return {"t":at,"x":x,"vx":(landing-x)/(2.0*lift/GRAVITY),"vy":lift,"kind":kind,"spin":rng.randf_range(-6.0,6.0)}

static func flight(piece: Dictionary) -> float:
    return 2.0*float(piece.vy)/GRAVITY

static func position(piece: Dictionary, time: float) -> Vector2:
    var t: float=time-float(piece.t)
    return Vector2(float(piece.x)+float(piece.vx)*t,LAUNCH_Y-float(piece.vy)*t+.5*GRAVITY*t*t)

static func airborne(piece: Dictionary, time: float) -> bool:
    var t: float=time-float(piece.t)
    return t>=0.0 and t<=flight(piece)

static func landed(piece: Dictionary, time: float) -> bool:
    return time-float(piece.t)>flight(piece)

static func duration(all: Array) -> float:
    var last: float=0.0
    for piece in all: last=maxf(last,float(piece.t)+flight(piece))
    return last+.5

static func junk_count(all: Array) -> int:
    var count: int=0
    for piece in all: count+=1 if is_junk(int(piece.kind)) else 0
    return count

static func cleanliness(dirt: int, junk: int) -> float:
    return clampf(1.0-float(dirt)/maxf(1.0,float(junk)),0.0,1.0)

## Stars a raw hide loses in the cleaner. Clean work keeps every field star.
static func star_penalty(clean: float) -> int:
    return 0 if clean>=.85 else 1 if clean>=.6 else 2

static func final_stars(raw_stars: int, clean: float) -> int:
    return clampi(raw_stars-star_penalty(clean),1,5)
