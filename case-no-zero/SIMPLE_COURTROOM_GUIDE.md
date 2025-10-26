# Simple Courtroom Guide 🎯

## How It Works (Super Simple!)

### 1. **Start Scene**
- Courtroom loads
- Shows first dialogue line
- Camera focuses on speaker

### 2. **Show Dialogue**
- Speaker says their line
- Camera zooms to them (1.5x zoom)
- Text appears on screen

### 3. **Wait for Input**
- Game waits for you to press SPACE or ENTER
- Shows "waiting_for_input = true"

### 4. **Next Button Pressed**
- You press SPACE/ENTER
- Game moves to next line (current_line += 1)
- Shows next dialogue

### 5. **Repeat Until Done**
- Keeps going until all dialogue is shown
- Then ends the courtroom sequence

## Controls 🎮

- **SPACE or ENTER**: Next dialogue line
- **F1**: Unlock all checkpoints (debug)
- **F2**: Unlock all evidence (debug)
- **F3**: Reset courtroom (debug)
- **F4**: Add life (debug)

## Camera System 📷

- **Characters DON'T move** - they stay in their positions
- **Camera DOES move and zoom** to focus on speakers
- **Judge**: Camera moves to judge, zooms 1.5x
- **Prosecutor**: Camera moves to prosecutor, zooms 1.5x
- **Defendant**: Camera moves to defendant, zooms 1.5x
- **Witness**: Camera moves to witness, zooms 1.5x
- **Return**: Camera returns to center, normal zoom

## That's It! 🎯

Super simple:
1. Load dialogue
2. Show line
3. Wait for SPACE/ENTER
4. Next line
5. Repeat until done

No complex systems, no confusion!
