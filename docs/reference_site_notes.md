# Reference Site Notes

The user-provided reference URL is `https://ludobyiamsouviki.web.app/`.

The reference currently presents a dark navy/teal splash background with a centered four-color Ludo icon. The main visual direction is dark, neon, game-oriented, with cyan/magenta glow accents. The first browser load required waiting for the Flutter splash screen to finish before the app canvas appeared.

No additional textual layout details were extracted from the reference page because it is a canvas-rendered Flutter app. The local project should preserve the existing dark neon direction while improving the home screen’s horizontal margins and replacing plain icon treatments with polished image-backed assets.

## Deployed-site smoke check

On 2026-08-25, the deployed URL loaded the same Flutter home screen successfully after its splash. The visible first page showed the dark neon board background, a centered logo image, and three large menu cards: VS Computer, Pass & Play, and Play Online. The deployed home subtitle still advertises 2 or 4 players for VS Computer. The browser canvas exposes no ordinary DOM controls, so game interaction requires canvas coordinates and the Flutter-rendered visual state.

## Deployed online setup check

The deployed online setup currently exposes only `2 Players` and `4 Players`, with no six-player option. This matches the requested scope: six-player should be re-enabled for Pass & Play first, while online six-player remains disabled for now. Creating a room was not performed because it would create an external online room and was not needed for passive inspection.

## Visual diagnosis

The deployed home screenshot uses a full-bleed dark cosmic background with the content centered in a narrow column. The current `ludo_banner_logo.png` is a JPEG saved with a checkerboard background baked into the pixels rather than transparency. That explains the distracting boxed/checkerboard appearance around the logo and supports replacing it with the newly generated watermark-background PNG. The home layout should use full-width background with a centered content max width and safe horizontal padding, rather than exposing any light side gutters.

## Local implementation smoke check

The rebuilt local home screen now fills the viewport edge-to-edge with the artistic background. The new watermark-backed Ludo icon is centered without the previous checkerboard logo, and all three menu cards show image-backed icons. The Pass & Play subtitle advertises Classic 4 and Star 6. The centered content has intentional dark background margins rather than white gutters.

## Pass & Play Star 6 smoke check

The rebuilt Pass & Play modal visibly exposes `Classic 4` and `Star 6`. Selecting `Star 6` automatically selects `6 Players`, changes the human-player stepper to six, and shows six player name/color rows using red, green, yellow, blue, orange, and purple. Team mode is correctly hidden for Star 6. Online setup was not changed and remains classic-only.

## Six-player board smoke check

The rebuilt Star 6 Pass & Play match opened successfully with six colored player areas arranged around the board. The compact control panel stayed in its own left-side column and did not overlap the board. This confirms the re-enabled six-player UI path is reachable and visually separate from the classic layout.

## Generated asset check

The optimized `rank_first.png` is a clear gold crown/medal with cyan-magenta neon rim lighting and no embedded text. The optimized `last_player.png` is a clear red-and-blue checkered finish flag with a glowing red token and downward chevron, also with no embedded text. Exact ordinal labels remain Flutter text, avoiding unreadable generated typography while retaining the requested stylish image treatment.
