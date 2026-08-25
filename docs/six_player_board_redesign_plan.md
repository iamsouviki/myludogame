# Star 6 Board Redesign and 3D Token Implementation Plan

## Scope and decision

The voice-chat research is intentionally kept separate and is not part of this change. This plan covers only the **six-player Star 6 board redesign** and the requested **3D pawn-style tokens**.

The supplied six-player board image will be treated as a geometry and composition reference only. It contains visible stock-watermark text, so the implementation will create an original board design rather than copy or ship that image. The supplied pawn image will likewise be used as a silhouette/style reference; the production token files will be original generated assets without watermarks or text.

The existing four-player Classic board remains the protected baseline. All six-player changes will be routed through Star 6-specific painter, geometry, rules, and asset branches so the classic board cannot be changed accidentally.

## Current-state findings

The repository already has a `BoardType.hex6` mode, six available colors, a 78-cell logical track, five home-stretch cells, six-player setup in Pass & Play, and a separate `SixPlayerRules` hook. The current Star 6 painter is not the requested board style: it draws circular track dots around a white hexagon and circular player bases around the outside. `BoardConfig` also positions Star 6 track cells on a radial/circular approximation rather than in rectangular six-arm lanes.

The current token renderer is procedural. It draws a glossy circular token with concentric rings, so it does not match the requested upright plastic pawn silhouette. Token movement and tap handling already live above this renderer in `GameScreen`; replacing the visual inside `TokenWidget` can therefore preserve gameplay behavior and animation orchestration.

Flutter asset directories are not treated as recursive here, so the implementation will explicitly declare the Star 6 token and existing rank subdirectories under `assets/images/` to guarantee web bundling.

## Target visual layout

The new Star 6 board will be a rotationally symmetric six-arm board with one sector every 60 degrees. The board will retain the current logical route model of six arms × thirteen track cells, but the visual geometry will be rebuilt as a clean board grid.

Each sector will contain the following layers:

| Layer | Target design | Logical relationship |
|---|---|---|
| Player base | An outward-facing rounded triangular/arrow-shaped colored base with a white inset and four pawn sockets arranged as a compact 2 × 2 diamond | One base per physical route slot; token base coordinates come from `BoardConfig.basePosition` |
| Outer route | Two parallel six-cell lanes around each sector plus the sector’s start/transition cell, with crisp square or slightly rounded grid cells | Exactly thirteen logical cells per arm, preserving the existing route index contract |
| Home lane | A five-cell colored lane pointing inward toward the center, with a clear start arrow and dark grid lines | `homeStretchPosition(slot, step)` for steps 0–4 |
| Center | A six-wedge colored home area around a small dark/neutral center hexagon | Finished tokens continue to use the existing central-home position contract |
| Safety markers | Clean star markers on the existing Star 6 safe positions, colored starts, and visible entry arrows | Safety logic remains in `GameState`; only rendering changes |
| Player label | A compact name/rank label placed outside or above the triangular base, with enough contrast against the background | Uses existing player/color mapping and finish order |

The board should use a single normalized coordinate system centered on the canvas. Every sector is generated from one canonical top-sector definition rotated by `slot * 60°`. This avoids six separately maintained drawings and guarantees that red, green, yellow, blue, orange, and purple remain aligned with their logical route slots.

## Geometry implementation

### `BoardConfig`

Replace only the Star 6 geometry methods while leaving all Classic 4 methods unchanged:

- `_hex6TrackPosition`
- `_hex6HomeStretch`
- `_hex6BasePosition`

Use normalized radial and tangential vectors for each sector:

```text
angle = slot * 60° - 90°
radial = (cos(angle), sin(angle))
tangent = (-sin(angle), cos(angle))
```

The canonical thirteen-cell sector will map its six outer-side cells, transition/start cell, and six inner-side cells to rectangular lane centers. The exact spacing will be derived from the available board radius and `cellSize`, not hard-coded screen pixels. The five home-lane cells will use the same radial/tangential basis and remain centered on the sector’s inward lane. Base pawn sockets will be derived from the base center using radial and tangential offsets so all four pawn positions remain aligned after rotation.

Add geometry assertions/tests for the following invariants:

1. All six start cells are distinct.
2. All six home lanes point toward the same center.
3. Every player base has four distinct socket positions.
4. Rotating the canonical sector by 60° produces the corresponding neighboring sector.
5. No Star 6 token socket or lane cell is placed outside the board’s painted bounds.
6. Classic 4 coordinates and route behavior remain unchanged.

### `BoardPainter`

Keep `_paintClassic4` untouched. Refactor only `_paintHex6` into small Star 6-specific helpers:

- `_drawHex6TrackGrid`
- `_drawHex6HomeLanes`
- `_drawHex6PlayerBase`
- `_drawHex6CenterHome`
- `_drawHex6StarsAndArrows`
- `_drawHex6PlayerLabel`

The painter should draw filled cells and grid lines from the same coordinates consumed by token overlays. The base should be a `Path` built from the rotated canonical triangular shape, with a white inset path and four subtle socket circles or socket rings. No stock image should be used as the board background; the board must remain crisp at any canvas size and support responsive Flutter layouts.

## 3D pawn token implementation

### Asset set

Generate six standalone transparent PNGs under `assets/images/tokens/`:

```text
star6_red_pawn.png
star6_green_pawn.png
star6_yellow_pawn.png
star6_blue_pawn.png
star6_orange_pawn.png
star6_purple_pawn.png
```

Each asset will show one upright glossy plastic pawn with:

- A rounded head and tapered body silhouette.
- A soft 3D highlight from the upper-left.
- A darker lower edge for depth.
- The matching Star 6 player color.
- Transparent background.
- No text, watermark, board, extra pawn, or colored rectangle.
- A consistent camera angle, scale, and padding across all six files.

The assets should be generated as a coherent set, then checked individually at the small size used on the board. Deterministic resizing may be used after generation to create web-appropriate production dimensions, but the transparent silhouette and color must be preserved.

### `TokenWidget`

Add an optional `pawnAsset` or `usePawnStyle` input. `GameScreen` will set it only for `BoardType.hex6` initially, keeping the existing four-player circular token visual unchanged. The widget will preserve:

- `GestureDetector` tap behavior.
- Highlight pulse and scale animation.
- Highlight glow and selected-token contrast.
- `isInBase` semantics.
- Existing token size and stacking layout.

For Star 6, the child renderer will use `Image.asset(..., fit: BoxFit.contain, filterQuality: FilterQuality.high)`. The current procedural renderer will remain as an error fallback so a missing asset cannot make tokens invisible or break a match.

## Rules and state isolation

No new gameplay rule will be introduced by the visual redesign. `GameState` will continue to own movement, capture, safe spots, home entry, six-sequence handling, and finish order. The existing `SixPlayerRules` helper remains the boundary for Star 6-only game-end semantics.

The following isolation rules are mandatory:

| Area | Classic 4 | Star 6 |
|---|---|---|
| Board painter | Existing `_paintClassic4` | New `_paintHex6` helpers |
| Board geometry | Existing 15 × 15 grid mapping | New rotational six-sector mapping |
| Logical track | 52 cells | 78 cells |
| Player colors | Red, green, yellow, blue | Red, green, yellow, blue, orange, purple |
| Setup access | Existing VS Computer/online restrictions | Pass & Play only |
| Rules hook | Existing classic threshold | `SixPlayerRules` threshold and future hooks |
| Token appearance | Existing circular renderer initially | Original 3D pawn assets |

Online Star 6 remains disabled in this phase. Existing persisted Star 6 games must not be invalidated solely because the visual board is being changed.

## Tests and validation

Add or extend deterministic tests for:

- Six-player board geometry symmetry and non-overlapping base sockets.
- Six-player route positions matching the painter’s lane structure.
- Six-player finish threshold remaining separate from Classic 4.
- Pass & Play creating six human players with all six colors.
- Classic 4 factory, route, and finish behavior remaining unchanged.
- Token asset mapping returning the correct color-specific pawn asset.
- Token widget fallback remaining available when an image cannot load.

Run the following validation sequence after implementation:

1. `dart format` on every changed Dart file.
2. `flutter analyze`.
3. `flutter test` including the existing Classic 4 and Star 6 rule suites.
4. `flutter build web --release`.
5. Browser smoke test on the deployed reference domain for issue discovery and on the local release build for the new implementation.
6. Test Pass & Play Classic 4 and Star 6 setup separately.
7. Inspect Star 6 at a narrow phone-sized viewport and a desktop-sized viewport.
8. Verify tokens remain tappable, highlighted tokens pulse once, home-lane movement still follows the logical route, and finished-token/rank overlays do not obscure the new base geometry.
9. Review `git diff --check`, restore analyzer-generated configuration if necessary, commit only intended files, and push the branch.

## Suggested implementation order

### Stage A — Geometry contract

Create the canonical six-sector coordinate helpers and tests first. Do not change token rendering until track, home-lane, and base socket coordinates are stable.

### Stage B — Star 6 painter

Replace only the current Star 6 painter with the triangular-base and lane-grid design. Validate that every token coordinate lands inside the corresponding painted cell or base socket.

### Stage C — Original pawn assets

Generate and optimize the six transparent 3D pawn PNGs. Add the color-to-asset mapping and the Star 6-only renderer path with procedural fallback.

### Stage D — Integration and responsive polish

Verify rank badges, player labels, base socket spacing, board sizing, and the existing compact control panel at multiple viewport sizes. Adjust only Star 6 constants if a classic layout would otherwise be affected.

### Stage E — Regression and delivery

Run the full analyzer, tests, release build, and browser smoke checks. Commit and push the implementation as a focused Star 6 redesign commit, separate from the earlier voice-chat research.

## Acceptance criteria

The redesign is complete when a six-player Pass & Play match shows six original triangular colored player areas arranged radially, crisp rectangular route lanes and colored home lanes, a six-color center, six visible player labels, and upright 3D pawn tokens in bases and on the route. Token taps and animations must still work. Classic 4 must render and behave as before. Online setup must remain classic-only until a separate online Star 6 phase is approved.
