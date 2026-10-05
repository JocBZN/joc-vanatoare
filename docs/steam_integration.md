# Punctul de integrare Steam

Proiectul nu instalează și nu apelează Steam API.
`NetworkSession.attach_peer(peer: MultiplayerPeer, hosting: bool)` este granița transportului.
RPC-urile și gameplay-ul pot folosi un peer furnizat ulterior de un plugin Steam compatibil.

Host: închide transportul precedent prin `leave_game()`, setează numele și atașează peer-ul ca host.
Client: `attach_peer(peer, false)` curăță replicile solo și începe așteptarea conexiunii.
Semnalele Godot `connected_to_server`, `peer_connected`, `peer_disconnected`, `server_disconnected`
trebuie să rămână emise de transport. Peer-ul hostului trebuie să aibă ID-ul Godot 1.
Păstrează canalele 0, 1, 2 și 3 și calea autoload-ului `/root/NetworkSession`.

Pentru identitatea Steam, adaptează validarea din `_register()` și `identities` folosind identitatea
verificată de transport. Acum `_register()` acceptă UUID-ul anonim de 32 caractere din LocaleSettings;
nu îl trata ca autentificare Steam. Portbagajul și inventarele folosesc deja identitatea stabilă,
deci nu trebuie legate de ID-ul temporar ENet.

Meniul pentru lobby-uri Steam / invitații va înlocui alegerea manuală IP + UDP.
Verifică separat reconectarea, conturile, invitațiile și distribuirea build-ului cu Steam.
Nu există aici Steam App ID, Steam SDK, achievements, cloud save sau host migration.
