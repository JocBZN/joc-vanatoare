class_name TruckUpgrades
extends RefCounted
## The Wandering Oak's shared upgrade ladder. The state is one small dictionary
## {id: level} held by the host, paid for by whoever buys, replicated with the
## truck snapshot and applied by HuntingJeep on every peer.
##
## Performance: `speed` and `accel` have three levels each.
## Builds (each one needs the one named in REQUIRES to be fitted first):
##   bar     the Bull Head: a giant iron bull that rams animals
##   tower   the Watchtower with a searchlight, a telescope and a radar dish
##   nitro   the Carrot Rockets
##   boat    the Galleon: the truck unfolds into a big wooden boat the moment it touches water
##           (with an aft deck to shoot the sea from) and opens the ocean map
##   grill   the Hospital Barbecue: everyone aboard heals while it sizzles
##   vacuum  the Loot Hoover: a giant trunk that sucks up loot within reach
##   sphere  the Glass Sphere: a bathysphere under the hull to watch the sea from inside
##   horn    the Shark-Scaring Gramophone: a brass blast that makes animals bolt
##   rotor   the Flying Oak: a helicopter rotor on the tower; hold the key to fly
const ORDER: Array[StringName]=[&"speed",&"accel",&"bar",&"tower",&"nitro",&"boat",&"grill",&"vacuum",&"sphere",&"horn",&"rotor"]
const BUILDS: Array[StringName]=[&"bar",&"tower",&"nitro",&"boat",&"grill",&"vacuum",&"sphere",&"horn",&"rotor"]
const LEVELS: Dictionary={&"speed":3,&"accel":3,&"bar":1,&"tower":1,&"nitro":1,&"boat":1,&"grill":1,&"vacuum":1,&"sphere":1,&"horn":1,&"rotor":1}
const COSTS: Dictionary={
    &"speed":[600,1400,3000],&"accel":[500,1200,2600],
    &"bar":[900],&"tower":[1800],&"nitro":[3200],&"boat":[5500],
    &"grill":[2600],&"vacuum":[3800],&"sphere":[4200],&"horn":[3000],&"rotor":[6500],
}
## Build -> the build that has to be on the truck first.
const REQUIRES: Dictionary={&"tower":&"bar",&"nitro":&"tower",&"boat":&"nitro",&"grill":&"tower",&"vacuum":&"nitro",&"sphere":&"boat",&"horn":&"boat",&"rotor":&"tower"}
## Multipliers per level (index 0 = stock truck).
const SPEED_MULTIPLIER: Array[float]=[1.0,1.16,1.34,1.55]
const ACCEL_MULTIPLIER: Array[float]=[1.0,1.3,1.65,2.1]
## Nitro: seconds of burn on a full tank, seconds to refill it, and the push.
const NITRO_BURN: float=3.2
const NITRO_REFILL: float=9.0
const NITRO_FORCE: float=2.4
const NITRO_SPEED: float=1.45
## Grill: hit points per second for everybody aboard.
const GRILL_HEAL: float=4.0
## Loot hoover: reach in metres, and how often it sweeps.
const VACUUM_RADIUS: float=22.0
const VACUUM_PERIOD: float=.35
## Horn: how far the blast carries, how long animals bolt, and the wait before the next one.
const HORN_RADIUS: float=95.0
const HORN_SCARE: float=8.0
const HORN_COOLDOWN: float=18.0
## Rotor: seconds of lift on a full tank, seconds to refill, lift as a multiple of weight, and the ceiling above ground.
const ROTOR_BURN: float=14.0
const ROTOR_REFILL: float=9.0
const ROTOR_LIFT: float=1.38
const ROTOR_CEILING: float=34.0
## The bull bar: slowest speed that still hurts animals, and damage per m/s.
const BAR_MIN_SPEED: float=5.0
const BAR_DAMAGE_PER_SPEED: float=7.0

## DEBUG: set by the game when it runs with a window, so every upgrade can be tried
## without grinding coins. Headless test runs leave it off and keep exact prices.
static var free_for_testing: bool=false

static func fresh() -> Dictionary:
    var state: Dictionary={}
    for id in ORDER: state[String(id)]=0
    return state

static func level(state: Dictionary,id: StringName) -> int:
    return clampi(int(state.get(String(id),0)),0,int(LEVELS.get(id,0)))

static func max_level(id: StringName) -> int:
    return int(LEVELS.get(id,0))

static func is_valid(id: StringName) -> bool:
    return LEVELS.has(id)

## Price of the next level, or -1 when the upgrade is maxed out.
static func next_cost(state: Dictionary,id: StringName) -> int:
    var current: int=level(state,id)
    if current>=max_level(id): return -1
    if free_for_testing: return 0
    return int(COSTS[id][current])

## "" when the upgrade can be bought, else a localization key for why not.
static func blocker(state: Dictionary,id: StringName) -> String:
    if not is_valid(id): return "TRUCK_UNKNOWN"
    if level(state,id)>=max_level(id): return "TRUCK_MAXED"
    var needed: StringName=StringName(REQUIRES.get(id,&""))
    if needed!=&"" and level(state,needed)<1: return "TRUCK_NEEDS"
    return ""

static func requirement(id: StringName) -> StringName:
    return StringName(REQUIRES.get(id,&""))

static func top_speed_multiplier(state: Dictionary) -> float:
    return SPEED_MULTIPLIER[level(state,&"speed")]

static func engine_multiplier(state: Dictionary) -> float:
    return ACCEL_MULTIPLIER[level(state,&"accel")]

## Keeps only well-formed levels from an untrusted replicated dictionary.
static func sanitize(raw: Dictionary) -> Dictionary:
    var state: Dictionary=fresh()
    for id in ORDER:
        if raw.has(String(id)) and raw[String(id)] is int: state[String(id)]=level(raw,id)
    # A build never stands without the one beneath it.
    for build in BUILDS:
        var needed: StringName=requirement(build)
        if needed!=&"" and level(state,needed)<1: state[String(build)]=0
    return state
