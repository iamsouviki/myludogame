# Four-Player Ludo Rule and UI Clarification

## Purpose

This document records the confirmed gameplay and UI requirements for the classic four-player mode.

## 1. Completed-player position must be prominent

When a player has all four tokens in the home/finished area, the player’s ordinal position must be shown in a **large, prominent style** in that player’s own room/base area or player header. It should not appear only as a small label in the dice/control panel.

For example, if Player 2 is the first player to complete all four tokens, the green player area shown in the supplied image should visibly display:

> 1st

The display should remain associated with that player’s color and name. Later completed players should show `2nd`, `3rd`, and `4th` in the same prominent location. The existing game rules, token positions, and active-player controls must continue to work.

## 2. Consecutive six rule

A player may use at most **two consecutive sixes** in one turn sequence.

| Six rolled in the sequence | Expected behavior |
|---|---|
| First six | The player may move a valid token, then receives another dice roll. |
| Second six | The player may move a valid token, then receives another dice roll. |
| Third six | The third six is invalidated; the player does not move a token for that third six, does not receive another roll, and the turn passes to the next eligible player. |

Therefore, a player can move tokens after the first and second six, but never after a third consecutive six. The third six must not create a bonus roll or leave the player stuck in the rolling/moving phase.

This rule applies consistently to local/offline and authoritative online gameplay.

## 3. A six with no legal move does not grant a bonus roll

If a player rolls a six but none of that player’s tokens can legally move six spaces, the six is consumed and the turn passes to the next eligible player. This applies to every distribution of tokens between the player’s colored home row and the central finished-home area:

| Tokens on the colored home row | Tokens already in central home | Expected behavior after rolling 6 |
|---:|---:|---|
| 4 | 0 | No bonus roll; pass the turn. |
| 3 | 1 | No bonus roll; pass the turn. |
| 2 | 2 | No bonus roll; pass the turn. |
| 1 | 3 | No bonus roll; pass the turn. |

A six grants another roll only when at least one token has a valid move for that six. A player with no legal move must not remain in the rolling phase waiting for another roll because of the six.

## 4. A completed player must not receive a bonus turn

Once all four tokens of a player are in the home/finished area, that player is complete and must be skipped for future turns. In particular, the player must not receive another roll merely because:

- the player rolled a six before completing;
- the completion move itself was made with a six; or
- the completion move also captured an opponent token.

After the player’s completion is recorded, the turn must move to the next unfinished player. If only two unfinished players remain, they must continue alternating normally without the completed player being selected.

## Acceptance checks

The implementation will be considered correct when the following are true:

1. A completed player’s own board area visibly shows a large ordinal label such as `1st`, `2nd`, `3rd`, or `4th`.
2. First six: move and receive another roll.
3. Second six: move and receive another roll.
4. Third six: no third token move and no additional roll; the turn advances.
5. A player who has completed all four tokens never rolls again, even when the final move was a six or capture.
6. Existing classic four-player movement, capture, home-entry, offline persistence, and online authority behavior remain intact.

## Confirmation requested

Please confirm that this interpretation is correct before implementation, especially the intended third-six behavior: **the first two sixes may move tokens, while the third consecutive six is cancelled and ends the turn**.
