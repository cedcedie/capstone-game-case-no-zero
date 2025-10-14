# Case No Zero - Godot Game Project

A narrative-driven detective game built with Godot 4.

## Project Structure

```
case-no-zero/
├── addons/                    # Godot plugins
│   ├── Tile_Set_Helper/      # Tile set management plugin
│   └── YarnSpinner-Godot/    # Dialogue system plugin
├── assets/                    # Game assets
│   ├── audio/                # Sound effects and music
│   ├── fonts/                # Font files
│   └── PNG/                  # Sprite assets
│       ├── characters/       # Character sprites
│       ├── exterior/         # Exterior environment sprites
│       ├── interior/         # Interior environment sprites
│       ├── interiorAnimations/ # Interior animation sprites
│       └── ui/               # UI elements and icons
├── data/                     # Game data files
│   └── dialogues/           # JSON dialogue files
├── dialogue/                 # Yarn dialogue files
│   ├── exterior/            # Exterior dialogue
│   └── interior/            # Interior dialogue
├── docs/                     # Documentation
│   └── plugin-screenshots/  # Plugin documentation images
├── scenes/                   # Godot scene files
│   ├── characters/          # Character scenes
│   ├── cutscene/            # Cutscene scenes
│   ├── maps/                # Map scenes
│   ├── objects/             # Interactive objects
│   └── ui/                  # UI scenes
├── scripts/                  # GDScript files
│   ├── character/           # Character scripts
│   ├── interactables/       # Interactive object scripts
│   ├── manager/             # Game management scripts
│   └── ui/                  # UI scripts
└── project.godot            # Godot project file
```

## Features

- **Dialogue System**: Uses YarnSpinner for narrative dialogue
- **Character System**: Multiple NPCs with unique interactions
- **Scene Management**: Organized scene structure for different game areas
- **Audio System**: Background music and sound effects
- **UI System**: Custom UI elements and dialogue chooser

## Development

### Prerequisites
- Godot 4.x
- Git

### Setup
1. Clone the repository
2. Open the project in Godot 4
3. Ensure all plugins are enabled in Project Settings

### Key Scripts
- `scripts/manager/lower_level_station.gd` - Main station scene manager
- `scripts/character/` - Character behavior scripts
- `scenes/ui/DialogChooser.gd` - Dialogue choice system

## File Organization

The project follows a clear organizational structure:
- **Assets** are categorized by type and usage
- **Scenes** are organized by game area and function
- **Scripts** are grouped by functionality
- **Data** files are separated from code

## License

See LICENSE file for details.
