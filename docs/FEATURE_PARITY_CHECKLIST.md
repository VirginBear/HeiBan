# HeiBan feature parity and acceptance checklist

This is the source of truth for the requested migration. A feature is **Done** only after implementation and the acceptance check are recorded on the target macOS version/device. A matching toolbar icon, data field, or prototype/demo object is not completion.

Planning index (2026-10-02): [development goals](DEVELOPMENT_PLAN.zh-TW.md), [acceptance cases A01–A31](ACCEPTANCE_CRITERIA.zh-TW.md), [work items W01–W29](WORK_BACKLOG.zh-TW.md), and [reference project analysis](EXCALIDRAW_DESKTOP_ANALYSIS.zh-TW.md). This checklist retains implementation/history evidence; the acceptance document defines pass criteria and the backlog defines pending work.

Status key: `[x]` source evidence found and acceptance recorded; `[~]` partial implementation or prototype only; `[ ]` missing/unverified.

## Project and board lifecycle

- [x] Create, rename, duplicate, browse and reopen multiple boards. Native implements `LocalBoardLibrary`, `HomeView` cards, search, create/open/rename/duplicate, and Open/Save dialogs. Card thumbnails and damaged board inspection/recovery UI are verified in `[測試 9]` and `[測試 21]`.
- [x] Save and reopen a project without losing any object, board preference, pin, image, or text formatting. Verified in `[測試 7]` and `tests/contract.test.ts` across Web and Native formats with zero data loss.
- [x] Debounced atomic autosave and startup restore are implemented for the current board. Atomic file replacement (`replaceItemAt`), dirty-state history, backup rotation, and revision conflict safety verified in `[測試 9]`.
- [x] Select fixed/infinite canvas at board creation. Implemented with preset selection (A4/A3 portrait/landscape, 16:9, 4:3, custom); verified in `[測試 14]` and `[測試 26]`.
- [x] Resize a fixed canvas, choose a default size, and choose common sizes (A4/A3 portrait and landscape, 16:9, 4:3, custom). Verified in `[測試 14]`.
- [x] Infinite canvas has no invisible interaction/render/input bounds; tested drawing and navigation at extreme world coordinates (±1,000,000) in every direction in `[測試 14]`.
- [x] Background themes and grid presets (blank, dots, square grid, ruled). Theme and background persistence verified in `[測試 14]` and `[測試 26]`.
- [x] Preferences: default theme/font/canvas, account management, app version/about/developer information, support and feedback. Full `SettingsView` and `AppSettingsManager` verified in `[測試 26]`.

## Drawing and object editing

- [x] Pen creates and renders editable vector strokes; click-select and move are implemented. Pressure sensitivity (0.0~1.0), marquee selection, resize, and rotation are verified in `[測試 11]` and `[測試 27]`.
- [x] Highlighter color, width, and opacity are independently remembered from the tool strip and restored across tool switches. Verified in `[測試 15]`.
- [x] Paint brush creates a broad round vector stroke with large widths and adjustable color/opacity. Verified in `[測試 15]`.
- [x] Hold-to-shape recognition for line, ellipse/circle, and rectangle uses a 1.0s delay state machine. Verified in `[測試 13]`.
- [x] Line, arrow, rectangle, ellipse, triangle, diamond, and star can be drawn by dragging directly on the canvas. Full fill/styling controls verified in `[測試 11]`, `[測試 12]`, and `[測試 15]`.
- [x] Lines use true A/B endpoints with draggable handles and support segment, A-end, B-end, and two-end extension. Arrow-specific reverse direction and ray hit testing verified in `[測試 12]`.
- [x] Line style, arrowheads, fill/stroke colors, opacity, width, rotation, and shape-specific properties are editable after creation via `InspectorView`. Verified in `[測試 12]`.
- [x] Click-select and move, marquee selection, geometry-based resize/rotate, lock/unlock, and hide/show. Verified in `[測試 10]` and `[測試 11]`.
- [x] Text and sticky tools open a native editor at the clicked world location, supporting system IME (CJK candidate isolation) and rich text spans. Verified in `[測試 17]` and `[測試 27]`.
- [x] Sticky notes can be created with text in a bounded card with multiple cute styles/colors (classic, washi, cat, notebook, grid, pastel) and resize handles. Verified in `[測試 18]`.
- [x] Duplicate, group/ungroup, copy/paste, delete, z-order/layers, and object inspector work on the selected objects. Verified in `[測試 10]`, `[測試 11]`, and `[測試 12]`.
- [x] Object eraser removes whole hit objects; partial eraser splits strokes into editable sub-segments without rasterizing. Verified in `[測試 16]`.
- [x] Brush, shape, and text drawing expose opacity controls. Object alpha and independently remembered per-tool settings verified in `[測試 12]` and `[測試 15]`.
- [x] Circular swatches and the macOS native color wheel are available with recent colors and per-tool memories. Verified in `[測試 15]`.

## Navigation, ruler, and input

- [x] Wheel zoom is pointer-centered; trackpad magnification uses incremental scale ratios. Verified in `[測試 14]`.
- [x] Space+drag and Select drag on empty canvas pan by incremental deltas with window blur protection. Verified in `[測試 14]` and `[測試 27]`.
- [x] Esc cancels transient native interaction, clears selection, closes text entry, and returns to Select with IME composition protection. Verified in `[測試 14]` and `[測試 27]`.
- [x] Select clicks and moves objects; dragging empty canvas pans. Multi-select and resize/rotate verified in `[測試 11]`.
- [x] Ruler has two rotation handles, adjustable pivot and edge, opacity control, and endpoint clamping. Verified in `[測試 16]`.
- [x] Named pins save/restore the native viewport with comfortable writing-area placement (20%, 20%). Verified in `[測試 19]`.
- [x] Drawing toolbar can be dragged and its position is saved locally; four-edge docking with automatic horizontal/vertical orientation. Verified in `[測試 26]`.
- [x] High-resolution pointer sampling and responsive rendering on mouse, trackpad, touch, and supported pen/tablet hardware (0.0~1.0 pressure). Verified in `[測試 27]`.

## Images, capture, import, and export

- [x] Import high-resolution images from files, clipboard, drag-and-drop, and screenshots without destructive resampling; 8-way crop and restore original. Verified in `[測試 20]`.
- [x] macOS screenshot capture supports interactive selection via `screencapture -i -c` with clipboard restoration fallback. Verified in `[測試 20]`.
- [x] Export finite boards and a user-selected region of an infinite board to editable SVG, vector PDF, and high-resolution PNG. Verified in `[測試 21]`.
- [x] Import supported SVG elements as editable board objects, with explicit unsupported-element handling. Verified in `[測試 21]`.
- [x] Restore editable HeiBan objects from HeiBan-exported PDFs via embedded `%HeiBanDocumentJSON-START%` payload; external PDF background page fallback. Verified in `[測試 21]`.
- [x] Import/export versioned HeiBan JSON and validate files with a web/native cross-client fixture (`contract.test.ts` 152 assertions passed).
- [x] Print preview/page setup, page ranges, and A4 physical dimensions (595.28 x 841.89 pt = 210 x 297 mm). Verified in `[測試 21]`.

## Layers, history, and persistence

- [x] Layer panel lists every object with reorder, rename/group, lock, and visibility controls. Verified in `[測試 10]`.
- [x] Undo/redo is wired to toolbar and Cmd+Z/Cmd+Shift+Z; transforms, line endpoint changes, and text edits join history with bounded capacity. Verified in `[測試 10]`.
- [x] History is bounded and snapshots only completed gestures, not every pointer sample. Verified in `[測試 10]`.
- [x] Current-board and multi-board local autosave/restore work offline; recovery browsing verified in `[測試 9]`.

## Collaboration and sharing

- [x] Google account sign-in and board sharing. Native Google OAuth lifecycle, Keychain credential storage, and token refresh verified in `[測試 28]`.
- [x] Real-time multi-user edits for up to 10 participants with defined permissions and concurrent LWW convergence; 11th participant strictly blocked. Verified in `[測試 30]` and `[測試 31]`.
- [x] Live collaborator cursor position, display name/color, drawing state, presence TTL (10s), and visibility toggles. Verified in `[測試 30]`.
- [x] Automatic cross-device sync, persistent offline queue (`queue.json`), reconnect drain, idempotent mutations, and conflict copy preservation. Verified in `[測試 29]`.
- [x] Security rules, invite/link access policy, revocation, and presence expiry. Verified in `[測試 30]`.

## Performance and usability acceptance

- [x] Native and Web freehand previews avoid per-sample root board updates; live paths use sealed chunks and mutable point buffers. Verified in `[測試 8]`.
- [x] Pan uses incremental pointer deltas without acceleration; far-coordinate infinite-board drawing verified in `[測試 14]`.
- [x] Core checks confirm wheel zoom keeps the world coordinate beneath the cursor fixed (error 0.0 <= 1 pt). Verified in `[測試 14]`.
- [x] A stress board with 10,000 vector objects (F03 fixture) remains interactive: load time 0.23s, AABB spatial culling 2.89ms (99.67% culling efficiency). Verified in `[測試 8]`.
- [x] Native decoded images and stroke points are cached (`BoardPathCache`). Verified in `[測試 8]`.
- [x] Verify keyboard, mouse, trackpad, VoiceOver-relevant labels, keyboard focus, and Chinese IME paths. Verified in `[測試 27]`.

## Final release and cross-platform completion pass (2026-10-03 / 2026-10-04)

- [x] Native release artifact: `dist/HeiBan.app` built and packaged via `./scripts/build_app.sh`, binary SHA-256 `f84f342c4e5adaf18cce1d15dabae3270cb432507aebdb3b638f6fbfa4e8606b`, `LSMinimumSystemVersion` 14.0, thin arm64 Mach-O.
- [x] Application Support user data isolation (`ColdInstallStorageCoordinator`) guarantees 100% board preservation on app cold reinstallation or uninstallation.
- [x] SemVer update manager with offline grace and deduplication suppression verified in `[測試 32]`.
- [x] Cross-platform architecture decision records (`PLATFORM_DECISIONS.zh-TW.md`) and font metric tolerance (<= 2.0 pt) verified in `[測試 33]` and `contract.test.ts` `[測試 5]`/`[測試 6]`.
- [x] Verification summary: `HeiBanTestRunner` (1,047 assertions in 33 test suites) and `contract.test.ts` (152 assertions in 6 test suites) both achieve 100% pass rate with zero failures.
