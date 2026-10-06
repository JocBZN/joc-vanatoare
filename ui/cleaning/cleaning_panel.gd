extends KnifePanel
## The camp hide cleaner. The drum at the bottom tumbles the raw hide and flings
## whatever is stuck to it into the air: slice flesh, fat, burrs and sinew before
## they fall back on the hide, but leave the stones and the hide itself alone.

const EVENTS: Dictionary={
    "flesh":{"color":Color("ff8a7a"),"sound":"slice","size":26,"text":"CLEAN_POP_FLESH"},
    "fat":{"color":Color("fff1b0"),"sound":"slice","size":26,"text":"CLEAN_POP_FAT"},
    "burr":{"color":Color("cfe6b9"),"sound":"slice","size":26,"text":"CLEAN_POP_BURR"},
    "sinew":{"color":Color("f4efd8"),"sound":"perfect","size":28,"text":"CLEAN_POP_SINEW"},
    "chop":{"color":Color("ffb35c"),"sound":"crack","size":24,"text":"CLEAN_POP_CHOP"},
    "clang":{"color":Color("b8c4cc"),"sound":"clang","size":32,"bad":true,"shake":.5,"text":"CLEAN_POP_CLANG"},
    "tear":{"color":Color("ff4a3a"),"sound":"rip","size":34,"bad":true,"shake":.8,"text":"CLEAN_POP_TEAR"},
    "missed":{"color":Color("d79a6a"),"sound":"plop","size":24,"bad":true,"text":"CLEAN_POP_MISSED"},
    "complete":{"color":Color("ffd65c"),"sound":"complete","size":40,"text":"CLEAN_POP_COMPLETE"},
}
## What the drum throws off each species, beyond plain flesh and fat.
const BURR_SKIN: Dictionary={&"deer":"tick",&"bear":"honey",&"boar":"mud",&"frog":"algae",&"turtle":"algae",&"snake":"algae",&"crocodile":"algae",&"ancient_crocodile":"algae",&"ancient_bear":"honey",&"albino_crocodile":"algae"}

var _pieces: Array=[]
var _pieces_seed: int=-1
var _drum: AudioStreamPlayer

func events() -> Dictionary: return EVENTS
func job_key(data: Dictionary) -> String: return str(data.get("token",0))
func clock_key(data: Dictionary) -> String: return job_key(data)
func clock_field() -> String: return "time"
func card_anchor() -> Vector2: return Vector2(.5,.5)
func card_rect() -> Rect2: return Rect2(-410,-345,820,690)
func board_height() -> float: return 400.0

func _ready() -> void:
    super._ready()
    name="CleaningPanel"
    _drum=AudioStreamPlayer.new();_drum.volume_db=-30;_drum.stream=ArcadeKit.loop(2207,.08,55.0,9000.0);add_child(_drum)

func begin_cleaning(item_id: String) -> void:
    begin_pending({"item":item_id})

func update_loops(_delta: float) -> void:
    if not is_instance_valid(_drum): return
    if is_interactive() and not _drum.playing: _drum.play()
    elif not is_interactive() and _drum.playing: _drum.stop()

func pieces() -> Array:
    var seed: int=int(state.get("seed",-1))
    if seed!=_pieces_seed:
        _pieces_seed=seed
        _pieces=CleaningPattern.pieces(seed,float(state.get("difficulty",0)),bool(state.get("fatty",false))) if seed>=0 else []
    return _pieces

func scene_tremble() -> float:
    return 1.2 if is_interactive() else 0.0

# ---------------------------------------------------------------- drawing ---

func draw_scene(area: Rect2) -> void:
    var t: float=float(Time.get_ticks_msec())*.001
    # The machine's mouth: dark steel with rivets.
    var shell:=StyleBoxFlat.new()
    shell.bg_color=Color("1d2526");shell.border_color=Color("6f7f7a")
    shell.set_border_width_all(3);shell.set_corner_radius_all(16)
    board.draw_style_box(shell,area.grow(8))
    for k in 8:
        var x: float=area.position.x+area.size.x*(float(k)+.5)/8.0
        board.draw_circle(Vector2(x,area.position.y+6),3,Color("8a9792"))
    var kind: StringName=StringName(String(state.get("kind","rabbit")))
    var coat: Color=COAT_COLORS.get(kind,Color("86705c"))
    _draw_drum(area,coat,t)
    if not is_interactive(): return
    var all: Array=pieces()
    var done: int=int(state.get("done",0))
    var cracked: int=int(state.get("cracked",0))
    for index in all.size():
        if done&(1<<index): continue
        var piece: Dictionary=all[index]
        if not CleaningPattern.airborne(piece,_clock): continue
        var at: Vector2=_to_board(CleaningPattern.position(piece,_clock))
        var turn: float=float(piece.spin)*(_clock-float(piece.t))
        _draw_piece(int(piece.kind),at,turn,coat,kind,cracked&(1<<index)!=0,t)
    # Session clock along the top edge.
    var fill: float=clampf(_clock/maxf(1.0,float(state.get("duration",1))),0,1)
    board.draw_rect(Rect2(area.position+Vector2(14,14),Vector2(area.size.x-28,6)),Color(0,0,0,.4))
    board.draw_rect(Rect2(area.position+Vector2(14,14),Vector2((area.size.x-28)*fill,6)),Color("a9d696"))

## The tumbling drum: rolling slats and the hide flopping around inside.
func _draw_drum(area: Rect2, coat: Color, t: float) -> void:
    var top: float=area.position.y+area.size.y*.86
    var drum:=Rect2(area.position.x+10,top,area.size.x-20,area.end.y-top+4)
    board.draw_rect(drum,Color("3a2c22"))
    var speed: float=2.6 if is_interactive() else .6
    for k in 14:
        var x: float=drum.position.x+fposmod(float(k)/14.0*drum.size.x+t*speed*60.0,drum.size.x)
        board.draw_line(Vector2(x,drum.position.y),Vector2(x-14,drum.end.y),Color("5a4636"),4.0)
    var bob: float=sin(t*7.0)*6.0
    var hide_at:=Vector2(drum.get_center().x+sin(t*2.3)*drum.size.x*.25,drum.position.y+drum.size.y*.45+bob)
    board.draw_circle(hide_at,drum.size.y*.42,coat.darkened(.15))
    board.draw_circle(hide_at+Vector2(drum.size.y*.35,-4),drum.size.y*.3,coat)
    board.draw_line(Vector2(drum.position.x,drum.position.y),Vector2(drum.end.x,drum.position.y),Color("8a9792"),4.0)

func _draw_piece(kind: int, at: Vector2, turn: float, coat: Color, species: StringName, cracked: bool, t: float) -> void:
    var r: float=_unit()*float(CleaningPattern.RADIUS[kind])
    var spin:=Vector2(cos(turn),sin(turn))
    match kind:
        CleaningPattern.JUNK_FLESH:
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,.8,1.1,.7,1.0,.85]),Color("a8323a"))
            board.draw_line(at-spin*r*.5,at+spin*r*.3,Color("e07a72"),3.0,true)
        CleaningPattern.JUNK_FAT:
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,1.05,.9,1.0,1.1,.95]),Color("f2e3a0"))
            board.draw_circle(at+Vector2(-r*.3,-r*.3),r*.25,Color(1,1,.92,.7))
        CleaningPattern.JUNK_BURR: _draw_burr(at,r,turn,String(BURR_SKIN.get(species,"burr")),t)
        CleaningPattern.JUNK_SINEW:
            var gap: Vector2=Vector2(-spin.y,spin.x)*(r*.35 if cracked else 0.0)
            for half in [-1.0,1.0]:
                var offset: Vector2=spin*r*.55*half+gap*half
                board.draw_line(at+offset-spin*r*.5,at+offset+spin*r*.5,Color("f4efd8"),7.0,true)
                board.draw_line(at+offset-spin*r*.4,at+offset+spin*r*.4,Color("c9b8a0"),2.0,true)
        CleaningPattern.STONE:
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,.75,.95,.8,1.05,.7,.9]),Color("7b8187"))
            board.draw_circle(at+Vector2(-r*.25,-r*.3),r*.22,Color(1,1,1,.25))
        CleaningPattern.PELT:
            # The hide itself flopping out of the drum: do NOT cut it.
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,.85,1.15,.9,1.05,.8,1.1,.95]),coat)
            for k in 12:
                var angle: float=turn+TAU*float(k)/12.0
                var edge: Vector2=at+Vector2(cos(angle),sin(angle))*r*.95
                board.draw_line(edge,edge+Vector2(cos(angle),sin(angle))*6,coat.lightened(.25),2.0,true)
            board.draw_arc(at,r*1.12,0,TAU,32,Color(1,.35,.25,.55+.3*sin(t*12.0)),2.0,true)

func _draw_burr(at: Vector2, r: float, turn: float, skin: String, t: float) -> void:
    match skin:
        "tick":
            for leg in 3:
                for s in [-1.0,1.0]:
                    board.draw_line(at+Vector2(s*r*.4,float(leg-1)*r*.45),at+Vector2(s*r*1.25,float(leg-1)*r*.6+sin(t*12.0+float(leg))*2.0),Color(.18,.1,.06),1.5,true)
            board.draw_circle(at,r*.75,Color("5a3a22"))
        "honey":
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,.9,1.1,.95]),Color(.92,.62,.12,.9))
            board.draw_circle(at+Vector2(-r*.3,-r*.3),r*.2,Color(1,.95,.7,.7))
        "mud":
            board.draw_colored_polygon(_blob(at,r,turn,[1.0,.7,1.0,.85,.75]),Color("5b4632"))
        "algae":
            for k in 4:
                var angle: float=turn+float(k)*.8
                board.draw_line(at,at+Vector2(cos(angle),sin(angle))*r*1.2,Color("5f8a3a"),4.0,true)
        _:
            board.draw_circle(at,r*.7,Color("6f7f3a"))
            for k in 10:
                var angle: float=turn+TAU*float(k)/10.0
                board.draw_line(at,at+Vector2(cos(angle),sin(angle))*r*1.15,Color("9db05a"),1.5,true)

func _blob(at: Vector2, r: float, turn: float, shape: Array) -> PackedVector2Array:
    var points:=PackedVector2Array()
    for k in shape.size():
        var angle: float=turn+TAU*float(k)/float(shape.size())
        points.append(at+Vector2(cos(angle),sin(angle))*r*float(shape[k]))
    return points

## Cleanliness: falls with every piece that lands back and every bad cut.
func draw_meter() -> void:
    if pending: return
    var clean: float=float(state.get("clean",1.0))
    var penalty: int=CleaningPattern.star_penalty(clean)
    draw_bar(clean,[Color("8fd98a"),Color("e5c88a"),Color("df8674")][penalty],[.6,.85])

# ----------------------------------------------------------------- labels ---

func refresh_labels() -> void:
    if not is_instance_valid(title_label) or state.is_empty(): return
    title_label.text=tr("CLEAN_TITLE")
    var item: LootDefinition=AnimalCatalog.loot(StringName(String(state.get("item",""))))
    stage_label.text=item.localized_name() if item else ""
    progress_label.text="" if pending else LocaleSettings.text("CLEAN_PROGRESS",{"done":int(state.get("cleaned",0)),"total":int(state.get("junk",0))})
    info_label.text=tr("CLEAN_INFO")
    var stars: int=clampi(int(state.get("stars",item.stars if item else 5)),1,5)
    stars_label.text=stars_text(stars)
    stars_label.add_theme_color_override("font_color",star_color(stars))
    quality_label.text=tr("HARVEST_PREPARING") if pending else LocaleSettings.text("CLEAN_RATING",{"percent":int(round(float(state.get("clean",1.0))*100.0)),"quality":tr("HARVEST_STARS_"+str(stars))})
    quality_label.add_theme_color_override("font_color",star_color(stars))
    value_label.text=tr("HARVEST_PRICE_PENDING") if pending else LocaleSettings.text("PRICE",{"n":int(state.get("value",0))})
    value_label.add_theme_color_override("font_color",star_color(stars))
    value_note_label.text="" if pending else LocaleSettings.text("CLEAN_RAW_VALUE",{"n":int(state.get("raw_value",0))})
    refresh_hint()

func refresh_hint() -> void:
    var feedback: String=String(state.get("feedback",""))
    feedback_label.add_theme_color_override("font_color",Color("f09b7d") if is_bad(feedback) or feedback=="cancelled" else Color("a6e9c0"))
    if not active and not pending:
        if feedback=="complete":
            var result: LootDefinition=AnimalCatalog.loot(StringName(String(state.get("result",""))))
            feedback_label.text=LocaleSettings.text("CLEAN_FEEDBACK_COMPLETE",{"item":result.localized_name() if result else ""})
            tip_label.text=tr("CLEAN_DONE_TIP")
        else:
            feedback_label.text=tr("CLEAN_FEEDBACK_"+feedback.to_upper()) if not feedback.is_empty() else ""
            tip_label.text=""
        return
    tip_label.text=tr("CLEAN_TIP")
    if pending: feedback_label.text="";return
    feedback_label.text=tr("CLEAN_FEEDBACK_"+feedback.to_upper()) if not feedback.is_empty() else tr("CLEAN_HINT")
