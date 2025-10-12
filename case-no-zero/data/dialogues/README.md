# JSON Dialogues Directory

This directory contains all JSON-based dialogue files for the game, completely separate from the Yarn Spinner dialogue system.

## 📁 Structure

```
data/dialogues/
├── README.md                    # This file
├── Intro.json                   # Bedroom intro cutscene dialogue
└── npc_police_dialogue.json     # NPC Police officer dialogue
```

## 📝 File Descriptions

### `Intro.json`
- **Location**: Bedroom cutscene
- **Used by**: `scenes/cutscene/bedroom_scene.gd`
- **Purpose**: Contains the opening cutscene dialogue between Player and Celine

### `npc_police_dialogue.json`
- **Location**: Police Station
- **Used by**: `scripts/character/npc_police.gd`
- **Purpose**: Contains NPC Police officer dialogue with two states:
  - `first_interaction`: Initial conversation about jail location
  - `repeated_interaction`: Shorter reminder dialogue

## 🔧 JSON Format

All dialogue JSON files follow this structure:

```json
{
  "dialogue_key": {
    "state_name": [
      {
        "speaker": "Character Name",
        "text": "Dialogue text"
      }
    ]
  }
}
```

## 🎯 Usage in Code

To load a dialogue file:

```gdscript
func load_dialogue():
    var file: FileAccess = FileAccess.open("res://data/dialogues/your_file.json", FileAccess.READ)
    if file == null:
        push_error("Cannot open dialogue file")
        return
    
    var text: String = file.get_as_text()
    file.close()
    
    var parsed: Variant = JSON.parse_string(text)
    # Use parsed data...
```

## 🚫 Important Note

**DO NOT** place Yarn Spinner `.yarn` files in this directory. 

- **JSON dialogues** → `data/dialogues/` (this directory)
- **Yarn dialogues** → `dialogue/` (separate directory)

This separation keeps the two dialogue systems independent and organized.


