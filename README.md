# 🎲 My Ludo — Complete Deep Architecture, System Flow & Source Code Specification

An exhaustive, production-grade technical specification detailing system architecture, execution flow diagrams, complete functionality mechanics, low-level data structures, state matrices, network synchronization, and line-by-line Dart source code explanations for **My Ludo**.

---

## 📌 Table of Contents
1. [System Architecture](#1-system-architecture)
2. [Complete System Flow & Execution Sequence](#2-complete-system-flow--execution-sequence)
   - [2.1 App Initialization Flow](#21-app-initialization-flow)
   - [2.2 Pass & Play (Local) Turn Flow](#22-pass--play-local-turn-flow)
   - [2.3 Computer (AI Bot) Execution Flow](#23-computer-ai-bot-execution-flow)
   - [2.4 2v2 Team Up Flow](#24-2v2-team-up-flow)
   - [2.5 Online Multiplayer Network Sync Flow](#25-online-multiplayer-network-sync-flow)
   - [2.6 Step-by-Step Stepping & Capture Rewind Physics Flow](#26-step-by-step-stepping--capture-rewind-physics-flow)
3. [Complete Functionality Mechanics](#3-complete-functionality-mechanics)
   - [3.1 Ludo King Standard Game Rules](#31-ludo-king-standard-game-rules)
   - [3.2 Board Geometry & Pixel Coordinate Mathematics](#32-board-geometry--pixel-coordinate-mathematics)
   - [3.3 Token Overlap & Dynamic Stacking Engine](#33-token-overlap--dynamic-stacking-engine)
   - [3.4 20-Color Theme Token System](#34-20-color-theme-token-system)
   - [3.5 Multi-Player Ranking & Game Completion Engine](#35-multi-player-ranking--game-completion-engine)
   - [3.6 Audio Synthesis & Haptic Feedback System](#36-audio-synthesis--haptic-feedback-system)
   - [3.7 Post-Game Archive & Database Cleanup Protocol](#37-post-game-archive--database-cleanup-protocol)
4. [Exhaustive Line-by-Line Dart File Breakdown](#4-exhaustive-line-by-line-dart-file-breakdown)
   - [4.1 lib/main.dart](#41-libmaindart)
   - [4.2 lib/utils/constants.dart](#42-libutilsconstantsdart)
   - [4.3 lib/utils/room_code_generator.dart](#43-libutilsroom_code_generatordart)
   - [4.4 lib/models/dice.dart](#44-libmodelsdicedart)
   - [4.5 lib/models/player.dart](#45-libmodelsplayerdart)
   - [4.6 lib/models/game_state.dart](#46-libmodelsgame_statedart)
   - [4.7 lib/game/board_config.dart](#47-libgameboard_configdart)
   - [4.8 lib/game/ai_player.dart](#48-libgameai_playerdart)
   - [4.9 lib/services/sound_service.dart](#49-libservicessound_servicedart)
   - [4.10 lib/services/game_service.dart](#410-libservicesgame_servicedart)
   - [4.11 lib/services/online_service.dart](#411-libservicesonline_servicedart)
   - [4.12 lib/firebase_options.dart](#412-libfirebase_optionsdart)
   - [4.13 lib/ui/theme.dart](#413-libuithemedart)
   - [4.14 lib/ui/widgets/board_painter.dart](#414-libuiwidgetsboard_painterdart)
   - [4.15 lib/ui/widgets/dice_widget.dart](#415-libuiwidgetsdice_widgetdart)
   - [4.16 lib/ui/widgets/token_widget.dart](#416-libuiwidgetstoken_widgetdart)
   - [4.17 lib/ui/widgets/player_avatar_widget.dart](#417-libuiwidgetsplayer_avatar_widgetdart)
   - [4.18 lib/ui/widgets/player_chip_widget.dart](#418-libuiwidgetsplayer_chip_widgetdart)
   - [4.19 lib/ui/widgets/color_card_widget.dart](#419-libuiwidgetscolor_card_widgetdart)
   - [4.20 lib/ui/widgets/online_chat_widget.dart](#420-libuiwidgetsonline_chat_widgetdart)
   - [4.21 lib/ui/screens/home_screen.dart](#421-libuiscreenshome_screendart)
   - [4.22 lib/ui/screens/lobby_screen.dart](#422-libuiscreenslobby_screendart)
   - [4.23 lib/ui/screens/game_screen.dart](#423-libuiscreensgame_screendart)

---

## 1. System Architecture

My Ludo is architected using a reactive 4-layer decoupling pattern:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   1. FLUTTER UI LAYER                                  │
│  GameScreen ───► BoardPainter (CustomPainter) ───► TokenWidget ───► PlayerAvatarWidget │
└───────────────────────────────────┬────────────────────────────────────────────────────┘
                                    │ Taps & User Gestures
                                    ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               2. GAME CONTROL SERVICE LAYER                            │
│  GameService ◄──► Timer Loop (160ms step / 40ms reverse) ◄──► SoundService (Audio)     │
└───────────────────────────────────┬────────────────────────────────────────────────────┘
                                    │ State Mutators & Repaint Signals
                                    ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  3. GAME STATE MODEL LAYER                             │
│  GameState (ChangeNotifier) ◄──► Player Model ◄──► BoardConfig (Geometry Engine)       │
└───────────────────────────────────┬────────────────────────────────────────────────────┘
                                    │ Realtime State Sync Payloads (JSON)
                                    ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                           4. FIREBASE REALTIME NETWORK LAYER                           │
│  OnlineService ───► rooms/$code (Live Payload) ───► leaderboards/$code (Archive)       │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Complete System Flow & Execution Sequence

### 2.1 App Initialization Flow
1. OS launches native app process $\to$ `main()` executes.
2. `WidgetsFlutterBinding.ensureInitialized()` binds engine channels.
3. `Firebase.initializeApp()` connects Firebase project instance.
4. `runApp(const MyLudoApp())` mounts root widget tree with `AppTheme.darkTheme`.
5. Initial router displays `HomeScreen`.

---

### 2.2 Pass & Play (Local) Turn Flow
```
[User Taps Dice Widget]
        │
        ▼
GameScreen._onDiceRoll() ──► GameService.rollDice()
                                     │
                                     ├── SoundService.playDiceRollSound()
                                     └── GameState.rollDice()
                                             ├── Dice.roll() -> Returns 1..6
                                             ├── Triple-6 Check -> If 3 consecutive, forfeit turn
                                             └── _findValidMoves() -> Evaluate token path validity
                                                     │
                                                     ├── IF 0 Valid Moves: Wait 2000ms -> advanceTurn()
                                                     └── IF Valid Moves Exist: phase = GamePhase.moving
```

```
[User Taps Valid Token]
        │
        ▼
GameScreen._onTokenTap(index) ──► GameService.selectToken(index)
                                           │
                                           ▼
                                  _animateStepByStepMove(index)
                                           │
                                           ├── Periodic Timer (160ms/step):
                                           │     ├── GameState.moveTokenStep()
                                           │     ├── SoundService.playStepSound()
                                           │     └── notifyListeners() -> Canvas Repaint
                                           │
                                           └── Step Completion:
                                                 ├── findCapturedOpponents()
                                                 │     └── IF Captures Exist:
                                                 │           ├── SoundService.playCaptureSound()
                                                 │           └── Periodic Timer (40ms/step): reverseTokenStep()
                                                 │
                                                 └── _finishMoveTurn()
                                                       ├── IF getsExtraRoll == true: Stay on active player
                                                       └── ELSE: advanceTurn() (currentPlayerIndex = next)
```

---

### 2.3 Computer (AI Bot) Execution Flow
When `state.isCurrentPlayerAI == true`, `GameService._tryAITurn()` initiates:

```
[Active Turn == AI Bot]
        │
        ▼
1. Timer(800ms delay) ──► GameService._executeAITurn()
        │
        ▼
2. GameService.rollDice() ──► Computes dice roll value
        │
        ├── IF Valid Moves Exist:
        │     └── Timer(1000ms display delay) ──► AIPlayer.chooseToken(state)
        │                                                     │
        │                                                     ▼
        │                                           Evaluates Utility Score U(m_i)
        │                                           Picks token with max(U(m_i))
        │                                                     │
        │                                                     ▼
        │                                           _animateStepByStepMove(bestToken)
        │
        └── IF 0 Valid Moves:
              └── Timer(2000ms display delay) ──► advanceTurn() ──► _tryAITurn()
```

#### AI Utility Function ($U(m_i)$)
$$U(m_i) = w_1 \cdot I_{\text{home}} + w_2 \cdot I_{\text{capture}} + w_3 \cdot I_{\text{base}} + w_4 \cdot I_{\text{stretch}} + w_5 \cdot I_{\text{danger}} + w_6 \cdot I_{\text{star}} + w_7 \cdot D_{\text{progress}}$$

Where weights are:
- Reaching Home Box ($I_{\text{home}}$): $+100.0$
- Capturing Opponent ($I_{\text{capture}}$): $+70.0 + (\text{opponentDist} \times 0.3)$
- Leaving Base Yard ($I_{\text{base}}$): $+50.0 (+30.0 \text{ if no tokens on board})$
- Entering Home Stretch ($I_{\text{stretch}}$): $+40.0$
- Escaping Danger ($I_{\text{danger}}$): $+25.0$
- Landing on Star Spot ($I_{\text{star}}$): $+20.0$
- Distance Progress ($D_{\text{progress}}$): $\text{distanceTraveled} \times 0.2$

---

### 2.4 2v2 Team Up Flow
In 2v2 mode:
- Team A = Player `0` (Red) + Player `2` (Yellow) $\implies \text{teamId} = 0$
- Team B = Player `1` (Green) + Player `3` (Blue) $\implies \text{teamId} = 1$

When `_checkCapture(playerIndex, tokenIndex)` evaluates landing tile:
```dart
if (currentTeam != null && players[opponentIndex].teamId == currentTeam) {
  continue; // Skip capture! Teammates occupy the same cell peacefully.
}
```

---

### 2.5 Online Multiplayer Network Sync Flow

```
Device A (Active Player)                   Firebase RTDB Server                  Device B (Spectating Player)
─────────────────────────                   ────────────────────                  ───────────────────────────
[User Taps Dice / Token]
          │
          ▼
Execute Action Locally
          │
          ▼
_syncToFirebase() ─────────────────────► set(rooms/$code/gameState)
                                                  │
                                                  └────────────────────────────► onValue Event Fired!
                                                                                            │
                                                                                            ▼
                                                                                    loadFromJson(remoteJSON)
                                                                                            │
                                                                                            ▼
                                                                                    Canvas Repaints Board!
```

- **Turn Authorization Guard**:
  ```dart
  bool get _isLocalPlayerTurn => widget.localPlayerId == null || state.currentPlayer.id == widget.localPlayerId;
  ```
  If `_isLocalPlayerTurn` is `false`, touch inputs are disabled on non-active devices.

---

### 2.6 Step-by-Step Stepping & Capture Rewind Physics Flow
- **Forward Stepping**: `Timer.periodic(160ms)` increments token position by 1 tile per tick while playing `sounds/step.mp3` and calling `notifyListeners()`.
- **Capture Reverse Rewind**: If landing cell contains opponent tokens, `Timer.periodic(40ms)` decrements opponent positions by 1 tile per tick back to base yard ($-1$) while playing `sounds/capture.mp3`.

---

## 3. Complete Functionality Mechanics

### 3.1 Ludo King Standard Game Rules
1. **Entering Board**: Requires a dice roll of **6** to exit base yard ($-1$) onto start tile.
2. **Extra Turn Grant** (Non-Stacking):
   - Roll a **6** $\implies \text{getsExtraRoll} = \text{true}$.
   - **Capture an opponent** $\implies \text{getsExtraRoll} = \text{true}$.
   - **Reach Home Box** $\implies \text{getsExtraRoll} = \text{true}$.
3. **Triple 6 Penalty**: 3 consecutive 6 rolls forfeit turn.
4. **Safe Star Cells**: Start tiles and star tiles ($+8$ cells after start) block captures. Tokens pass through freely (no blockades).
5. **Exact Home Landing**: Reaching center home box requires exact roll count; overshooting is invalid.

### 3.2 Board Geometry & Pixel Coordinate Mathematics
Canvas size dynamically scales grid geometry ($15 \times 15$ cells):
$$\text{cellSize} = \frac{\min(\text{width}, \text{height})}{15.0}$$
$$\text{pixelX}(g_x) = (\text{centerX} - 7.5 \times \text{cellSize}) + g_x \times \text{cellSize}$$
$$\text{pixelY}(g_y) = (\text{centerY} - 7.5 \times \text{cellSize}) + g_y \times \text{cellSize}$$

### 3.3 Token Overlap & Dynamic Stacking Engine
When multiple player tokens occupy a single tile $C$, token radii shrink to $0.48 \times \text{cellSize}$ and shift to quadrant offsets ($\pm 0.2 \times \text{cellSize}$) so all tokens remain clearly visible.

### 3.4 20-Color Theme Token System
Supports 20 curated themes (`Red`, `Green`, `Yellow`, `Blue`, `Orange`, `Purple`, `Pink`, `Cyan`, `Lime`, `Amber`, `Teal`, `Indigo`, `Deep Orange`, `Magenta`, `Emerald`, `Crimson`, `Violet`, `Coral`, `Gold`, `Sky Blue`), providing primary colors, light background tints, and dropdown collision prevention.

### 3.5 Multi-Player Ranking & Game Completion Engine
Match continues until **all but one player** complete all 4 tokens ($N-1$ players finish):
- 4-Player Match: Ranks 1st, 2nd, 3rd place; remaining player auto-placed 4th.
- 6-Player Match: Ranks 1st through 5th place; remaining player auto-placed 6th.

### 3.6 Audio Synthesis & Haptic Feedback System
Integrates 4 isolated `AudioPlayer` channels executing non-blocking sound playback:
- Step Tick: `sounds/step.mp3` + Light Haptic
- Capture Rewind: `sounds/capture.mp3` + Heavy Haptic
- Dice Roll: `sounds/dice_roll.mp3` + Medium Haptic
- Match Victory: `sounds/victory.mp3` + Vibration

### 3.7 Post-Game Archive & Database Cleanup Protocol
Upon game completion (`GamePhase.finished`):
1. Writes ranking summary payload to `leaderboards/$roomCode`.
2. Issues `ref.remove()` on `rooms/$roomCode` to purge live memory payload.

---

## 4. Exhaustive Line-by-Line Dart File Breakdown

### 4.1 `lib/main.dart`
```dart
1: import 'package:flutter/material.dart';
2: import 'package:firebase_core/firebase_core.dart';
3: import 'firebase_options.dart';
4: 
5: import 'ui/screens/home_screen.dart';
6: import 'ui/theme.dart';
7: 
8: void main() async {
9:   WidgetsFlutterBinding.ensureInitialized();
10:   try {
11:     await Firebase.initializeApp(
12:       options: DefaultFirebaseOptions.currentPlatform,
13:     );
14:   } catch (e) {
15:     debugPrint('Firebase init fallback: $e');
16:   }
17:   runApp(const MyLudoApp());
18: }
19: 
20: class MyLudoApp extends StatelessWidget {
21:   const MyLudoApp({super.key});
22: 
23:   @override
24:   Widget build(BuildContext context) {
25:     return MaterialApp(
26:       title: 'My Ludo',
27:       debugShowCheckedModeBanner: false,
28:       theme: AppTheme.darkTheme,
29:       home: const HomeScreen(),
30:     );
31:   }
32: }
```
- **Lines 1–6**: Imports Flutter core, Firebase Core, auto-generated platform options, home screen, and theme tokens.
- **Line 8**: Main entry point declared `async`.
- **Line 9**: Binds Flutter engine platform channels before awaiting async initializations.
- **Lines 10–16**: Initializes Firebase matching current OS target platform with fallback error logging.
- **Line 17**: Launches root app widget `MyLudoApp`.
- **Lines 20–32**: Builds root MaterialApp applying `AppTheme.darkTheme` and launching `HomeScreen`.

---

### 4.2 `lib/utils/constants.dart`
- Defines `PlayerColor` enum (20 colors with `.color`, `.lightColor`, `.label`).
- Defines `PlayerType` (`human`, `ai`) and `AIDifficulty` (`easy`: 40%, `medium`: 70%, `hard`: 95%).
- Defines `GamePhase` (`setup`, `rolling`, `moving`, `animating`, `finished`) and `BoardType` (`classic4`, `hex6`).
- Defines numerical game constants (`tokensPerPlayer = 4`, `posInBase = -1`, `posHome = -2`, `diceMin = 1`, `diceMax = 6`, `diceToEnter = 6`, `maxConsecutiveSixes = 3`).

---

### 4.3 `lib/utils/room_code_generator.dart`
- Generates 6-character room codes using `Random()` sampled from character set `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.

---

### 4.4 `lib/models/dice.dart`
- Encapsulates pseudo-random dice rolling returning integers in $[1, 6]$. Supports optional seed parameter.

---

### 4.5 `lib/models/player.dart`
- Player data model storing `id`, `name`, `color`, `type`, `difficulty`, `avatarIndex`, and `teamId`. Includes `copyWith()`, `toJson()`, and `fromJson()`.

---

### 4.6 `lib/models/game_state.dart`
- Central game engine extending `ChangeNotifier`.
- Tracks `tokenPositions` 2D array, `currentPlayerIndex`, `lastDiceRoll`, `consecutiveSixes`, `getsExtraRoll`, `phase`, `validTokenMoves`, `winner`, and `finishOrder`.
- Executes `rollDice()`, `_canMoveToken()` pathway checks, `moveTokenStep()` 1-tile movement, `reverseTokenStep()` capture rewind, `_checkCapture()`, `_nextTurn()`, and JSON serialization.

---

### 4.7 `lib/game/board_config.dart`
- Board geometry calculator deriving `cellSize = min(width, height) / 15.0`.
- Maps 52 main track grid pairs `_classic4Track` and home stretch cell positions to pixel offsets.

---

### 4.8 `lib/game/ai_player.dart`
- Heuristic AI decision engine evaluating valid token moves using utility function $U(m_i)$ and selecting optimal move based on bot difficulty.

---

### 4.9 `lib/services/sound_service.dart`
- Audio playback service managing 4 isolated `AudioPlayer` instances for step ticks, capture whooshes, dice rolls, and victory fanfares alongside haptic feedback.

---

### 4.10 `lib/services/game_service.dart`
- Orchestrates turn timers, 160ms step forward timer loop, 40ms capture rewind timer loop, AI bot decision timing, and `onMoveComplete` callbacks.

---

### 4.11 `lib/services/online_service.dart`
- Firebase Realtime Database service managing room creation (`rooms/$code`), `onDisconnect().remove()` socket hooks, `joinRoomResult()` color collision validation, live game state syncing (`syncGameState`), room chat messaging, and post-game archiving (`storeFinishedMatch`).

---

### 4.12 `lib/firebase_options.dart`
- Auto-generated static Firebase configuration keys for Android, iOS, macOS, and Web platforms.

---

### 4.13 `lib/ui/theme.dart`
- Dark glassmorphism theme tokens (`bg1 = 0xFF0F172A`, `surface = 0xFF1E293B`, `accent = 0xFF00E5FF`). Provides `glassCard()` and `artisticBackground()` styling helpers.

---

### 4.14 `lib/ui/widgets/board_painter.dart`
- Custom `CustomPainter` rendering 4-player cross board graphics, corner base yards, grid line arms, start arrows, colored home stretch paths, safe stars, and center victory triangles.

---

### 4.15 `lib/ui/widgets/dice_widget.dart`
- 3D animated dice widget rendering 1 to 6 pips with rotation jitter animation during roll.

---

### 4.16 `lib/ui/widgets/token_widget.dart`
- Rendered token pawn component featuring radial gradients, pawn icon, base yard indicator, and pulsing highlight ring when moveable.

---

### 4.17 `lib/ui/widgets/player_avatar_widget.dart`
- Circular avatar display rendering avatar assets with customizable border rings.

---

### 4.18 `lib/ui/widgets/player_chip_widget.dart`
- Player info chip HUD component displaying avatar, name string, turn badge, and finished token count.

---

### 4.19 `lib/ui/widgets/color_card_widget.dart`
- Color swatch selector card widget used in lobby screen.

---

### 4.20 `lib/ui/widgets/online_chat_widget.dart`
- Draggable modal bottom sheet for real-time room chat messaging.

---

### 4.21 `lib/ui/screens/home_screen.dart`
- Main dashboard screen rendering mode cards ("PASS & PLAY", "VS COMPUTER", "2V2 TEAM UP", "ONLINE MULTIPLAYER") and configuration setup dialogs.

---

### 4.22 `lib/ui/screens/lobby_screen.dart`
- Online room creation & join screen displaying 6-digit room code, copy button, player list, color picker with duplicate prevention, and host Start Game button.

---

### 4.23 `lib/ui/screens/game_screen.dart`
- Main gameplay interface rendering board painter, token stack layer, top HUD, dice controls, Firebase sync listeners, turn authorization guards (`_isLocalPlayerTurn`), and victory champion modal showing full rankings.

---

*End of Complete Deep Architecture, System Flow & Source Code Specification.*
