# Case No Zero - Godot Game Project

A narrative-driven detective game built with Godot 4.

## Project Structure

```
case-no-zero/
├── assets/                    # Game assets
│   ├── audio/                # Sound effects and music
│   │   ├── music/           # Background music
│   │   └── sfx/             # Sound effects
│   ├── fonts/                # Font files
│   └── sprites/              # Sprite assets
│       ├── characters/       # Character sprites
│       ├── environments/     # Environment sprites
│       └── ui/               # UI elements and icons
├── data/                     # Game data files
│   └── dialogues/           # JSON dialogue files
├── docs/                     # Documentation
│   └── plugin-screenshots/  # Plugin documentation images
├── scenes/                   # Godot scene files
│   ├── characters/          # Character scenes
│   ├── cutscenes/           # Cutscene scenes
│   ├── environments/        # Environment/map scenes
│   ├── objects/             # Interactive objects
│   └── ui/                  # UI scenes
├── scripts/                  # GDScript files
│   ├── characters/          # Character scripts
│   ├── environments/        # Environment/level scripts
│   ├── interactables/       # Interactive object scripts
│   ├── managers/            # Game management scripts
│   └── ui/                  # UI scripts
└── project.godot            # Godot project file
```

## Features

- **Dialogue System**: Uses JSON-based dialogue system with choice mechanics
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
3. The project uses a custom JSON-based dialogue system

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
