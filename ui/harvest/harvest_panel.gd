extends KnifePanel
## Field skinning: flick the knife across stitched seams, Fruit-Ninja style,
## wave after wave until the hide is cut free. Each species brings its own twist
## (ticks, bees, spasms, a snapping jaw, seams that won't sit still). The result
## is a raw hide; it is cleaned back at camp.

const EVENTS: Dictionary={
    "perfect":{"color":Color("ffd65c"),"sound":"perfect","size":30},
    "cut":{"color":Color("e9f5d8"),"sound":"slice","size":24},
    "crack":{"color":Color("ffb35c"),"sound":"crack","size":24},
    "snag":{"color":Color("f0a070"),"sound":"snag","size":22,"bad":true},
    "wrong_way":{"color":Color("ff7a5c"),"sound":"snag","size":22,"bad":true},
    "spasm":{"color":Color("ff5a4a"),"sound":"rip","size":28,"bad":true,"shake":.8},
    "splat":{"color":Color("b6d36a"),"sound":"splat","size":28,"bad":true,"shake":.35},
    "sting":{"color":Color("ffd23a"),"sound":"sting","size":30,"bad":true,"shake":.6},
    "chomp":{"color":Color("ff4a3a"),"sound":"chomp","size":40,"bad":true,"shake":1.0},
    "complete":{"color":Color("ffd65c"),"sound":"complete","size":40},
}

var _fur: PackedVector2Array=PackedVector2Array()
var _fur_kind: String=""
var _swoosh_cooldown: float=0
var _buzz: AudioStreamPlayer

func events() -> Dictionary: return EVENTS
func job_key(data: Dictionary) -> String: return "%s:%s" % [data.get("id",0),data.get("token",0)]
func clock_key(data: Dictionary) -> String: return "%s:%s" % [job_key(data),data.get("step",-1)]
func clock_field() -> String: return "move_time"

func _ready() -> void:
    super._ready()
    name="HarvestPanel"
    _buzz=AudioStreamPlayer.new();_buzz.volume_db=-34;_buzz.stream=ArcadeKit.buzz();add_child(_buzz)

func begin_harvest(id: int, animal_kind: String) -> void:
    begin_pending({"id":id,"animal_kind":animal_kind,"required":0,"completed":0,"stars":5})

func _quirks() -> PackedStringArray:
    return PackedStringArray(state.get("quirks",PackedStringArray()))

func _process(delta: float) -> void:
    super._process(delta)
    _swoosh_cooldown=maxf(0,_swoosh_cooldown-delta)
    if is_interactive() and _speed>=float(state.get("min_speed",1.0)) and _swoosh_cooldown<=0:
        _swoosh_cooldown=.22;_play("swoosh",1.0+randf()*.15)

func update_loops(_delta: float) -> void:
    if not is_instance_valid(_buzz): return
    var buzzing: bool=is_interactive() and _quirks().has("bees")
    if buzzing and not _buzz.playing: _buzz.play()
    elif not buzzing and _buzz.playing: _buzz.stop()

func _kicking() -> int:
    if not is_interactive() or not _quirks().has("twitch"): return 0
    return HarvestPattern.spasm(int(state.get("id",0)),_clock,float(state.get("twitch_period",3)))

func scene_tremble() -> float:
    return 5.0 if _kicking()==2 else 0.0

# ---------------------------------------------------------------- drawing ---

func draw_scene(area: Rect2) -> void:
    var kind: String=String(state.get("animal_kind","rabbit"))
    var coat: Color=COAT_COLORS.get(StringName(kind),Color("86705c"))
    var hide_style:=StyleBoxFlat.new()
    hide_style.bg_color=coat.darkened(.38);hide_style.border_color=coat.lightened(.22)
    hide_style.set_border_width_all(2);hide_style.set_corner_radius_all(18)
    board.draw_style_box(hide_style,area.grow(8))
    _draw_fur(area,kind,coat)
    if not is_interactive(): return
    var id: int=int(state.get("id",0))
    var quirks: PackedStringArray=_quirks()
    if quirks.has("chomp"): _draw_jaw(area,id)
    _draw_seams(id,quirks)
    if quirks.has("ticks"): _draw_bugs(id,true)
    if quirks.has("bees"): _draw_bugs(id,false)
    var kicking: int=_kicking()
    if kicking>0:
        var pulse: float=.5+.5*sin(float(Time.get_ticks_msec())*.03)
        if kicking==2: board.draw_rect(area,Color(1,.2,.1,.18))
        ArcadeKit.text(board,area.position+Vector2(area.size.x*.5,area.size.y*.16),"!!" if kicking==2 else "!",42 if kicking==2 else 30+int(pulse*8),Color(1,.35,.2,.6+.4*pulse))

## Short fur strokes (or scale arcs) so the board reads as an actual pelt.
func _draw_fur(area: Rect2, kind: String, coat: Color) -> void:
    if _fur_kind!=kind or _fur.is_empty():
        _fur_kind=kind;_fur=PackedVector2Array()
        var rng:=RandomNumberGenerator.new();rng.seed=hash(kind)
        for i in 150: _fur.append(Vector2(rng.randf(),rng.randf()))
    var scaly: bool=kind in ["frog","turtle","snake","crocodile","ancient_crocodile"]
    for i in _fur.size():
        var p: Vector2=_to_board(_fur[i])
        var shade: Color=coat.lightened(.12) if i%2==0 else coat.darkened(.55)
        shade.a=.28
        if scaly: board.draw_arc(p,area.size.y*.035,0,PI,6,shade,1.5)
        else: board.draw_line(p,p+Vector2(7,3+sin(float(i))*3),shade,1.5,true)

func _draw_seams(id: int, quirks: PackedStringArray) -> void:
    var length: float=float(state.get("seam_length",.3))
    var jaw: int=HarvestPattern.jaw_side(id) if quirks.has("chomp") else 0
    var seams: Array=HarvestPattern.seams(id,int(state.get("step",0)),int(state.get("seams",2)),length,jaw)
    var hp: Array=state.get("hp",[])
    var full: int=int(state.get("seam_hp",1))
    var band: float=float(state.get("perfect_band",.4))
    for i in seams.size():
        var seam: Dictionary=seams[i]
        var ends: Array=HarvestPattern.seam_ends(seam,length,HarvestPattern.drift(quirks,id,_clock,seam.c))
        var a: Vector2=_from_metric(ends[0]);var b: Vector2=_from_metric(ends[1])
        var along: Vector2=(b-a).normalized();var side: Vector2=Vector2(-along.y,along.x)
        var left: int=int(hp[i]) if i<hp.size() else full
        if left<=0:
            # An opened cut: a dark gash with the hide curling back on both sides.
            var mid: Vector2=(a+b)*.5
            var gape: float=_unit()*.03
            board.draw_colored_polygon(PackedVector2Array([a,mid+side*gape,b,mid-side*gape]),Color(.33,.05,.06))
            board.draw_line(a,b,Color("e2574a"),2.0,true)
            board.draw_line(a.lerp(b,.15)+side*gape*.7,a.lerp(b,.85)+side*gape*.7,Color(.9,.65,.55,.5),1.5,true)
            continue
        var cracked: bool=full>1 and left<full
        var thread: Color=Color("ffb35c") if cracked else Color("f3e6c4")
        if full>1 and not cracked:
            # Armoured hide: a second, darker seam that needs its own flick.
            board.draw_line(a+side*5,b+side*5,Color(.62,.66,.70,.9),3.0,true)
        for k in 9:
            var from: Vector2=a.lerp(b,float(k)/9.0);var to: Vector2=a.lerp(b,(float(k)+.55)/9.0)
            board.draw_line(from,to,thread,3.0,true)
            board.draw_line(from.lerp(to,.5)-side*5,from.lerp(to,.5)+side*5,Color(thread,.7),1.5,true)
        # The sweet spot: crossing here is a perfect cut.
        var centre: Vector2=(a+b)*.5
        var reach: float=a.distance_to(b)*.5*band
        board.draw_line(centre-along*reach,centre+along*reach,Color(1,.85,.35,.75),5.0,true)
        if bool(state.get("directional",false)):
            var normal: Vector2=HarvestPattern.seam_normal(seam).normalized()
            var tip: Vector2=centre+normal*_unit()*.07
            var wing: Vector2=Vector2(-normal.y,normal.x)*6
            board.draw_line(centre-normal*_unit()*.05,tip,Color(.8,1,.7,.85),2.0,true)
            board.draw_colored_polygon(PackedVector2Array([tip+normal*8,tip+wing,tip-wing]),Color(.8,1,.7,.95))

## The crocodile's reflex: jaws rest half open, gape wide as a warning, SNAP.
func _draw_jaw(area: Rect2, id: int) -> void:
    var side: int=HarvestPattern.jaw_side(id)
    var mood: int=HarvestPattern.jaw_state(id,_clock,float(state.get("jaw_period",3)))
    var width: float=area.size.x*HarvestPattern.JAW_EDGE
    var zone:=Rect2(area.position.x if side<0 else area.end.x-width,area.position.y,width,area.size.y)
    var pulse: float=.5+.5*sin(float(Time.get_ticks_msec())*.02)
    board.draw_rect(zone,Color(1,.15,.1,.10 if mood==0 else .22+.18*pulse if mood==1 else .5))
    var gap: float=area.size.y*(.30 if mood==0 else .48 if mood==1 else .02)
    var mid: float=zone.get_center().y
    for row in [-1.0,1.0]:
        var edge: float=mid+row*gap
        var gum: float=area.position.y if row<0 else area.end.y
        board.draw_rect(Rect2(zone.position.x,minf(gum,edge),zone.size.x,absf(edge-gum)),Color(.25,.32,.2,.85))
        for k in 6:
            var x: float=zone.position.x+zone.size.x*(float(k)+.5)/6.0
            var half: float=zone.size.x/14.0
            board.draw_colored_polygon(PackedVector2Array([Vector2(x-half,edge),Vector2(x+half,edge),Vector2(x,edge-row*area.size.y*.07)]),Color("f4efd8"))

func _draw_bugs(id: int, ticks: bool) -> void:
    var count: int=int(state.get("hazards",2))
    var step: int=int(state.get("step",0))
    var bugs: PackedVector2Array=HarvestPattern.ticks(id,step,_clock,count) if ticks else HarvestPattern.bees(id,step,_clock,count)
    var dead: int=int(state.get("dead",0))
    var t: float=float(Time.get_ticks_msec())*.001
    var r: float=_unit()*HarvestPattern.HAZARD_RADIUS
    for i in bugs.size():
        if dead&(1<<i): continue
        var p: Vector2=_to_board(bugs[i])
        if ticks:
            for leg in 3:
                for s in [-1.0,1.0]:
                    var wiggle: float=sin(t*12.0+float(leg))*2.0
                    board.draw_line(p+Vector2(s*r*.4,float(leg-1)*r*.45),p+Vector2(s*r*1.25,float(leg-1)*r*.6+wiggle),Color(.18,.1,.06),1.5,true)
            board.draw_circle(p,r*.75,Color("5a3a22"))
            board.draw_circle(p+Vector2(0,-r*.8),r*.32,Color("2e1c10"))
        else:
            var flap: float=absf(sin(t*40.0+float(i)))
            board.draw_circle(p+Vector2(-r*.35,-r*.8),r*.5*flap+1,Color(.85,.95,1,.6))
            board.draw_circle(p+Vector2(r*.35,-r*.8),r*.5*flap+1,Color(.85,.95,1,.6))
            board.draw_circle(p,r*.8,Color("f2c230"))
            board.draw_line(p+Vector2(-r*.25,-r*.7),p+Vector2(-r*.25,r*.7),Color(.1,.08,.05),2.0)
            board.draw_line(p+Vector2(r*.25,-r*.7),p+Vector2(r*.25,r*.7),Color(.1,.08,.05),2.0)

## Hide integrity, the single number that decides the raw hide's stars.
func draw_meter() -> void:
    if pending: return
    var stars: int=clampi(int(state.get("stars",5)),1,5)
    var color: Color=[Color("df8674"),Color("e5a36a"),Color("e5c88a"),Color("a9d696"),Color("8fd98a")][stars-1]
    draw_bar(1.0-clampf(float(state.get("wear",0))/1000.0,0,1),color,[.94,.78,.57,.32])

# ----------------------------------------------------------------- labels ---

func refresh_labels() -> void:
    if not is_instance_valid(title_label) or state.is_empty(): return
    var kind: String=String(state.get("animal_kind","rabbit"))
    var definition:=AnimalCatalog.animal(StringName(kind))
    title_label.text=(tr(definition.display_name) if definition else kind)+"  ·  "+tr("HARVEST_SHELL" if kind=="turtle" else "HARVEST_SKIN")
    var completed: int=int(state.get("completed",0))
    var required: int=int(state.get("required",0))
    stage_label.text=tr("HARVEST_PREPARING") if pending else tr("HARVEST_MOVE_SLASH")
    progress_label.text="" if pending else LocaleSettings.text("HARVEST_PROGRESS",{"done":mini(completed+(1 if active else 0),required),"total":required})
    var quirks:=PackedStringArray()
    var source: PackedStringArray=definition.harvest_quirks if pending and definition else _quirks()
    for quirk in source:
        if quirk!="fat": quirks.append(tr("HARVEST_QUIRK_"+quirk.to_upper()))
    var difficulty: float=float(state.get("difficulty",definition.harvest_difficulty() if definition else 0.0))
    var level: String=tr("HARVEST_EASY" if difficulty<.15 else "HARVEST_MEDIUM" if difficulty<.4 else "HARVEST_HARD" if difficulty<.65 else "HARVEST_VERY_HARD" if difficulty<.95 else "HARVEST_EXPERT")
    info_label.text=LocaleSettings.text("HARVEST_LEVEL",{"difficulty":level})+("  ·  "+"  ·  ".join(quirks) if not quirks.is_empty() else "")
    var stars: int=clampi(int(state.get("stars",5)),1,5)
    stars_label.text=stars_text(stars)
    stars_label.add_theme_color_override("font_color",star_color(stars))
    quality_label.text=tr("HARVEST_PREPARING") if pending else LocaleSettings.text("HARVEST_RAW_RATING",{"quality":tr("HARVEST_STARS_"+str(stars))})
    quality_label.add_theme_color_override("font_color",star_color(stars))
    value_label.text=tr("HARVEST_PRICE_PENDING") if pending else LocaleSettings.text("PRICE",{"n":int(state.get("sell_value",0))})
    value_label.add_theme_color_override("font_color",star_color(stars))
    value_note_label.text="" if pending else LocaleSettings.text("HARVEST_RAW_VALUE",{"n":int(state.get("clean_value",0))})
    refresh_hint()

## Live coaching beats a stale verdict: the line under the board always says
## what to do right now, or what just went wrong.
func refresh_hint() -> void:
    var feedback: String=String(state.get("feedback",""))
    feedback_label.add_theme_color_override("font_color",Color("f09b7d") if is_bad(feedback) or feedback in ["cancelled","full_bag"] else Color("a6e9c0"))
    if not active and not pending:
        feedback_label.text=tr("HARVEST_FEEDBACK_"+feedback.to_upper()) if not feedback.is_empty() else ""
        tip_label.text=tr("HARVEST_DONE_TIP") if feedback=="complete" else ""
        return
    tip_label.text=tr("HARVEST_TIP")
    if pending: feedback_label.text="";return
    if not feedback.is_empty(): feedback_label.text=tr("HARVEST_FEEDBACK_"+feedback.to_upper());return
    var id: int=int(state.get("id",0))
    if _quirks().has("chomp") and HarvestPattern.jaw_state(id,_clock,float(state.get("jaw_period",3)))>0: feedback_label.text=tr("HARVEST_HINT_JAW")
    elif _kicking()>0: feedback_label.text=tr("HARVEST_HINT_SPASM")
    else: feedback_label.text=tr("HARVEST_HINT_SLASH_DIR" if bool(state.get("directional",false)) else "HARVEST_HINT_SLASH")
