# Courtroom Scene Flow Documentation

## Overall Flow

### 1. Initialization Phase
- Courtroom scene loads
- Camera setup and positioning
- Lifebar initialized (3 lives)
- Audio setup (courtroom BGM)
- Evidence inventory listener setup
- Dialogue listener setup
- Player movement disabled

### 2. Main Dialogue Sequence
- Plays through dialogue lines from `courtroom_dialogue.json`
- Each line can have:
  - **Speaker**: Hukom, Fiscal, Miguel, Erwin, Celine
  - **Text**: Dialogue content
  - **Action**: Special actions (camera focus, gavel, objection, etc.)
  - **Choices**: Player dialogue choices
  - **Contradictable**: Can be contradicted with evidence

### 3. Evidence Presentation Phase
Triggered when dialogue line has `action: "start_evidence_presentation"`

**Flow:**
1. Show evidence inventory (courtroom mode)
2. Hide `leos_notebook` until 5 other evidence are presented
3. **Loop:**
   - Wait for evidence click
   - Present evidence branch (see below)
   - Update final evidence visibility
   - Check if all evidence presented → break
   - Ask "Present more?" → if "Tapos na" → break
4. Hide evidence inventory
5. Continue dialogue sequence

### 4. Evidence Presentation Branch (Per Evidence)

**Correct Flow:**
1. Error checks (already presented? exists in inventory?)
2. Camera → center
3. **Miguel**: "I want to present [evidence name]!"
4. **Miguel**: [testimony text]
5. Camera → judge
6. Camera → fiscal
7. **Fiscal**: [objection text] - "Tutol po!"
8. **Show objection animation** (with shake)
9. **Fiscal**: [objection_follow_up] - nagrereklamo/complaint
10. **Fiscal**: [objection_additional] - additional argument (optional)
11. Camera → player
12. **Miguel**: [counter_objection]
13. **Miguel**: [counter_additional] - additional counter (optional)
14. **Show objection animation again**
15. Camera → judge
16. **Show gavel animation**
17. **Judge**: [judge_response] - ruling after gavel
18. Camera → center
19. **Show evidence sprite** (fade in/out)
20. Add evidence to presented list

**Wrong Evidence:**
- Lose 1 life
- Show error message
- Return to evidence selection

### 5. Contradiction Phase
Triggered when dialogue line has `contradictable: true`

**Flow:**
1. Show dialogue line
2. Show choices: ["Pindutin ang pahayag", "Ipakita ang ebidensya", "Magpatuloy"]
3. **If "Pindutin ang pahayag":**
   - Player asks for clarification
   - Show follow-up dialogue
4. **If "Ipakita ang ebidensya":**
   - Show evidence inventory
   - Wait for evidence click
   - **If correct evidence:**
     - Show correct contradiction dialogue
     - Judge accepts
   - **If wrong evidence:**
     - Lose 1 life
     - Show wrong contradiction dialogue
     - Try again or continue
5. **If "Magpatuloy":**
   - Skip contradiction
   - Continue dialogue

### 6. Lifebar System
- **Starting Lives**: 3
- **Lose Life When:**
  - Wrong evidence presented for contradiction
  - Wrong evidence presented during evidence phase (if implemented)
- **Game Over**: When lives reach 0
  - Fade out to main menu

### 7. Final Phase
- After all dialogue completes
- Fade out to main menu

## Key Sequences

### Objection Sequence (Corrected)
1. Fiscal says "Tutol po!" → **Show objection animation**
2. Fiscal nagrereklamo (follow-up complaint)
3. Fiscal additional argument (optional)
4. Player counters
5. Player additional counter (optional)
6. **Show objection animation again**
7. **Show gavel animation** (camera on judge)
8. Judge makes ruling

### Evidence Selection
- Evidence inventory shown in courtroom mode
- Player clicks evidence icon
- Signal `evidence_selected_for_courtroom` emitted
- Evidence validated and presented
- `leos_notebook` hidden until 5 other evidence presented

## Camera Transitions
- **Judge**: Vector2(688.0, 152.0), Zoom 2.0
- **Center**: Vector2(688.0, 312.0), Zoom 1.3 (for evidence presentation)
- **Player**: Vector2(520.0, 440.0), Zoom 2.0
- **Fiscal**: Vector2(896.0, 440.0), Zoom 2.0
- Fast transitions: 0.5s, TRANS_QUART, EASE_OUT

## Audio
- **Courtroom Intro**: `Hammer of Justice.ogg`
- **Evidence BGM**: `Hammer of Justice.ogg`
- **Objection BGM**: `Spear of Justice.mp3`
- **Verdict BGM**: `Hammer of Justice.ogg`
- **Victory BGM**: `Spear of Justice.mp3`



