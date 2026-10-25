# Sudokuly v1.0.1 — design QA

Date: 2026-10-24, Europe/Athens.

Scope: replace the home screen's statistics/history and account icons with the user-selected Flow pair. The existing native layout, wordmark typography, button actions and accessibility labels remain the product context for this change.

## Visual target and implementation

- Source visual truth: `Design/FlowIcons/flow-selected-reference.png`, the exact image selected by the user.
- Running app screenshot: `Verification/flow-icons/home.png`.
- Full header and focused glyph comparison in one image: `Verification/flow-icons/design-comparison.png`.
- Source/vector detail comparison: `Verification/flow-icons/source-vector-comparison.png`.
- User-facing header crop: `Verification/flow-icons/home-header.png`.

The source is a 1586 × 992 concept board, not a full phone viewport. The implementation was captured on the existing Sudokuly QA iPhone 17e simulator, iOS 27.0, at 1170 × 2532 pixels: 390 × 844 pt at 3× density. The state is the light-mode home screen with a simulated signed-in test player. The comparison excludes OS chrome and normalizes the two header regions to the same width. Enlarged source glyphs and vector renderings are shown separately in the same comparison because silhouette details are the selected design target. No browser or CSS viewport applies to this native SwiftUI change.

## Findings

- Both custom silhouettes retain the selected flowing base, curved channels and connected account form. They use no third-party icon library.
- The source contours were smoothed while tracing them into vector assets to remove pixel-edge stair steps. The inspected final vector contours are smooth and remain faithful to the selected image.
- The header preserves the existing Bricolage Grotesque wordmark and layout. Each custom image uses a 26 × 26 pt frame inside its existing 44 × 44 pt button. Differences between the concept board's generated lettering and the app's installed font are outside this icon replacement.
- Color uses the existing `Palette.ink` token. Template rendering removes the reference's raster texture/background and keeps the icons consistent with the app.
- Copy/content and navigation identifiers are unchanged. The removed grid logo remains absent to the left of the wordmark.
- No clipping, overlap, missing assets or actionable P0/P1/P2 visual issues were found in the final capture.

## Verification

- Debug simulator build passed.
- Two existing UI tests passed with zero failures: `HistoryUITests.testFirstGameIsRecordedOnceAndRelaunchClearsIt` and `AuthenticationUITests.testAppleEntryAndAccountDeletion`. These exercise the history and account buttons using isolated test fixtures.
- The compiled asset catalog contains both a template rendition and a retained vector rendition for each icon.
- The built app reports version 1.0.1 and build 2.
- Swift syntax, SVG/asset manifest validation and `git diff --check` passed.
- Logs, test screenshots, contour measurements and compiled-asset metadata are local evidence under `Verification/flow-icons/`.

The full iOS test suite, Release archive, physical-device rendering and a VoiceOver session were not run for this scoped visual change.

## Flow steps difficulty icons and Game details — 2026-10-25

The user selected `Design/FlowDifficulty/flow-steps-selected-reference.png` for the four difficulty bar states and requested a centered `Game details` header in historical game recaps. These changes preserve the native layout and the existing result content.

- Actual home capture: `Verification/flow-difficulty-game-details/screenshots/4CE2484C-1F93-467E-AFD1-DD68E848837E.png`.
- Actual game-details capture: `Verification/flow-difficulty-game-details/screenshots/DB513F7E-6F35-4EFE-8780-C725D37FDCDC.png`.
- Combined selected-source, vector and running-app comparison: `Verification/flow-difficulty-game-details/design-comparison.png`.
- Implementation preview: `Verification/flow-difficulty-game-details/implementation-preview.png`.
- Full trace/color metadata and test summary: `Verification/flow-difficulty-game-details/trace-metadata.json` and `summary.json`.

The source is a 1435 × 1096 concept board. Running captures are 1170 × 2532 pixels on the iPhone 17e / iOS 27.0 simulator (390 × 844 pt, 3× density). The source targets the glyph styling rather than the concept board's wide layout. All four selected glyphs and their vector equivalents were normalized into equal comparison boxes; the same comparison input includes the running native difficulty list and detail header. The app's existing font sizes, row spacing and white list surface are preserved.

Inspected all four ranks: one, two, three and four active charcoal bars, with inactive bars in light grey. Curved channels remain visible at the 30 pt row size. The images contain no baked-in background, retain vector representation and use original rendering to preserve both colors. The selector heading reads `SELECT A DIFFICULTY LEVEL`, fits on one line in the captured viewport and keeps the existing typography. The `Game details` title follows the Account header's 16 pt semibold typography and is balanced by equal 46 pt side slots, with the circular back control retained.

Debug compilation and two existing history UI tests passed with zero failures or skips. The tests cover the normal home-to-game/history flow and historical win, timeout and mistake recaps. An added assertion verifies the new header label and its horizontal center within 1.5 pt in each recap. Final screenshot comparison found no actionable P0/P1/P2 visual mismatch. No visual fixes were needed after this final comparison. Physical-device and large accessibility text-size checks were not run for this scoped change.

## Your progress history layout — 2026-10-25

The user requested a centered `Your progress` header, removal of `One puzzle at a time.`, and narrower history sections whose visible left and right edges align with the statistics above.

- Source visual truth: `/Users/mountzou/Downloads/Στιγμιότυπο οθόνης 2026-10-25, 2.31.35 πμ.png`.
- One-game implementation capture: `Verification/history-progress-alignment/screenshots/6F99F0E2-8973-438B-9FBE-902DD5B82916.png`.
- Six-game implementation capture: `Verification/history-progress-alignment/screenshots/3ED7901F-248F-4DBC-89A1-7F61A80654D4.png`.
- Combined source and implementation comparison: `Verification/history-progress-alignment/design-comparison.png`.
- User-facing implementation crop: `Verification/history-progress-alignment/progress-preview.png`.

The reference is 1320 × 2868 pixels (440 × 956 pt at 3×); the running iPhone 17e capture is 1170 × 2532 pixels (390 × 844 pt at 3×). The combined comparison preserves each viewport's logical width and uses equal-size point units rather than stretching either screen. Both show one solved game. The implementation uses an isolated test result, so its day, duration and time differ from the user's reference; those data differences are outside the layout change.

The new header follows the existing Account/Game details typography and balanced side slots. The footer is absent. History date groups, their rows and separators now take their side insets from the actual content bounds of the first and last statistics, instead of the full-width column slots. In the inspected one-game capture, the leading row content aligns with the Played label and the trailing chevron aligns with the Focus content. Spacing responds to statistic widths and available screen width. Existing colors, fonts, hero copy and row content are preserved.

Debug compilation and the two existing history UI tests passed with zero failures or skips (`Verification/history-progress-alignment/summary.json`). Assertions cover the centered header, removed footer, reduced row width, empty/single/multiple-record states, and continued navigation into game details. The final source/implementation comparison found no actionable P0/P1/P2 mismatch. A physical-device or large accessibility text-size pass was not run for this change.

final result: passed
