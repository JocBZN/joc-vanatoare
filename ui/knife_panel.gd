class_name KnifePanel
extends CanvasLayer
## Base of the knife mini-games (field skinning, camp cleaner). Owns the card,
## the virtual blade and its trail, host-event popups with sound, shake and
## flash, the combo badge, cancel keys and the local clock that extrapolates
## the host's between its 20 Hz updates. Subclasses draw the scene and labels.
##
## Nothing is ever held down: captured mouse motion steers the knife and the
## host judges every sample; a panel only draws and predicts.
signal cancel_requested

const COAT_COLORS: Dictionary={&"rabbit":Color("86705c"),&"deer":Color("b27b4e"),&"boar":Color("5a4940"),&"wolf":Color("737977"),&"bear":Color("493d32"),&"frog":Color("63794b"),&"turtle":Color("635a36"),&"snake":Color("7a7953"),&"crocodile":Color("666747"),&"ancient_crocodile":Color("464f3a"),&"ancient_bear":Color("4f4338"),&"albino_crocodile":Color("e9d6cd")}

var state: Dictionary={}
var active: bool=false
var pending: bool=false
var board: Control
var title_label: Label
var stage_label: Label
var progress_label: Label
var info_label: Label
var meter: Control
var stars_label: Label
var quality_label: Label
var value_label: Label
var value_note_label: Label
var feedback_label: Label
var tip_label: Label
var _root: Control
var _card: PanelContainer
var _terminal_time: float=0
var _job_key: String=""
var _ended_key: String=""
var _fx_seen: int=-1
## Local copy of the host's clock, extrapolated between updates.
var _clock: float=0
var _clock_key: String=""
var _trail: Array[Dictionary]=[]
var _popups: Array[Dictionary]=[]
var _shake: float=0
var _flash: float=0
var _flash_bad: bool=false
var _combo_shown: int=0
var _combo_age: float=9
var _speed: float=0
var _last_blade: Vector2=Vector2(.5,.5)
var _players: Array[AudioStreamPlayer]=[]
var _next_player: int=0
var _sounds: Dictionary={}

# ---------------------------------------------------- subclass interface ---

## Popup spec per host event: color, sound, size, and optional bad / shake.
func events() -> Dictionary: return {}
## Identifies one job, so a new or resumed job never replays old events.
func job_key(_data: Dictionary) -> String: return ""
## Changes whenever the host's clock restarts (a new wave or session).
func clock_key(_data: Dictionary) -> String: return ""
func clock_field() -> String: return "time"
## Card offsets from its anchor (by default the bottom-right corner).
func card_rect() -> Rect2: return Rect2(-700,-660,676,616)
func card_anchor() -> Vector2: return Vector2.ONE
func board_height() -> float: return 330.0
func draw_scene(_area: Rect2) -> void: pass
func draw_meter() -> void: pass
func refresh_labels() -> void: pass
func refresh_hint() -> void: pass
func update_loops(_delta: float) -> void: pass
## Extra board jitter the scene wants (a kicking corpse, a rattling drum).
func scene_tremble() -> float: return 0.0

# ------------------------------------------------------------- lifecycle ---

func _ready() -> void:
    layer=11
    _root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_root)
    _card=PanelContainer.new();_root.add_child(_card)
    var rect: Rect2=card_rect()
    var anchor: Vector2=card_anchor()
    _card.anchor_left=anchor.x;_card.anchor_right=anchor.x;_card.anchor_top=anchor.y;_card.anchor_bottom=anchor.y
    _card.offset_left=rect.position.x;_card.offset_right=rect.position.x+rect.size.x
    _card.offset_top=rect.position.y;_card.offset_bottom=rect.position.y+rect.size.y
    _card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.035,.07,.065,.96);style.border_color=Color("a4b992")
    style.set_border_width_all(1);style.set_corner_radius_all(12)
    style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=14;style.content_margin_bottom=14
    _card.add_theme_stylebox_override("panel",style)
    var rows:=VBoxContainer.new();rows.add_theme_constant_override("separation",4);_card.add_child(rows)
    title_label=_label(22,Color("f5dfaf"));rows.add_child(title_label)
    var header:=HBoxContainer.new();rows.add_child(header)
    stage_label=_label(16,Color("c5d7c3"));stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(stage_label)
    progress_label=_label(15,Color("e6d49c"));header.add_child(progress_label)
    info_label=_label(13,Color("e5a36a"));info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(info_label)
    board=Control.new();board.custom_minimum_size=Vector2(0,board_height());board.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(board)
    board.draw.connect(_draw_board)
    meter=Control.new();meter.custom_minimum_size=Vector2(0,24);meter.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(meter)
    meter.draw.connect(draw_meter)
    var rating:=HBoxContainer.new();rows.add_child(rating)
    var quality_column:=VBoxContainer.new();quality_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    quality_column.add_theme_constant_override("separation",0);rating.add_child(quality_column)
    stars_label=_label(26,Color("f5d477"));quality_column.add_child(stars_label)
    quality_label=_label(13,Color("e6d49c"));quality_column.add_child(quality_label)
    var price_column:=VBoxContainer.new();price_column.add_theme_constant_override("separation",0);rating.add_child(price_column)
    value_label=_label(22,Color("f5d477"));value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price_column.add_child(value_label)
    value_note_label=_label(13,Color("b1c3b5"));value_note_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price_column.add_child(value_note_label)
    feedback_label=_label(18,Color("a6e9c0"));rows.add_child(feedback_label)
    tip_label=_label(13,Color("b1c3b5"));tip_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(tip_label)
    for i in 5:
        var player:=AudioStreamPlayer.new();player.volume_db=-17;add_child(player);_players.append(player)
    _sounds["slice"]=ArcadeKit.noise(.11,.55,true)
    _sounds["swoosh"]=ArcadeKit.noise(.09,.35,true)
    _sounds["perfect"]=ArcadeKit.tone(988,1480,.16)
    _sounds["crack"]=ArcadeKit.noise(.05,.9,false)
    _sounds["snag"]=ArcadeKit.tone(150,110,.14)
    _sounds["splat"]=ArcadeKit.noise(.16,.12,false)
    _sounds["sting"]=ArcadeKit.tone(620,930,.22)
    _sounds["chomp"]=ArcadeKit.chomp()
    _sounds["clang"]=ArcadeKit.clang()
    _sounds["plop"]=ArcadeKit.sweep(260,90,.16,false)
    _sounds["rip"]=ArcadeKit.noise(.30,.35,false)
    _sounds["complete"]=ArcadeKit.tone(880,1320,.26)
    LocaleSettings.changed.connect(refresh_labels)
    _root.hide()

func _label(font_size: int,color: Color) -> Label:
    var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
    return label

func begin_pending(data: Dictionary) -> void:
    state=data.duplicate();state["active"]=true
    active=true;pending=true;_terminal_time=0;_job_key="";_fx_seen=-1
    _trail.clear();_popups.clear();_shake=0;_flash=0;_combo_shown=0
    NetworkSession.local_blade=Vector2(.5,.5);_last_blade=NetworkSession.local_blade
    _root.show();refresh_labels();board.queue_redraw()

func show_state(data: Dictionary) -> void:
    if data.is_empty(): return
    state=data.duplicate();pending=false;active=bool(state.get("active",true))
    var key: String=job_key(state)
    var fx: int=int(state.get("fx",0))
    # A finished or cancelled job's summary repeats until the host forgets it:
    # show it once for a moment, then keep it hidden.
    if not active:
        var ending: String="%s:%s:%s" % [key,fx,state.get("feedback","")]
        if ending==_ended_key and _terminal_time<=0: return
        if ending!=_ended_key: _ended_key=ending;_terminal_time=float(state.get("remaining",1.2))
    if key!=_job_key:
        _job_key=key;_fx_seen=fx if active else fx-1
    if fx!=_fx_seen:
        _fx_seen=fx
        _event(String(state.get("feedback","")),Vector2(state.get("fx_pos",Vector2(.5,.5))),int(state.get("combo",0)))
    if clock_key(state)!=_clock_key:
        _clock_key=clock_key(state);_clock=_server_clock()
    _root.show();refresh_labels();board.queue_redraw()

func is_open() -> bool:
    return active or pending

func is_interactive() -> bool:
    return active and not pending

func close() -> void:
    active=false;pending=false;state={};_terminal_time=0
    _trail.clear();_popups.clear()
    update_loops(0.0)
    if is_instance_valid(_root): _root.hide()

## The host's clock as of now: its last report plus the time since it arrived.
## The local host reads the live job, which has no arrival stamp.
func _server_clock() -> float:
    var time: float=float(state.get(clock_field(),0))
    if active and state.has("received_at"):
        time+=clampf(float(Time.get_ticks_msec())/1000.0-float(state.received_at),0,.5)
    return time

func _process(delta: float) -> void:
    _flash=maxf(0,_flash-delta);_shake=maxf(0,_shake-delta*2.2);_combo_age+=delta
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
        while not _trail.is_empty() and now-float(_trail[0].t)>ArcadeKit.TRAIL_SECONDS: _trail.pop_front()
    for index in range(_popups.size()-1,-1,-1):
        _popups[index].age=float(_popups[index].age)+delta
        if float(_popups[index].age)>=.95: _popups.remove_at(index)
    update_loops(delta)
    if _root.visible:
        board.queue_redraw();meter.queue_redraw()
        if is_open(): refresh_hint()
    if not active and not pending and _terminal_time>0:
        _terminal_time=maxf(0,_terminal_time-delta)
        if _terminal_time<=0: _root.hide()

## One host event: popup, sound, shake, flash and the combo badge.
func _event(feedback: String, at: Vector2, combo: int) -> void:
    var table: Dictionary=events()
    if not table.has(feedback): return
    var spec: Dictionary=table[feedback]
    var bad: bool=bool(spec.get("bad",false))
    _popups.append({"text":tr(String(spec.get("text","HARVEST_POP_"+feedback.to_upper()))),"p":at,"age":0.0,"color":spec.color,"size":int(spec.size)})
    _play(String(spec.sound),1.0 if bad else 1.0+clampf(float(combo-1),0,8)*.07)
    _shake=maxf(_shake,float(spec.get("shake",0)))
    _flash=.35 if bad else .18;_flash_bad=bad
    if combo>=2 and not bad:
        _combo_shown=combo;_combo_age=0
    elif bad: _combo_shown=0

func _play(sound: String, pitch: float=1.0) -> void:
    if not _sounds.has(sound): return
    var player: AudioStreamPlayer=_players[_next_player];_next_player=(_next_player+1)%_players.size()
    player.stream=_sounds[sound];player.pitch_scale=pitch;player.play()

func is_bad(feedback: String) -> bool:
    return events().has(feedback) and bool(events()[feedback].get("bad",false))

# ---------------------------------------------------------------- drawing ---

func _board_rect() -> Rect2:
    return ArcadeKit.board_rect(board.size)

func _to_board(point: Vector2) -> Vector2:
    var area: Rect2=_board_rect()
    return area.position+Vector2(point.x*area.size.x,point.y*area.size.y)

func _from_metric(point: Vector2) -> Vector2:
    return _to_board(Vector2(point.x/HarvestPattern.ASPECT,point.y))

func _unit() -> float:
    return _board_rect().size.y

func _draw_board() -> void:
    var area: Rect2=_board_rect()
    var jitter:=Vector2.ZERO
    var tremble: float=_shake*9.0+scene_tremble()
    if tremble>0:
        var t: float=float(Time.get_ticks_msec())*.001
        jitter=Vector2(sin(t*83.0),cos(t*67.0))*tremble
    board.draw_set_transform(jitter)
    draw_scene(area)
    if is_interactive():
        ArcadeKit.draw_trail(board,_trail,_to_board)
        ArcadeKit.draw_knife(board,_to_board(NetworkSession.local_blade),_trail,_to_board,_speed>=HarvestPattern.HOVER_SPEED)
    for popup in _popups:
        var age: float=float(popup.age)
        var pop: float=1.0+.35*maxf(0,1.0-age*6.0)
        var color: Color=popup.color;color.a=clampf(1.4-age*1.5,0,1)
        ArcadeKit.text(board,_to_board(popup.p)+Vector2(0,-28-age*42),String(popup.text),int(float(popup.size)*pop),color)
    if _combo_shown>=2 and _combo_age<=1.4:
        var tint: Color=Color("ffd65c").lerp(Color("ff7a3c"),clampf(float(_combo_shown-2)/6.0,0,1))
        tint.a=clampf(1.6-_combo_age,0,1)
        var pop: float=1.0+.4*maxf(0,1.0-_combo_age*5.0)
        ArcadeKit.text(board,Vector2(area.end.x-84,area.position.y+34),LocaleSettings.text("HARVEST_COMBO",{"n":_combo_shown}),int((22.0+minf(float(_combo_shown),8.0)*2.0)*pop),tint)
    if _flash>0: board.draw_rect(area.grow(8),Color(1,.3,.2,_flash*.45) if _flash_bad else Color(.85,1,.65,_flash*.35))
    board.draw_set_transform(Vector2.ZERO)

## A bar with tier marks, shared by hide integrity and cleanliness.
func draw_bar(fill: float, color: Color, marks: Array) -> void:
    var width: float=meter.size.x
    var style:=StyleBoxFlat.new();style.bg_color=Color("182c27");style.border_color=Color("496454")
    style.set_border_width_all(1);style.set_corner_radius_all(5)
    meter.draw_style_box(style,Rect2(0,7,width,13))
    meter.draw_rect(Rect2(1,8,maxf(0,(width-2)*clampf(fill,0,1)),11),color)
    for mark in marks:
        meter.draw_line(Vector2(float(mark)*width,5),Vector2(float(mark)*width,22),Color(.95,1,.85,.35),1)

func stars_text(stars: int) -> String:
    return "★".repeat(clampi(stars,0,5))+"☆".repeat(5-clampi(stars,0,5))

func star_color(stars: int) -> Color:
    return [Color("df8674"),Color("e5a36a"),Color("e5c88a"),Color("a9d696"),Color("f5d477")][clampi(stars,1,5)-1]

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
        if is_interactive(): NetworkSession.local_blade=ArcadeKit.steer(NetworkSession.local_blade,event.relative)
        get_viewport().set_input_as_handled()
        return
    # Clicks do nothing here; they are swallowed so the gun never fires.
    for action in ["fire","jump"]:
        if event.is_action_pressed(action) or event.is_action_released(action):
            get_viewport().set_input_as_handled()
            return
