class_name NpcCatalog
extends RefCounted
## The crew living in the Mammoth base. Each entry drives the procedural look of
## a Shopkeeper and the cheeky lines it shouts; the text lives in the RO/EN
## localization as NPC_<ID>_NAME and NPC_<ID>_1..lines.
## `kind` links a keeper to a LobbyInteractable kind; "" means it only talks.

const CREW: Dictionary = {
    "gica": {"kind":"weapons","lines":8,"skin":Color("e0a57a"),"shirt":Color("4f6b3a"),"pants":Color("3b3f45"),
        "hat":"beret","hat_color":Color("2c2f33"),"hair":Color("2a2018"),"mustache":true,"belly":.18,"height":1.0,"apron":Color(),"glasses":true},
    "rucsandra": {"kind":"backpacks","lines":7,"skin":Color("efbf98"),"shirt":Color("b4436c"),"pants":Color("5a3d6e"),
        "hat":"scarf","hat_color":Color("e2b33b"),"hair":Color("9a9a9a"),"mustache":false,"belly":.24,"height":.9,"apron":Color("f3e7c9"),"glasses":true},
    "fane": {"kind":"sell","lines":7,"skin":Color("c98b62"),"shirt":Color("c8c2b0"),"pants":Color("2e3c55"),
        "hat":"cap","hat_color":Color("c4472f"),"hair":Color("3a2a1c"),"mustache":true,"belly":.32,"height":1.02,"apron":Color("6b4a32"),"glasses":false},
    "debara": {"kind":"storage","lines":6,"skin":Color("e8b48f"),"shirt":Color("6c7f8c"),"pants":Color("4b4034"),
        "hat":"beanie","hat_color":Color("2f6d6a"),"hair":Color("e9e5dc"),"mustache":true,"belly":.12,"height":.86,"apron":Color("8a7a5c"),"glasses":true},
    "nelu": {"kind":"","lines":6,"skin":Color("d79a6c"),"shirt":Color("f0d34a"),"pants":Color("2f5d8a"),
        "hat":"captain","hat_color":Color("f4f1e8"),"hair":Color("1e1a17"),"mustache":true,"belly":.28,"height":1.0,"apron":Color(),"glasses":true},
}

static func entry(id: String) -> Dictionary:
    return CREW.get(id,{})

static func for_kind(kind: String) -> String:
    for id in CREW:
        if CREW[id].kind==kind and kind!="": return id
    return ""

static func name_key(id: String) -> String:
    return "NPC_"+id.to_upper()+"_NAME"

static func line_key(id: String, index: int) -> String:
    return "NPC_"+id.to_upper()+"_"+str(index+1)

static func line_count(id: String) -> int:
    return int(entry(id).get("lines",0))

## A random line, avoiding `previous` when there is a choice.
static func random_line(id: String, rng: RandomNumberGenerator, previous: int=-1) -> int:
    var count: int=line_count(id)
    if count<=0: return -1
    var index: int=rng.randi_range(0,count-1)
    if count>1 and index==previous: index=(index+1+rng.randi_range(0,count-2))%count
    return index
