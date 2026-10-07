extends Control
## The in-game HUD, drawn in code: minimal, rounded, only what matters now.
## Bottom left: health with a fading damage trail, coins and the backpack.
## Bottom right: weapon and ammo, or a speedometer while at the wheel.
## Top: the boss bar when a boss is near or under fire, notifications, the
## lobby hint and, in multiplayer, the party with their health.
## Centre: the interaction prompt as a key cap, the animal you aim at and
## floating damage numbers. Bottom centre: control hints for the current
## situation, which fade away once they have been on screen for a while.

const Paint:=preload("res://ui/hud/hud_paint.gd")
const Icons:=preload("res://ui/hud/map_icons.gd")
const VIGNETTE:=preload("res://ui/hud/vignette.gdshader")
const MAX_HEALTH: float=100.0
const HINT_SECONDS: float=10.0
const TOAST_SECONDS: float=4.2
const BOSS_RANGE: float=150.0

## game/main.gd: where the nearby interactable and the aimed animal live.
var main
var vignette: ColorRect
var _health_shown: float=1.0
var _health_ghost: float=1.0
var _ghost_wait: float=0.0
var _last_health: int=100
var _hurt: float=0.0
var _toasts: Array=[]
var _hits: Array=[]
var _context: String=""
var _hint_clock: float=0.0
var _boss_health: Dictionary={}
var _boss_hit_at: Dictionary={}
var _boss_ghost: Dictionary={}
var _fallen_boss: Dictionary={}
var _clock: float=0.0

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vignette=ColorRect.new();vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var material:=ShaderMaterial.new();material.shader=VIGNETTE;vignette.material=material
    # Under the widgets: the red edges must never tint the numbers.
    vignette.show_behind_parent=true
    add_child(vignette)

func toast(message: String) -> void:
    if message.strip_edges().is_empty(): return
    for entry in _toasts:
        if entry.text==message: entry.time=0.0;return
    _toasts.append({"text":message,"time":0.0})
    while _toasts.size()>3: _toasts.pop_front()

func hit(damage: int) -> void:
    _hits.append({"n":damage,"time":0.0,"drift":randf_range(-18.0,18.0)})
    while _hits.size()>6: _hits.pop_front()

func _process(delta: float) -> void:
    _clock+=delta
    for entry in _toasts: entry.time+=delta
    _toasts=_toasts.filter(func(entry) -> bool: return entry.time<TOAST_SECONDS)
    for entry in _hits: entry.time+=delta
    _hits=_hits.filter(func(entry) -> bool: return entry.time<.8)
    var hunter=NetworkSession.local_hunter()
    if is_instance_valid(hunter):
        var fraction: float=clampf(hunter.health/MAX_HEALTH,0.0,1.0)
        if hunter.health<_last_health: _hurt=1.0;_ghost_wait=.45
        _last_health=hunter.health
        _health_shown=lerpf(_health_shown,fraction,1.0-exp(-14.0*delta))
        if fraction>=_health_ghost: _health_ghost=fraction
        elif _ghost_wait>0.0: _ghost_wait-=delta
        else: _health_ghost=move_toward(_health_ghost,fraction,delta*.45)
        var context: String=_context_of(hunter)
        if context!=_context: _context=context;_hint_clock=0.0
        else: _hint_clock+=delta
        var low: float=clampf((.35-fraction)/.35,0.0,1.0)
        var pulse: float=low*(.45+.2*sin(_clock*5.0))
        _hurt=maxf(0.0,_hurt-delta*1.6)
        var material: ShaderMaterial=vignette.material
        if hunter.health<=0:
            material.set_shader_parameter("tint",Color(0.08,0.08,0.09,0.85));material.set_shader_parameter("strength",.9)
        else:
            material.set_shader_parameter("tint",Color(0.75,0.05,0.03,0.9));material.set_shader_parameter("strength",maxf(pulse,_hurt*.75))
    _track_bosses(hunter,delta)
    queue_redraw()

func _context_of(hunter) -> String:
    if hunter.health<=0: return "downed"
    if hunter.busy(): return "harvest"
    if hunter.seat_index==0: return "drive"
    if NetworkSession.phase=="lobby": return "lobby"
    if hunter.riding: return "ride"
    return "foot"

## Notices bosses losing health (on any peer, from replicated health) so the
## boss bar also shows for a boss under fire further away.
func _track_bosses(hunter, delta: float) -> void:
    for id in _fallen_boss.keys():
        _fallen_boss[id].time+=delta
        if _fallen_boss[id].time>4.0: _fallen_boss.erase(id)
    for memory in [_boss_health,_boss_hit_at,_boss_ghost]:
        for id in memory.keys():
            if not NetworkSession.animals.has(id): memory.erase(id)
    for id in NetworkSession.animals:
        var animal=NetworkSession.animals[id]
        if not is_instance_valid(animal) or animal.definition==null or not animal.definition.boss: continue
        var previous: int=int(_boss_health.get(id,animal.health))
        if animal.health<previous: _boss_hit_at[id]=_clock
        if animal.dead and previous>0 and is_instance_valid(hunter) and animal.global_position.distance_to(hunter.global_position)<400.0:
            _fallen_boss[id]={"name":animal.definition.display_name,"time":0.0}
        _boss_health[id]=animal.health
        var fraction: float=float(animal.health)/float(animal.definition.max_health)
        var ghost: float=float(_boss_ghost.get(id,fraction))
        _boss_ghost[id]=fraction if fraction>=ghost else move_toward(ghost,fraction,delta*.25)

func _boss_in_focus(hunter):
    var best=null
    var best_distance: float=INF
    for id in NetworkSession.animals:
        var animal=NetworkSession.animals[id]
        if not is_instance_valid(animal) or animal.definition==null or not animal.definition.boss or animal.dead: continue
        var distance: float=animal.global_position.distance_to(hunter.global_position)
        var engaged: bool=_clock-float(_boss_hit_at.get(id,-100.0))<8.0 and distance<450.0
        if (distance<BOSS_RANGE or engaged) and distance<best_distance: best=animal;best_distance=distance
    return best

func _draw() -> void:
    var hunter=NetworkSession.local_hunter()
    if not is_instance_valid(hunter) or not is_instance_valid(hunter.inventory): return
    var screen: Vector2=get_viewport_rect().size
    var map_open: bool=main!=null and is_instance_valid(main.minimap) and main.minimap.detail
    var busy: bool=hunter.busy()
    _draw_health(hunter,screen)
    if hunter.seat_index==0 and is_instance_valid(NetworkSession.jeep): _draw_speed(screen)
    elif not busy and hunter.health>0: _draw_weapon(hunter,screen)
    _draw_top(hunter,screen)
    _draw_party(hunter)
    if not map_open:
        if not busy and hunter.health>0: _draw_prompt(hunter,screen)
        _draw_target(hunter,screen)
        _draw_hits(screen)
        _draw_hints(hunter,screen)
    if hunter.health<=0: _draw_downed(hunter,screen)

# --- Bottom left: health, coins, backpack ---------------------------------------------------

func _draw_health(hunter, screen: Vector2) -> void:
    var base:=Vector2(26.0,screen.y-58.0)
    var downed: bool=hunter.health<=0
    var low: bool=_health_shown<.3 and not downed
    var heart_size: float=18.0*(1.0+(.12*sin(_clock*8.0) if low else 0.0))
    var health_color: Color=Paint.DANGER.lerp(Paint.HEALTH,smoothstep(.2,.6,_health_shown))
    if downed:
        Paint.skull(self,base+Vector2(9,-2),18.0,Color("ff8b71"))
    else:
        Paint.heart(self,base+Vector2(9,-1),heart_size,health_color)
    Paint.text(self,base+Vector2(24,8),str(maxi(0,hunter.health)),24,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,5)
    var bar:=Rect2(base+Vector2(72,-4),Vector2(196,9))
    Paint.bar(self,bar,_health_shown,Color(0.5,0.5,0.5) if downed else health_color,_health_ghost)
    if hunter.revive_progress>0.0:
        Paint.bar(self,Rect2(bar.position+Vector2(0,13),Vector2(bar.size.x,4)),hunter.revive_progress,Color("8fd3ff"))
    # Coins and backpack, as two quiet chips under the bar.
    var inventory=hunter.inventory
    var row: float=base.y+30.0
    Paint.coin(self,Vector2(base.x+8,row-5),14.0)
    var coins: String=_group(inventory.coins)
    Paint.text(self,Vector2(base.x+22,row),coins,15,Paint.COIN,HORIZONTAL_ALIGNMENT_LEFT,-1,4)
    var x: float=base.x+30.0+Paint.text_width(coins,15)+16.0
    var used: int=inventory.used_space()
    var cap: int=inventory.capacity()
    var full: bool=used>=cap
    Paint.backpack(self,Vector2(x+6,row-6),15.0,Color("e2a95a") if not full else Paint.DANGER)
    var bag: String="%d/%d" % [used,cap]
    Paint.text(self,Vector2(x+18,row),bag,15,Paint.TEXT if not full else Paint.DANGER,HORIZONTAL_ALIGNMENT_LEFT,-1,4)
    var value: int=inventory.loot_value()
    if value>0:
        var after: float=x+24.0+Paint.text_width(bag,15)+10.0
        Paint.text(self,Vector2(after,row),"· "+LocaleSettings.text("HUD_LOOT",{"n":_group(value)}),13,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,4)

# --- Bottom right: weapon or speedometer ------------------------------------------------------

func _draw_weapon(hunter, screen: Vector2) -> void:
    var inventory=hunter.inventory
    var weapon=EquipmentCatalog.weapon(inventory.equipped_weapon_id)
    if weapon==null: return
    var right: float=screen.x-28.0
    var bottom: float=screen.y-30.0
    var cap: int=inventory.magazine_capacity(weapon.id)
    var ammo: int=inventory.ammunition()
    if inventory.reload_remaining>0.0:
        var total: float=maxf(.1,weapon.reload_seconds)
        var bar:=Rect2(Vector2(right-150,bottom-26),Vector2(150,8))
        Paint.bar(self,bar,1.0-clampf(inventory.reload_remaining/total,0.0,1.0),Paint.ACCENT)
        Paint.text(self,Vector2(right-150,bottom-36),LocaleSettings.text("HUD_RELOADING",{"n":"%.1f" % inventory.reload_remaining}),13,Paint.ACCENT,HORIZONTAL_ALIGNMENT_RIGHT,150,4)
    else:
        var tail: String="/ %d" % cap
        Paint.text(self,Vector2(right-60,bottom-12),tail,16,Paint.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,60,4)
        var empty: bool=ammo==0
        var low: bool=ammo<=maxi(1,cap/4)
        Paint.text(self,Vector2(right-160,bottom-12),str(ammo),34,Paint.DANGER if empty else Paint.ACCENT if low else Paint.TEXT,HORIZONTAL_ALIGNMENT_RIGHT,160-Paint.text_width(tail,16)-8.0,5)
        if empty: Paint.text(self,Vector2(right-220,bottom+8),LocaleSettings.text("HUD_RELOAD_KEY",{}),12,Paint.DANGER,HORIZONTAL_ALIGNMENT_RIGHT,220,4)
    Paint.text(self,Vector2(right-260,bottom-56),tr(weapon.display_name).to_upper(),13,Paint.ACCENT,HORIZONTAL_ALIGNMENT_RIGHT,260,4)
    # Two slot pips (keys 1 and 2); the one in hand is bright, the other names its gun.
    var other: int=1-inventory.active_slot
    var x: float=right
    for slot in [1,0]:
        var active: bool=inventory.active_slot==slot
        x-=20.0
        Paint.panel(self,Rect2(Vector2(x,bottom-86),Vector2(20,18)),Color(0.95,0.93,0.86,0.92) if active else Color(0,0,0,0.38),6.0,Color(1,1,1,0.25) if not active else Color(0,0,0,0),false)
        Paint.text(self,Vector2(x,bottom-72.5),str(slot+1),12,Color(0.1,0.1,0.1) if active else Paint.MUTED,HORIZONTAL_ALIGNMENT_CENTER,20,0)
        x-=6.0
    var spare=EquipmentCatalog.weapon(inventory.loadout[other])
    if spare and spare.id!=weapon.id: Paint.text(self,Vector2(x-220,bottom-72.5),tr(spare.display_name),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,214,3)

func _draw_speed(screen: Vector2) -> void:
    var truck=NetworkSession.jeep
    var center:=Vector2(screen.x-86.0,screen.y-78.0)
    var radius: float=52.0
    var kmh: float=absf(truck.speed)*3.6
    var dial: float=maxf(75.0,truck.max_forward_speed*3.6*(TruckUpgrades.NITRO_SPEED if TruckUpgrades.level(truck.upgrades,&"nitro")>0 else 1.0))
    var fraction: float=clampf(kmh/dial,0.0,1.0)
    var start: float=deg_to_rad(135.0)
    var sweep: float=deg_to_rad(270.0)
    draw_circle(center,radius+10.0,Color(0,0,0,0.32))
    draw_arc(center,radius,start,start+sweep,48,Color(1,1,1,0.16),7.0,true)
    if fraction>0.002: draw_arc(center,radius,start,start+sweep*fraction,48,Paint.ACCENT.lerp(Paint.DANGER,smoothstep(.75,1.0,fraction)),7.0,true)
    for tick in 6:
        var angle: float=start+sweep*tick/5.0
        draw_line(center+Vector2.from_angle(angle)*(radius-9.0),center+Vector2.from_angle(angle)*(radius-4.0),Color(1,1,1,0.5),1.5,true)
    Paint.text(self,center+Vector2(-50,8),str(int(round(kmh))),30,Paint.TEXT,HORIZONTAL_ALIGNMENT_CENTER,100,5)
    Paint.text(self,center+Vector2(-50,26),"km/h",11,Paint.MUTED,HORIZONTAL_ALIGNMENT_CENTER,100,3)
    var gear: String="P" if truck.parked else "R" if truck.speed<-.4 else "N" if absf(truck.speed)<.3 else "D"
    var pill:=Rect2(center+Vector2(-12,radius-8.0),Vector2(24,20))
    Paint.panel(self,pill,Paint.ACCENT if gear=="D" else Color(0.95,0.93,0.86,0.92),6.0,Color(0,0,0,0),false)
    Paint.text(self,Vector2(pill.position.x,pill.position.y+15),gear,13,Color(0.1,0.1,0.1),HORIZONTAL_ALIGNMENT_CENTER,24,0)
    Paint.steering_wheel(self,center+Vector2(-radius-28.0,radius-4.0),18.0,Color(1,1,1,0.7))
    # Nitro tank, once the boosters are fitted: fills while idle, drains while burning.
    if TruckUpgrades.level(truck.upgrades,&"nitro")>0:
        var tank:=Rect2(center+Vector2(-radius-40.0,radius+16.0),Vector2(radius*2.0+80.0,8.0))
        draw_rect(tank,Color(0,0,0,0.42))
        draw_rect(Rect2(tank.position,Vector2(tank.size.x*clampf(truck.nitro,0.0,1.0),tank.size.y)),Color("ff9a3a") if truck.boosting else Color("f2c94c"))
        Paint.text(self,tank.position+Vector2(0,-3),tr("HUD_NITRO"),10,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,3)
    # Rotor fuel and the gramophone's recharge sit under it.
    var bar_y: float=radius+36.0
    if TruckUpgrades.level(truck.upgrades,&"rotor")>0:
        var fuel:=Rect2(center+Vector2(-radius-40.0,bar_y),Vector2(radius*2.0+80.0,8.0))
        draw_rect(fuel,Color(0,0,0,0.42))
        draw_rect(Rect2(fuel.position,Vector2(fuel.size.x*clampf(truck.rotor_fuel,0.0,1.0),fuel.size.y)),Color("8fd3ff") if truck.rotor_on else Color("e9e2cf"))
        Paint.text(self,fuel.position+Vector2(0,-3),tr("HUD_ROTOR"),10,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,3)
        bar_y+=20.0
    if TruckUpgrades.level(truck.upgrades,&"horn")>0:
        var horn:=Rect2(center+Vector2(-radius-40.0,bar_y),Vector2(radius*2.0+80.0,8.0))
        draw_rect(horn,Color(0,0,0,0.42))
        var ready: float=1.0-clampf(truck.horn_cooldown/TruckUpgrades.HORN_COOLDOWN,0.0,1.0)
        draw_rect(Rect2(horn.position,Vector2(horn.size.x*ready,horn.size.y)),Color("d9b24a") if ready>=1.0 else Color("8d7f86"))
        Paint.text(self,horn.position+Vector2(0,-3),tr("HUD_HORN"),10,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1,3)

# --- Top: boss, notifications, lobby, party -------------------------------------------------

func _draw_top(hunter, screen: Vector2) -> void:
    var middle: float=screen.x*.5
    var y: float=20.0
    var boss=_boss_in_focus(hunter)
    if boss:
        var width: float=460.0
        var fraction: float=float(boss.health)/float(boss.definition.max_health)
        Icons.draw_crown(self,Vector2(middle-width*.5+10,y+10),20.0)
        Paint.text(self,Vector2(middle-width*.5+28,y+16),tr(boss.definition.display_name).to_upper(),15,Icons.GOLD,HORIZONTAL_ALIGNMENT_LEFT,width-140.0,5)
        Paint.text(self,Vector2(middle+width*.5-130,y+16),"%s / %s" % [_group(boss.health),_group(boss.definition.max_health)],12,Paint.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,130,4)
        Paint.bar(self,Rect2(Vector2(middle-width*.5,y+24),Vector2(width,10)),fraction,Color("e0482f"),float(_boss_ghost.get(boss.animal_id,fraction)))
        y+=50.0
    elif not _fallen_boss.is_empty():
        var fallen: Dictionary=_fallen_boss.values()[0]
        var alpha: float=clampf(4.0-float(fallen.time),0.0,1.0)
        Icons.draw_crown(self,Vector2(middle,y+8),22.0)
        Paint.text(self,Vector2(middle-260,y+38),LocaleSettings.text("HUD_BOSS_DOWN",{"name":tr(fallen.name)}),17,Color(Icons.GOLD,alpha),HORIZONTAL_ALIGNMENT_CENTER,520,5)
        y+=56.0
    if NetworkSession.phase=="lobby":
        var hint: String=tr("LOBBY_HOST_HINT" if NetworkSession.is_host() else "WAIT_HOST")
        var w: float=Paint.text_width(hint,14)+36.0
        Paint.panel(self,Rect2(Vector2(middle-w*.5,y),Vector2(w,30)),Paint.PANEL,15.0)
        Paint.text(self,Vector2(middle-w*.5,y+20),hint,14,Paint.TEXT,HORIZONTAL_ALIGNMENT_CENTER,w,0)
        y+=40.0
    for entry in _toasts:
        var age: float=float(entry.time)
        var alpha: float=minf(clampf(age/.18,0.0,1.0),clampf((TOAST_SECONDS-age)/.5,0.0,1.0))
        var text: String=entry.text
        var w: float=minf(screen.x-120.0,Paint.text_width(text,15)+40.0)
        var rect:=Rect2(Vector2(middle-w*.5,y-(1.0-alpha)*8.0),Vector2(w,32))
        Paint.panel(self,rect,Color(0.05,0.07,0.065,0.7*alpha),16.0)
        draw_circle(rect.position+Vector2(16,16),3.5,Color(Paint.ACCENT,alpha))
        Paint.text(self,Vector2(rect.position.x+12,rect.position.y+21),text,15,Color(Paint.TEXT,alpha),HORIZONTAL_ALIGNMENT_CENTER,w-16.0,0)
        y+=38.0

func _draw_party(hunter) -> void:
    if NetworkSession.players.size()<=1 and NetworkSession.mode=="solo": return
    var y: float=26.0
    Paint.text(self,Vector2(22,y),NetworkSession.status_text(),11,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,320,3)
    y+=20.0
    for peer in NetworkSession.players:
        var friend=NetworkSession.players[peer]
        if friend==hunter or not is_instance_valid(friend): continue
        var color: Color=Icons.PARTY
        draw_circle(Vector2(28,y-4),4.0,color)
        Paint.text(self,Vector2(38,y),friend.player_name,13,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,120,4)
        var fraction: float=clampf(friend.health/MAX_HEALTH,0.0,1.0)
        Paint.bar(self,Rect2(Vector2(162,y-8),Vector2(70,5)),fraction,Paint.DANGER.lerp(Paint.HEALTH,smoothstep(.2,.6,fraction)))
        if friend.health<=0: Paint.skull(self,Vector2(246,y-5),12.0,Color("ff8b71"))
        elif friend.seat_index==0: Paint.steering_wheel(self,Vector2(246,y-5),12.0,Color(1,1,1,0.8))
        elif friend.get("riding")==true: Icons.draw_truck(self,Vector2(246,y-5),11.0,0.0)
        y+=22.0

# --- Centre: prompt, aimed animal, damage --------------------------------------------------------

func _draw_prompt(hunter, screen: Vector2) -> void:
    if not hunter.control_enabled: return
    var text: String=""
    var progress: float=-1.0
    if hunter.seat_index==0:
        # At the wheel the way out only matters once the truck can be left.
        if not is_instance_valid(NetworkSession.jeep) or NetworkSession.jeep.linear_velocity.length()>2.0: return
        text=tr("jeep_exit")
    elif main!=null and main.nearby:
        var nearby=main.nearby
        text=nearby.localized_name()
        if nearby.interaction_kind=="revive":
            var target=NetworkSession.players.get(nearby.target_peer())
            if target: text=LocaleSettings.text("HUD_REVIVE",{"name":target.player_name});progress=target.revive_progress
    if text.is_empty(): return
    var lines: PackedStringArray=text.split("\n")
    var title: String=lines[0]
    var detail: String=" · ".join(lines.slice(1)) if lines.size()>1 else ""
    var w: float=maxf(Paint.text_width(title,15),Paint.text_width(detail,12))+64.0
    w=minf(w,screen.x*.6)
    var h: float=36.0 if detail.is_empty() else 52.0
    var rect:=Rect2(Vector2(screen.x*.5-w*.5,screen.y*.5+70.0),Vector2(w,h))
    Paint.panel(self,rect,Paint.PANEL,h*.5 if detail.is_empty() else 14.0)
    var key_at:=Vector2(rect.position.x+12,rect.position.y+18)
    var key_w: float=Paint.key_cap(self,key_at,"E")
    if progress>=0.0: draw_arc(key_at+Vector2(key_w*.5,0),17.0,-PI*.5,-PI*.5+TAU*progress,32,Color("8fd3ff"),3.0,true)
    Paint.text(self,Vector2(rect.position.x+key_w+22,rect.position.y+23),title,15,Paint.TEXT,HORIZONTAL_ALIGNMENT_LEFT,w-key_w-34.0,0)
    if not detail.is_empty(): Paint.text(self,Vector2(rect.position.x+key_w+22,rect.position.y+41),detail,12,Paint.MUTED,HORIZONTAL_ALIGNMENT_LEFT,w-key_w-34.0,0)

func _draw_target(hunter, screen: Vector2) -> void:
    if main==null or not is_instance_valid(main.target_animal): return
    var animal=main.target_animal
    if animal.dead or animal.definition.boss: return
    var at:=Vector2(screen.x*.5,screen.y*.5+34.0)
    var color: Color=Icons.AGGRESSIVE.lightened(.2) if animal.definition.aggressive else Paint.TEXT
    Paint.text(self,at+Vector2(-100,0),tr(animal.definition.display_name),13,color,HORIZONTAL_ALIGNMENT_CENTER,200,4)
    var fraction: float=float(animal.health)/float(animal.definition.max_health)
    Paint.bar(self,Rect2(at+Vector2(-50,6),Vector2(100,5)),fraction,Color("e0482f") if animal.definition.aggressive else Paint.HEALTH)

func _draw_hits(screen: Vector2) -> void:
    for entry in _hits:
        var t: float=float(entry.time)/.8
        var at:=Vector2(screen.x*.5+18.0+float(entry.drift)*t,screen.y*.5-16.0-34.0*t)
        Paint.text(self,at,str(entry.n),16 if entry.n<60 else 20,Color(1,0.86,0.4,1.0-t*t),HORIZONTAL_ALIGNMENT_LEFT,-1,5)

# --- Bottom centre: hints -----------------------------------------------------------------

const HINTS: Dictionary={
    "foot":[["WASD","HINT_MOVE"],["SHIFT","HINT_SPRINT"],["SPACE","HINT_JUMP"],["RMB","HINT_AIM"],["LMB","HINT_FIRE"],["E","HINT_USE"],["B","HINT_BAG"],["M","HINT_MAP"]],
    "ride":[["WASD","HINT_WALK_DECK"],["RMB","HINT_AIM"],["LMB","HINT_FIRE"],["R","HINT_RELOAD"],["E","HINT_LADDER"],["M","HINT_MAP"]],
    "lobby":[["WASD","HINT_MOVE"],["E","HINT_USE"],["B","HINT_BAG"],["ESC","HINT_MENU"]],
    "drive":[["W S","HINT_THROTTLE"],["A D","HINT_STEER"],["SPACE","HINT_BRAKE"],["TAB","HINT_ROUTE"],["E","HINT_EXIT"],["V","HINT_FLIP"],["M","HINT_MAP"]],
}

func _draw_hints(hunter, screen: Vector2) -> void:
    var y: float=screen.y-22.0
    if _context in ["harvest","downed"]:
        var line: String=tr("HARVEST_CONTROLS" if _context=="harvest" else "DOWNED_HELP")
        Paint.text(self,Vector2(0,y),line,13,Paint.MUTED,HORIZONTAL_ALIGNMENT_CENTER,screen.x,4)
        return
    var alpha: float=clampf((HINT_SECONDS-_hint_clock)/1.5,0.0,1.0)
    if alpha<=0.0 or not HINTS.has(_context): return
    # The row must stay clear of the health block and the weapon block; the
    # most obvious keys give way first on narrow screens or long translations.
    var entries: Array=HINTS[_context].duplicate()
    var room: float=screen.x-2.0*330.0
    while _hint_width(entries)>room and entries.size()>3:
        var dropped: bool=false
        for key in ["SPACE","SHIFT","WASD","V"]:
            for entry in entries:
                if entry[0]==key: entries.erase(entry);dropped=true;break
            if dropped: break
        if not dropped: entries.pop_back()
    var x: float=screen.x*.5-_hint_width(entries)*.5
    for entry in entries:
        var w: float=Paint.key_cap(self,Vector2(x,y-4),entry[0],11,alpha*.92)
        x+=w+5.0
        Paint.text(self,Vector2(x,y+1),tr(entry[1]),11,Color(Paint.TEXT,alpha*.9),HORIZONTAL_ALIGNMENT_LEFT,-1,4)
        x+=Paint.text_width(tr(entry[1]),11)+14.0

func _hint_width(entries: Array) -> float:
    var total: float=0.0
    for entry in entries: total+=maxf(22.0,Paint.text_width(entry[0],11)+12.0)+5.0+Paint.text_width(tr(entry[1]),11)+14.0
    return total-14.0

func _draw_downed(hunter, screen: Vector2) -> void:
    var at:=Vector2(0,screen.y*.5-40.0)
    Paint.text(self,at,tr("HUD_DOWNED").to_upper(),30,Color("ff8b71"),HORIZONTAL_ALIGNMENT_CENTER,screen.x,6)
    if hunter.revive_progress>0.0:
        Paint.text(self,at+Vector2(0,30),LocaleSettings.text("HUD_BEING_REVIVED",{"n":roundi(hunter.revive_progress*100)}),14,Color("8fd3ff"),HORIZONTAL_ALIGNMENT_CENTER,screen.x,4)
        Paint.bar(self,Rect2(Vector2(screen.x*.5-110,at.y+42),Vector2(220,6)),hunter.revive_progress,Color("8fd3ff"))

static func _group(value: int) -> String:
    var digits: String=str(absi(value))
    var out: String=""
    while digits.length()>3:
        out=" "+digits.substr(digits.length()-3)+out
        digits=digits.substr(0,digits.length()-3)
    return ("-" if value<0 else "")+digits+out
