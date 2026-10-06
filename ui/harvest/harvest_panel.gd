extends CanvasLayer
## Skinning overlay: a short arcade routine on the hide. Flick the knife across
## stitched seams, scrub fat off against the clock, then grab the flap and rip it
## off like a slingshot. Each species brings its own twist (ticks, bees, spasms,
## a snapping jaw…). Nothing is ever held down: the mouse steers a virtual knife
## and the host judges every sample, this panel only draws and predicts.
signal click_requested(id: int, token: int, click: int, point: Vector2)
signal cancel_requested

## Screen pixels of mouse travel per metric hide unit (the hide is one unit tall).
## Deliberately not difficulty-dependent: species get harder, the hand does not.
const BLADE_PIXELS: float=330.0
const COAT_COLORS: Dictionary={&"rabbit":Color("86705c"),&"deer":Color("b27b4e"),&"boar":Color("5a4940"),&"wolf":Color("737977"),&"bear":Color("493d32"),&"frog":Color("63794b"),&"turtle":Color("635a36"),&"snake":Color("7a7953"),&"crocodile":Color("666747"),&"ancient_crocodile":Color("464f3a")}
const TRAIL_SECONDS: float=.16
## Popup text, colour and sound per host event.
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
    "scraped":{"color":Color("fff1b0"),"sound":"slice","size":24},
    "clean":{"color":Color("ffd65c"),"sound":"perfect","size":30},
    "fat_left":{"color":Color("ff9a5c"),"sound":"snag","size":24,"bad":true},
    "grab":{"color":Color("cfe6b9"),"sound":"grab","size":22},
    "fumble":{"color":Color("f0a070"),"sound":"snag","size":20},
    "boing":{"color":Color("8fd0ff"),"sound":"boing","size":34,"bad":true,"shake":.25},
    "flop_perfect":{"color":Color("ffd65c"),"sound":"flop","size":36,"shake":.3},
    "flop":{"color":Color("e9f5d8"),"sound":"flop","size":30,"shake":.25},
    "overpull":{"color":Color("ff9a5c"),"sound":"rip","size":28,"bad":true,"shake":.5},
    "rip":{"color":Color("ff4a3a"),"sound":"rip","size":36,"bad":true,"shake":.9},
    "complete":{"color":Color("ffd65c"),"sound":"complete","size":40},
}

var state: Dictionary={}
var active: bool=false
var pending: bool=false
var board: Control
var species_label: Label
var stage_label: Label
var progress_label: Label
var quirk_label: Label
var stars_label: Label
var quality_label: Label
var value_label: Label
var value_percent_label: Label
var feedback_label: Label
var tip_label: Label
var integrity_bar: Control
var _root: Control
var _card: PanelContainer
var _terminal_time: float=0
var _job_key: String=""
var _ended_key: String=""
var _fx_seen: int=-1
var _clicks: int=0
## Local copy of the host's move clock, extrapolated between 20 Hz updates.
var _clock: float=0
var _clock_step: int=-1
var _trail: Array[Dictionary]=[]
var _popups: Array[Dictionary]=[]
var _shake: float=0
var _flash: float=0
var _flash_bad: bool=false
var _combo_shown: int=0
var _combo_age: float=9
var _speed: float=0
var _last_blade: Vector2=Vector2(.5,.5)
var _swoosh_cooldown: float=0
var _fur: PackedVector2Array=PackedVector2Array()
var _fur_kind: String=""
var _players: Array[AudioStreamPlayer]=[]
var _next_player: int=0
var _sounds: Dictionary={}
var _scrape: AudioStreamPlayer
var _scrape_level: float=0
var _buzz: AudioStreamPlayer

func _ready() -> void:
    layer=11
    name="HarvestPanel"
    _root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_root)
    _card=PanelContainer.new();_root.add_child(_card)
    _card.anchor_left=1;_card.anchor_right=1;_card.anchor_top=1;_card.anchor_bottom=1
    _card.offset_left=-700;_card.offset_right=-24;_card.offset_top=-660;_card.offset_bottom=-44
    _card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.035,.07,.065,.96);style.border_color=Color("a4b992")
    style.set_border_width_all(1);style.set_corner_radius_all(12)
    style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=14;style.content_margin_bottom=14
    _card.add_theme_stylebox_override("panel",style)
    var rows:=VBoxContainer.new();rows.add_theme_constant_override("separation",4);_card.add_child(rows)
    species_label=_label(22,Color("f5dfaf"));rows.add_child(species_label)
    var header:=HBoxContainer.new();rows.add_child(header)
    stage_label=_label(16,Color("c5d7c3"));stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(stage_label)
    progress_label=_label(15,Color("e6d49c"));header.add_child(progress_label)
    quirk_label=_label(13,Color("e5a36a"));quirk_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(quirk_label)
    board=Control.new();board.custom_minimum_size=Vector2(0,330);board.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(board)
    board.draw.connect(_draw_board)
    integrity_bar=Control.new();integrity_bar.custom_minimum_size=Vector2(0,24);integrity_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(integrity_bar)
    integrity_bar.draw.connect(_draw_integrity)
    var rating:=HBoxContainer.new();rows.add_child(rating)
    var quality_column:=VBoxContainer.new();quality_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    quality_column.add_theme_constant_override("separation",0);rating.add_child(quality_column)
    stars_label=_label(26,Color("f5d477"));quality_column.add_child(stars_label)
    quality_label=_label(13,Color("e6d49c"));quality_column.add_child(quality_label)
    var price_column:=VBoxContainer.new();price_column.add_theme_constant_override("separation",0);rating.add_child(price_column)
    value_label=_label(22,Color("f5d477"));value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price_column.add_child(value_label)
    value_percent_label=_label(13,Color("b1c3b5"));value_percent_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price_column.add_child(value_percent_label)
    feedback_label=_label(18,Color("a6e9c0"));rows.add_child(feedback_label)
    tip_label=_label(13,Color("b1c3b5"));tip_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(tip_label)
    for i in 5:
        var player:=AudioStreamPlayer.new();player.volume_db=-17;add_child(player);_players.append(player)
    _sounds["slice"]=_noise(.11,.55,true)
    _sounds["swoosh"]=_noise(.09,.35,true)
    _sounds["perfect"]=_tone(988,1480,.16)
    _sounds["crack"]=_noise(.05,.9,false)
    _sounds["snag"]=_tone(150,110,.14)
    _sounds["splat"]=_noise(.16,.12,false)
    _sounds["sting"]=_tone(620,930,.22)
    _sounds["chomp"]=_chomp()
    _sounds["grab"]=_tone(520,780,.07)
    _sounds["boing"]=_sweep(180,520,.32,true)
    _sounds["flop"]=_sweep(220,70,.20,false)
    _sounds["rip"]=_noise(.30,.35,false)
    _sounds["complete"]=_tone(880,1320,.26)
    _scrape=AudioStreamPlayer.new();_scrape.volume_db=-40;_scrape.stream=_scrape_loop();add_child(_scrape)
    _buzz=AudioStreamPlayer.new();_buzz.volume_db=-34;_buzz.stream=_buzz_loop();add_child(_buzz)
    LocaleSettings.changed.connect(_refresh_labels)
    _root.hide()

func _label(font_size: int,color: Color) -> Label:
    var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
    return label

func begin_pending(id: int,animal_kind: String) -> void:
    state={"id":id,"animal_kind":animal_kind,"required":0,"completed":0,"stars":5,"active":true}
    active=true;pending=true;_terminal_time=0;_job_key="";_fx_seen=-1
    _trail.clear();_popups.clear();_shake=0;_flash=0;_combo_shown=0
    NetworkSession.local_blade=Vector2(.5,.5);_last_blade=NetworkSession.local_blade
    _root.show();_refresh_labels();board.queue_redraw()

func show_state(data: Dictionary) -> void:
    if data.is_empty(): return
    state=data.duplicate();pending=false;active=bool(state.get("active",true))
    var key: String="%s:%s" % [state.get("id",0),state.get("token",0)]
    var fx: int=int(state.get("fx",0))
    # A finished or cancelled job's summary repeats until the host forgets it:
    # show it once for a moment, then keep it hidden.
    if not active:
        var ending: String="%s:%s:%s" % [key,fx,state.get("feedback","")]
        if ending==_ended_key and _terminal_time<=0: return
        if ending!=_ended_key: _ended_key=ending;_terminal_time=1.2
    if key!=_job_key:
        # A new job (or a resumed one) never replays events from before it opened.
        _job_key=key;_fx_seen=fx if active else fx-1
        _clicks=maxi(_clicks,int(state.get("clicks",0)))
    if fx!=_fx_seen:
        _fx_seen=fx
        _event(String(state.get("feedback","")),Vector2(state.get("fx_pos",Vector2(.5,.5))),int(state.get("combo",0)))
    if int(state.get("step",-1))!=_clock_step:
        _clock_step=int(state.get("step",-1));_clock=_server_clock()
    _root.show();_refresh_labels();board.queue_redraw()

func is_open() -> bool:
    return active or pending

## Every move is played with the mouse; there is no separate timing lane.
func is_interactive() -> bool:
    return active and not pending

func move() -> int:
    return int(state.get("move",HarvestPattern.MOVE_SLASH))

func close() -> void:
    active=false;pending=false;state={};_terminal_time=0
    _trail.clear();_popups.clear()
    if is_instance_valid(_scrape) and _scrape.playing: _scrape.stop()
    if is_instance_valid(_buzz) and _buzz.playing: _buzz.stop()
    if is_instance_valid(_root): _root.hide()

## The host's move clock as of now: its last report plus the time since it
## arrived. The local host reads the live job, which has no arrival stamp.
func _server_clock() -> float:
    var time: float=float(state.get("move_time",0))
    if active and state.has("received_at"):
        time+=clampf(float(Time.get_ticks_msec())/1000.0-float(state.received_at),0,.5)
    return time

func _process(delta: float) -> void:
    _flash=maxf(0,_flash-delta);_shake=maxf(0,_shake-delta*2.2);_combo_age+=delta
    _swoosh_cooldown=maxf(0,_swoosh_cooldown-delta)
    if is_interactive():
        _clock+=delta
        var target: float=_server_clock()
        _clock=target if absf(target-_clock)>.25 else lerpf(_clock,target,clampf(delta*6.0,0,1))
        var blade: Vector2=NetworkSession.local_blade
        var moved: float=HarvestPattern.metric(blade).distance_to(HarvestPattern.metric(_last_blade))
        _speed=lerpf(_speed,moved/maxf(delta,.001),clampf(delta*20.0,0,1))
        _last_blade=blade
        var now: float=float(Time.get_ticks_msec())/1000.0
        _trail.append({"p":blade,"t":now,"fast":_speed>=HarvestPattern.HOVER_SPEED})
        while not _trail.is_empty() and now-float(_trail[0].t)>TRAIL_SECONDS: _trail.pop_front()
        if move()==HarvestPattern.MOVE_SLASH and _speed>=float(state.get("min_speed",1.0)) and _swoosh_cooldown<=0:
            _swoosh_cooldown=.22;_play("swoosh",1.0+randf()*.15)
    for index in range(_popups.size()-1,-1,-1):
        _popups[index].age=float(_popups[index].age)+delta
        if float(_popups[index].age)>=.95: _popups.remove_at(index)
    _update_loops(delta)
    if _root.visible:
        board.queue_redraw();integrity_bar.queue_redraw()
        if is_interactive(): _refresh_hint()
    if not active and not pending and _terminal_time>0:
        _terminal_time=maxf(0,_terminal_time-delta)
        if _terminal_time<=0: _root.hide()

## Continuous sounds: scrubbing fat and the bear's bees.
func _update_loops(delta: float) -> void:
    var wants: float=0.0
    if is_interactive() and move()==HarvestPattern.MOVE_SCRAPE: wants=clampf(_speed/1.5,0,1)
    _scrape_level=lerpf(_scrape_level,wants,clampf(delta*9.0,0,1))
    if _scrape_level>.04:
        if not _scrape.playing: _scrape.play()
        _scrape.volume_db=lerpf(-40.0,-19.0,_scrape_level)
    elif _scrape.playing: _scrape.stop()
    var buzzing: bool=is_interactive() and _quirks().has("bees") and move()!=HarvestPattern.MOVE_YANK
    if buzzing and not _buzz.playing: _buzz.play()
    elif not buzzing and _buzz.playing: _buzz.stop()

func _quirks() -> PackedStringArray:
    return PackedStringArray(state.get("quirks",PackedStringArray()))

## One host event: popup, sound, shake, flash and the combo badge.
func _event(feedback: String, at: Vector2, combo: int) -> void:
    if not EVENTS.has(feedback): return
    var spec: Dictionary=EVENTS[feedback]
    var bad: bool=bool(spec.get("bad",false))
    _popups.append({"text":tr("HARVEST_POP_"+feedback.to_upper()),"p":at,"age":0.0,"color":spec.color,"size":int(spec.size)})
    var pitch: float=1.0+clampf(float(combo-1),0,8)*.07 if not bad else 1.0
    _play(String(spec.sound),pitch)
    _shake=maxf(_shake,float(spec.get("shake",0)))
    _flash=.35 if bad else .18;_flash_bad=bad
    if combo>=2 and not bad:
        _combo_shown=combo;_combo_age=0
    elif bad: _combo_shown=0

func _play(sound: String, pitch: float=1.0) -> void:
    if not _sounds.has(sound): return
    var player: AudioStreamPlayer=_players[_next_player];_next_player=(_next_player+1)%_players.size()
    player.stream=_sounds[sound];player.pitch_scale=pitch;player.play()

# ---------------------------------------------------------------- drawing ---

## The hide keeps its true proportions so a diagonal flick on screen is the
## same diagonal the host measures.
func _board_rect() -> Rect2:
    var room:=Vector2(maxf(60,board.size.x-28),maxf(40,board.size.y-28))
    var size:=Vector2(room.x,room.x/HarvestPattern.ASPECT)
    if size.y>room.y: size=Vector2(room.y*HarvestPattern.ASPECT,room.y)
    return Rect2((board.size-size)*.5,size)

func _to_board(point: Vector2) -> Vector2:
    var area: Rect2=_board_rect()
    return area.position+Vector2(point.x*area.size.x,point.y*area.size.y)

func _from_metric(point: Vector2) -> Vector2:
    return _to_board(Vector2(point.x/HarvestPattern.ASPECT,point.y))

func _unit() -> float:
    return _board_rect().size.y

func _draw_board() -> void:
    var area: Rect2=_board_rect()
    var kind: String=String(state.get("animal_kind","rabbit"))
    var coat: Color=COAT_COLORS.get(StringName(kind),Color("86705c"))
    var quirks: PackedStringArray=_quirks()
    var id: int=int(state.get("id",0))
    var kicking: int=HarvestPattern.spasm(id,_clock,float(state.get("twitch_period",3))) if quirks.has("twitch") and is_interactive() else 0
    var jitter:=Vector2.ZERO
    var tremble: float=_shake*9.0+(5.0 if kicking==2 else 0.0)
    if tremble>0:
        var t: float=float(Time.get_ticks_msec())*.001
        jitter=Vector2(sin(t*83.0),cos(t*67.0))*tremble
    board.draw_set_transform(jitter)
    var hide_style:=StyleBoxFlat.new()
    hide_style.bg_color=coat.darkened(.38);hide_style.border_color=coat.lightened(.22)
    hide_style.set_border_width_all(2);hide_style.set_corner_radius_all(18)
    board.draw_style_box(hide_style,area.grow(8))
    _draw_fur(area,kind,coat,quirks)
    if pending:
        board.draw_set_transform(Vector2.ZERO)
        return
    if is_interactive():
        if quirks.has("chomp") and move()!=HarvestPattern.MOVE_YANK: _draw_jaw(area,id)
        match move():
            HarvestPattern.MOVE_SLASH: _draw_seams(id,quirks)
            HarvestPattern.MOVE_SCRAPE: _draw_fat(id,area)
            HarvestPattern.MOVE_YANK: _draw_yank(id,coat)
        if move()!=HarvestPattern.MOVE_YANK:
            if quirks.has("ticks"): _draw_bugs(id,true)
            if quirks.has("bees"): _draw_bugs(id,false)
        if kicking>0: _draw_spasm(area,kicking)
        _draw_blade()
    _draw_popups()
    _draw_combo(area)
    if _flash>0:
        var tint: Color=Color(1,.3,.2,_flash*.45) if _flash_bad else Color(.85,1,.65,_flash*.35)
        board.draw_rect(area.grow(8),tint)
    board.draw_set_transform(Vector2.ZERO)

## Short fur strokes (or scale dots) so the board reads as an actual pelt.
func _draw_fur(area: Rect2, kind: String, coat: Color, quirks: PackedStringArray) -> void:
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
        var offset: Vector2=HarvestPattern.drift(quirks,id,_clock,seam.c)
        var ends: Array=HarvestPattern.seam_ends(seam,length,offset)
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
            var normal: Vector2=HarvestPattern.seam_normal(seam)
            normal=Vector2(normal.x,normal.y).normalized()
            var tip: Vector2=centre+normal*_unit()*.07
            board.draw_line(centre-normal*_unit()*.05,tip,Color(.8,1,.7,.85),2.0,true)
            board.draw_colored_polygon(PackedVector2Array([tip+normal*8,tip+Vector2(-normal.y,normal.x)*6,tip-Vector2(-normal.y,normal.x)*6]),Color(.8,1,.7,.95))

## The crocodile's reflex: jaws rest half open, gape wide as a warning, SNAP.
func _draw_jaw(area: Rect2, id: int) -> void:
    var side: int=HarvestPattern.jaw_side(id)
    var period: float=float(state.get("jaw_period",3))
    var mood: int=HarvestPattern.jaw_state(id,_clock,period)
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

func _draw_spasm(area: Rect2, kicking: int) -> void:
    var pulse: float=.5+.5*sin(float(Time.get_ticks_msec())*.03)
    if kicking==2: board.draw_rect(area,Color(1,.2,.1,.18))
    var font: Font=ThemeDB.fallback_font
    var mark: String="!!" if kicking==2 else "!"
    _text(font,area.position+Vector2(area.size.x*.5,area.size.y*.16),mark,42 if kicking==2 else 30+int(pulse*8),Color(1,.35,.2,.6+.4*pulse))

func _draw_fat(id: int, area: Rect2) -> void:
    var radius: float=float(state.get("fat_radius",.09))
    var blobs: PackedVector2Array=HarvestPattern.fat(id,int(state.get("step",0)),int(state.get("fat_count",3)),radius)
    var health: Array=state.get("fat",[])
    var t: float=float(Time.get_ticks_msec())*.001
    for i in blobs.size():
        var left: float=float(health[i]) if i<health.size() else 1.0
        if left<=0.0: continue
        var centre: Vector2=_to_board(blobs[i])
        var size: float=_unit()*radius*(.45+.55*left)
        var shape:=PackedVector2Array()
        for k in 14:
            var angle: float=TAU*float(k)/14.0
            shape.append(centre+Vector2(cos(angle),sin(angle))*size*(1.0+.12*sin(angle*3.0+t*4.0+float(i))))
        board.draw_colored_polygon(shape,Color(.96,.9,.66,.92))
        board.draw_circle(centre+Vector2(-size*.3,-size*.3),size*.22,Color(1,1,.9,.6))
    var total: float=maxf(.1,float(state.get("scrape_time",6)))
    var left_time: float=clampf(float(state.get("scrape_left",total))-maxf(0,_clock-float(state.get("move_time",0))),0,total)
    var fill: float=left_time/total
    var bar:=Rect2(area.position+Vector2(10,8),Vector2((area.size.x-20)*fill,8))
    board.draw_rect(Rect2(area.position+Vector2(10,8),Vector2(area.size.x-20,8)),Color(0,0,0,.35))
    board.draw_rect(bar,Color(.55,.85,.45).lerp(Color(1,.3,.2),1.0-fill))

## The slingshot: grab the ring, stretch along the arrow, release in the green.
func _draw_yank(id: int, coat: Color) -> void:
    var flap: Dictionary=HarvestPattern.yank(id,int(state.get("step",0)))
    var ring: Vector2=flap.ring;var direction: Vector2=flap.dir
    var width: float=float(state.get("sweet_width",.3))
    var wobble: float=float(state.get("wobble",0))
    if _quirks().has("twitch") and HarvestPattern.spasm(id,_clock,float(state.get("twitch_period",3)))==2: wobble+=.22
    var shift: float=HarvestPattern.yank_wobble(id,_clock,wobble)
    var start: Vector2=_to_board(ring)
    var grabbed: bool=bool(state.get("grabbed",false))
    var blade: Vector2=_to_board(NetworkSession.local_blade)
    var side: Vector2=Vector2(-direction.y,direction.x)
    # The flap of hide itself, stretched towards the hand once grabbed.
    var base: float=_unit()*.12
    if grabbed and blade.distance_to(start)>4.0:
        var pull: Vector2=(blade-start).normalized()
        var across: Vector2=Vector2(-pull.y,pull.x)
        board.draw_colored_polygon(PackedVector2Array([start-across*base,start+across*base,blade+across*base*.45,blade-across*base*.45]),Color(.55,.18,.15,.9))
    else:
        board.draw_circle(start,base*.7,Color(coat.lightened(.1),.35))
    # The pull path, with the release zone sliding as the hide fights back.
    var low: float=HarvestPattern.YANK_SWEET-width*.5-shift
    var high: float=HarvestPattern.YANK_SWEET+width*.5-shift
    var tear: float=HarvestPattern.YANK_RIP-shift
    board.draw_line(start,_to_board(HarvestPattern.yank_point(ring,direction,1.35)),Color(1,1,1,.18),10.0,true)
    board.draw_line(_to_board(HarvestPattern.yank_point(ring,direction,maxf(0,low))),_to_board(HarvestPattern.yank_point(ring,direction,high)),Color(.45,.9,.45,.85),12.0,true)
    var sweet: Vector2=_to_board(HarvestPattern.yank_point(ring,direction,HarvestPattern.YANK_SWEET-shift))
    board.draw_circle(sweet,5,Color(1,.9,.4))
    board.draw_line(_to_board(HarvestPattern.yank_point(ring,direction,tear)),_to_board(HarvestPattern.yank_point(ring,direction,1.35)),Color(1,.3,.2,.75),12.0,true)
    var tip: Vector2=_to_board(HarvestPattern.yank_point(ring,direction,1.42))
    board.draw_colored_polygon(PackedVector2Array([tip+direction*10,tip+side*8,tip-side*8]),Color(1,1,1,.5))
    var pulse: float=.5+.5*sin(float(Time.get_ticks_msec())*.012)
    if grabbed:
        board.draw_line(start,blade,Color(.95,.75,.6),3.0,true)
        var tension: float=HarvestPattern.yank_tension(ring,NetworkSession.local_blade,direction)+shift
        var meter: Color=Color(.45,.9,.45) if tension>=HarvestPattern.YANK_SWEET-width*.5 and tension<=HarvestPattern.YANK_SWEET+width*.5 else Color(1,.35,.2) if tension>HarvestPattern.YANK_SWEET+width*.5 else Color(.9,.9,.8)
        board.draw_circle(blade,9,meter)
    else:
        board.draw_arc(start,_unit()*HarvestPattern.GRAB_RADIUS*(.8+.2*pulse),0,TAU,28,Color(1,.9,.5,.9),3.0,true)
    board.draw_circle(start,7,Color("f3e6c4"))

func _draw_blade() -> void:
    if _trail.size()>=2:
        var now: float=float(Time.get_ticks_msec())/1000.0
        for i in range(1,_trail.size()):
            var age: float=clampf((now-float(_trail[i].t))/TRAIL_SECONDS,0,1)
            var fast: bool=bool(_trail[i].fast)
            var color: Color=Color(1,.97,.85,(1.0-age)*.9) if fast else Color(.85,.9,.8,(1.0-age)*.25)
            board.draw_line(_to_board(_trail[i-1].p),_to_board(_trail[i].p),color,(9.0 if fast else 3.0)*(1.0-age)+1.0,true)
    var blade: Vector2=_to_board(NetworkSession.local_blade)
    var heading: Vector2=Vector2(1,-.6).normalized()
    if _trail.size()>=2:
        var motion: Vector2=_to_board(_trail[_trail.size()-1].p)-_to_board(_trail[0].p)
        if motion.length()>4: heading=motion.normalized()
    var side: Vector2=Vector2(-heading.y,heading.x)
    var cutting: bool=_speed>=HarvestPattern.HOVER_SPEED
    var steel: Color=Color("fff6dc") if cutting else Color(.9,.92,.88,.8)
    board.draw_colored_polygon(PackedVector2Array([blade+heading*16,blade+side*4,blade-heading*4,blade-side*1.5]),steel)
    board.draw_line(blade-heading*4,blade-heading*15,Color("4a3526"),5.0,true)

func _draw_popups() -> void:
    var font: Font=ThemeDB.fallback_font
    for popup in _popups:
        var age: float=float(popup.age)
        var pop: float=1.0+.35*maxf(0,1.0-age*6.0)
        var color: Color=popup.color;color.a=clampf(1.4-age*1.5,0,1)
        _text(font,_to_board(popup.p)+Vector2(0,-28-age*42),String(popup.text),int(float(popup.size)*pop),color)

func _draw_combo(area: Rect2) -> void:
    if _combo_shown<2 or _combo_age>1.4: return
    var font: Font=ThemeDB.fallback_font
    var color: Color=Color("ffd65c").lerp(Color("ff7a3c"),clampf(float(_combo_shown-2)/6.0,0,1))
    color.a=clampf(1.6-_combo_age,0,1)
    var pop: float=1.0+.4*maxf(0,1.0-_combo_age*5.0)
    _text(font,Vector2(area.end.x-84,area.position.y+34),LocaleSettings.text("HARVEST_COMBO",{"n":_combo_shown}),int((22.0+minf(float(_combo_shown),8.0)*2.0)*pop),color)

func _text(font: Font, centre: Vector2, text: String, size: int, color: Color) -> void:
    var width: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
    var at: Vector2=centre-Vector2(width*.5,-size*.35)
    board.draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,6,Color(0,0,0,color.a*.85))
    board.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

## Hide integrity, the single number that decides the star rating and the price.
func _draw_integrity() -> void:
    if pending: return
    var width: float=integrity_bar.size.x
    var keep: float=1.0-clampf(float(state.get("wear",0))/1000.0,0,1)
    var track:=Rect2(0,7,width,13)
    var style:=StyleBoxFlat.new();style.bg_color=Color("182c27");style.border_color=Color("496454")
    style.set_border_width_all(1);style.set_corner_radius_all(5)
    integrity_bar.draw_style_box(style,track)
    var stars: int=clampi(int(state.get("stars",5)),1,5)
    var color: Color=[Color("df8674"),Color("e5a36a"),Color("e5c88a"),Color("a9d696"),Color("8fd98a")][stars-1]
    integrity_bar.draw_rect(Rect2(1,8,maxf(0,(width-2)*keep),11),color)
    # Star thresholds, so the player can see the next tier they are about to lose.
    for threshold in [60,220,430,680]:
        var x: float=(1.0-float(threshold)/1000.0)*width
        integrity_bar.draw_line(Vector2(x,5),Vector2(x,22),Color(.95,1,.85,.35),1)

# ----------------------------------------------------------------- labels ---

func _refresh_labels() -> void:
    if not is_instance_valid(species_label) or state.is_empty(): return
    var kind: String=String(state.get("animal_kind","rabbit"))
    var definition:=AnimalCatalog.animal(StringName(kind))
    var name_value: String=tr(definition.display_name) if definition else kind
    species_label.text=name_value+"  ·  "+tr("HARVEST_SHELL" if kind=="turtle" else "HARVEST_SKIN")
    var completed: int=int(state.get("completed",0))
    var required: int=int(state.get("required",0))
    stage_label.text=tr("HARVEST_PREPARING") if pending else tr("HARVEST_MOVE_"+str(move()))
    progress_label.text="" if pending else LocaleSettings.text("HARVEST_PROGRESS",{"done":mini(completed+(1 if active else 0),required),"total":required})
    var quirks:=PackedStringArray()
    var source: PackedStringArray=_quirks() if not pending or not definition else definition.harvest_quirks
    for quirk in source: quirks.append(tr("HARVEST_QUIRK_"+quirk.to_upper()))
    var difficulty: float=float(state.get("difficulty",definition.harvest_difficulty() if definition else 0.0))
    var level: String=tr("HARVEST_EASY" if difficulty<.15 else "HARVEST_MEDIUM" if difficulty<.4 else "HARVEST_HARD" if difficulty<.65 else "HARVEST_VERY_HARD" if difficulty<.95 else "HARVEST_EXPERT")
    quirk_label.text=LocaleSettings.text("HARVEST_LEVEL",{"difficulty":level})+("  ·  "+"  ·  ".join(quirks) if not quirks.is_empty() else "")
    var stars: int=clampi(int(state.get("stars",5)),1,5)
    var rating_color: Color=[Color("df8674"),Color("e5a36a"),Color("e5c88a"),Color("a9d696"),Color("f5d477")][stars-1]
    stars_label.text="★".repeat(stars)+"☆".repeat(5-stars)
    stars_label.add_theme_color_override("font_color",rating_color)
    quality_label.text=tr("HARVEST_PREPARING") if pending else LocaleSettings.text("HARVEST_RATING",{"quality":tr("HARVEST_STARS_"+str(stars)),"stars":stars})
    quality_label.add_theme_color_override("font_color",rating_color)
    value_label.text=tr("HARVEST_PRICE_PENDING") if pending else LocaleSettings.text("PRICE",{"n":int(state.get("sell_value",0))})
    value_label.add_theme_color_override("font_color",rating_color)
    value_percent_label.text="" if pending else LocaleSettings.text("HARVEST_VALUE_BASE",{"percent":int(state.get("value_percent",0)),"base":int(state.get("base_value",0))})
    _refresh_hint()

## Live coaching beats a stale verdict: the line under the board always says
## what to do right now, or what just went wrong.
func _refresh_hint() -> void:
    var feedback: String=String(state.get("feedback",""))
    var bad: bool=EVENTS.has(feedback) and bool(EVENTS[feedback].get("bad",false))
    feedback_label.add_theme_color_override("font_color",Color("f09b7d") if bad or feedback in ["cancelled","full_bag"] else Color("a6e9c0"))
    if not active and not pending:
        feedback_label.text=tr("HARVEST_FEEDBACK_"+feedback.to_upper()) if not feedback.is_empty() else ""
        tip_label.text=tr("HARVEST_DONE_TIP") if feedback=="complete" else ""
        return
    if pending:
        feedback_label.text="";tip_label.text=tr("HARVEST_TIP");return
    if not feedback.is_empty(): feedback_label.text=tr("HARVEST_FEEDBACK_"+feedback.to_upper())
    else: feedback_label.text=_live_hint()
    tip_label.text=tr("HARVEST_TIP_"+str(move()))

func _live_hint() -> String:
    var id: int=int(state.get("id",0))
    var quirks: PackedStringArray=_quirks()
    if quirks.has("chomp") and move()!=HarvestPattern.MOVE_YANK and HarvestPattern.jaw_state(id,_clock,float(state.get("jaw_period",3)))>0:
        return tr("HARVEST_HINT_JAW")
    if quirks.has("twitch") and HarvestPattern.spasm(id,_clock,float(state.get("twitch_period",3)))>0:
        return tr("HARVEST_HINT_SPASM")
    match move():
        HarvestPattern.MOVE_SLASH:
            return tr("HARVEST_HINT_SLASH_DIR" if bool(state.get("directional",false)) else "HARVEST_HINT_SLASH")
        HarvestPattern.MOVE_SCRAPE:
            var left: float=maxf(0,float(state.get("scrape_left",0))-maxf(0,_clock-float(state.get("move_time",0))))
            return LocaleSettings.text("HARVEST_HINT_SCRAPE",{"s":"%.1f" % left})
    return tr("HARVEST_HINT_PULL" if bool(state.get("grabbed",false)) else "HARVEST_HINT_GRAB")

# ------------------------------------------------------------------ input ---

func _input(event: InputEvent) -> void:
    if not is_open() or (event is InputEventKey and event.echo): return
    if event.is_action_pressed("interact") or event.is_action_pressed("release_cursor"):
        cancel_requested.emit();get_viewport().set_input_as_handled();return
    for action in ["move_forward","move_backward","move_left","move_right"]:
        if event.is_action_pressed(action):
            cancel_requested.emit();get_viewport().set_input_as_handled();return
    if event.is_action_pressed("inventory") or event.is_action_pressed("minimap_detail"):
        cancel_requested.emit()
        return # Main may open the requested menu after cancellation.
    if event is InputEventMouseMotion:
        # Captured-mouse motion steers the virtual knife; the host scores it.
        if is_interactive():
            NetworkSession.local_blade=Vector2(
                clampf(NetworkSession.local_blade.x+event.relative.x/(BLADE_PIXELS*HarvestPattern.ASPECT),-.1,1.1),
                clampf(NetworkSession.local_blade.y+event.relative.y/BLADE_PIXELS,-.1,1.1))
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("fire") or event.is_action_pressed("jump"):
        # A click is a discrete act (grab or release the flap), never a hold.
        if is_interactive() and move()==HarvestPattern.MOVE_YANK:
            _clicks+=1
            click_requested.emit(int(state.id),int(state.token),_clicks,NetworkSession.local_blade)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_released("fire") or event.is_action_released("jump"):
        get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ sound ---

func _tone(first: float,second: float,duration: float) -> AudioStreamWAV:
    var wav:=_wav()
    var bytes:=PackedByteArray()
    for i in int(duration*wav.mix_rate):
        var t: float=float(i)/wav.mix_rate
        var envelope: float=sin(PI*t/duration)*exp(-t*8)
        var sample_value: int=int((sin(TAU*first*t)+sin(TAU*second*t)*.35)*envelope*12000)
        bytes.append(sample_value&255);bytes.append((sample_value>>8)&255)
    wav.data=bytes
    return wav

## Filtered noise burst. `bright` sweeps the filter open for a blade swish.
func _noise(duration: float, smoothing: float, bright: bool) -> AudioStreamWAV:
    var wav:=_wav();var count: int=int(duration*wav.mix_rate)
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
    wav.data=bytes
    return wav

## Pitch slide; `bounce` adds the wobble that makes a flap go BOING.
func _sweep(start: float, end: float, duration: float, bounce: bool) -> AudioStreamWAV:
    var wav:=_wav();var count: int=int(duration*wav.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    var phase: float=0
    for i in count:
        var t: float=float(i)/float(count)
        var frequency: float=lerpf(start,end,t)*(1.0+(.18*sin(t*TAU*7.0)*(1.0-t) if bounce else 0.0))
        phase+=TAU*frequency/wav.mix_rate
        bytes.encode_s16(i*2,int(sin(phase)*exp(-t*3.0)*sin(PI*minf(1.0,t*12.0))*15000.0))
    wav.data=bytes
    return wav

func _chomp() -> AudioStreamWAV:
    var wav:=_wav();var count: int=int(.24*wav.mix_rate)
    var bytes:=PackedByteArray();bytes.resize(count*2)
    var rng:=RandomNumberGenerator.new();rng.seed=909
    for i in count:
        var t: float=float(i)/wav.mix_rate
        var click: float=exp(-t*90.0)+exp(-maxf(0,t-.11)*90.0)*float(t>.11)
        var thud: float=sin(TAU*90.0*t)*exp(-t*14.0)
        bytes.encode_s16(i*2,int(clampf((rng.randf_range(-1,1)*click*.8+thud*.7)*22000.0,-32000,32000)))
    wav.data=bytes
    return wav

func _wav() -> AudioStreamWAV:
    var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050
    return wav

## Looping filtered noise: the blade scraping fat off the hide.
func _scrape_loop() -> AudioStreamWAV:
    var wav:=_wav();wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
    var length: int=11025
    var bytes:=PackedByteArray();bytes.resize(length*2)
    var rng:=RandomNumberGenerator.new();rng.seed=4421
    var smooth: float=0
    for i in length:
        smooth=lerpf(smooth,rng.randf_range(-1,1),.16)
        # Cross-fade the tail into the head so the loop point is inaudible.
        var blend: float=clampf(float(i)/float(length)*6.0-5.0,0,1)
        var sample: float=lerpf(smooth,smooth*.4+sin(float(i)*.03)*.2,blend)
        bytes.encode_s16(i*2,int(sample*7200))
    wav.data=bytes;wav.loop_end=length
    return wav

## A lazy buzz for the bear's bees: a detuned sawtooth pair.
func _buzz_loop() -> AudioStreamWAV:
    var wav:=_wav();wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
    var length: int=22050
    var bytes:=PackedByteArray();bytes.resize(length*2)
    for i in length:
        var t: float=float(i)/wav.mix_rate
        var saw: float=fposmod(t*210.0,1.0)*2.0-1.0
        var other: float=fposmod(t*214.0,1.0)*2.0-1.0
        var swell: float=.6+.4*sin(t*TAU*2.0)
        bytes.encode_s16(i*2,int((saw+other)*.5*swell*5200.0))
    wav.data=bytes;wav.loop_end=length
    return wav
