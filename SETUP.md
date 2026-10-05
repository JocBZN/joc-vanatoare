# Hunt Together

Godot 3D hunting co-op prototype for up to four players. Includes the camp lobby, Forest and Blackwater Marsh expeditions, weapons and backpack shops, individual progression, wildlife, revive, and the shared jeep and cargo system.

## Open the project

1. Clone this repository with Git, or download and extract its ZIP.
2. In Godot **4.7.2**, import `project.godot` from the repository root.
3. Let Godot import the included models, textures, and audio, then press **F5**.

The project uses Forward+ rendering and Jolt physics. Assets are included directly in Git; Git LFS is not required. Godot generates its `.godot/` cache locally.

## Play together

Choose English or Romanian in the menu. One player hosts and up to three players join through the existing ENet connection menu. Steam integration is not included yet. For connections across the internet, the host's network must allow the game's configured UDP port.

At camp, the host interacts with the fire using **E**, selects Forest or Swamp, and starts the expedition. The game waits for the connected players to load. Weapons, backpacks, loot ownership, and jeep cargo use the existing multiplayer systems.

Controls, testing, and known prototype limitations are documented in:

- [Play guide](docs/play_guide.md)
- [Swamp expedition](docs/swamp.md)
- [Architecture](docs/architecture.md)
- [Verification](docs/verification.md)
- [Art asset attribution](assets/art/ATTRIBUTION.md)
- [Forest animal attribution](assets/animals/forest/ATTRIBUTION.md)

The game remains a prototype. Some animal and hunter models still need final visual polish. Third-party asset licensing is documented in the attribution files.
