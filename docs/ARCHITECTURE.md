# HeiBan architecture

Current macOS implementation (2026-10-09): [module ownership and data flow](../macos/docs/development/ARCHITECTURE.zh-TW.md), [current delivery status](../macos/docs/development/CURRENT_STATUS.zh-TW.md), and [development history](DEVELOPMENT_INDEX.zh-TW.md). The target boundaries below remain planning context; consult the platform documents for what is actually wired into the app.

Planning update (2026-10-02): see the Traditional Chinese [development goals](DEVELOPMENT_PLAN.zh-TW.md), [acceptance criteria](ACCEPTANCE_CRITERIA.zh-TW.md), [work backlog](WORK_BACKLOG.zh-TW.md), and [Excalidraw Desktop source analysis](EXCALIDRAW_DESKTOP_ANALYSIS.zh-TW.md). These distinguish target architecture from the current implementation and preserve the user's confirmed PDF scope.

## Product direction

HeiBan is a local-first whiteboard. The macOS app is the first native client; a shared document format is the compatibility boundary for the existing React/Vite client and a later web/Windows client. Treat Microsoft Whiteboard, Goodnotes, Figma/FigJam, and Excalidraw as product references for interaction patterns. Reimplement those patterns against HeiBan's own model and UI; do not copy another project's source code or assets.

## Current repository

- `src/`: existing React 19 + TypeScript + Vite client. Firebase 12 is present for Google sign-in, Firestore, and collaboration. This is the current feature-rich prototype and its persisted JSON shape is the compatibility reference.
- `macos/Sources/HeiBanCore/`: Swift document models, coordinate math, gesture recognition, and board state.
- `macos/Sources/HeiBanMac/`: SwiftUI/AppKit macOS UI and canvas rendering.
- `macos/Sources/HeiBanTestRunner/`: executable core checks, not a user-facing test target.
- `macos/scripts/`: local build and packaging helpers.

The macOS target currently has no third-party package dependencies and targets macOS 14. Web and native clients do not yet share a formal schema package or a persistence/sync service contract.

## Target boundaries

```text
HeiBanMac (SwiftUI + AppKit)
  ├─ App shell, menus, panels, shortcuts, file/screenshot dialogs
  ├─ Canvas interaction adapter (mouse, trackpad, Apple Pencil/tablet)
  └─ Canvas renderer (Core Graphics / SwiftUI Canvas)
        ↓ commands / immutable snapshots
HeiBanCore (Foundation + CoreGraphics)
  ├─ Document and object model + versioned JSON codec
  ├─ Board command handlers and selection/transform rules
  ├─ Undo/redo transaction history
  ├─ Viewport, hit-testing, geometry, snapping
  └─ Import/export adapters (SVG/PDF/PNG) behind interfaces
        ↓ local repository protocol
HeiBanStorage (future)
  ├─ Local document library and autosave
  └─ Cloud sync adapter (future; Google identity + collaboration service)
```

Keep high-frequency pointer samples in a canvas-only preview store. Commit one completed gesture as one board command/history transaction. The preview must not publish changes through the root board model, which would refresh toolbars, panels, and all committed content for every sample. The native canvas now follows this separation for in-flight pen points. Sealed 64-segment chunks are merged into one Path so each preview frame submits one stable-path stroke instead of one draw call per chunk; the rest of the board state and renderer still need profiling and further separation.

The Web client follows the same boundary for freehand input: stroke points are held in a mutable gesture buffer and browser-coalesced samples are consumed when available. The preview commits cubic curve segments in bounded chunks and updates only its small active tail once per animation frame, rather than serializing the full stroke for every frame. Board object drag updates are committed to React state at most once per frame; the latest object state is sent to Firestore after a short quiet period. Presence is coalesced to the latest sample and writes are serialized. These reduce redundant work but do not replace profiling with large boards or real multi-user sessions.

## Document and cross-platform contract

- Preserve the existing web fields and spellings, including `extension` in JSON, optional fields, object IDs, z-order, points, opacity, pins, canvas mode/preset/dimensions, and timestamps.
- Keep coordinates in board/world space. Screen coordinates exist only in the interaction adapter; all input and output pass through the viewport transform.
- Add schema versioning and migration functions before changing persisted field meaning. Never rely on synthesized Swift `Codable` defaults as a migration strategy.
- Store large image assets separately from metadata in a later storage layer. Current web JSON can contain data URLs; native-only image decoding should not become a permanent shared contract.
- Treat Firebase as an adapter. Core editing must work offline without Firebase types or network calls. Define conflict resolution and presence expiry before enabling multi-user writes from the native app.

## Performance requirements

- Pointer sampling and preview drawing must not trigger full app-shell updates.
- Avoid decoding embedded image data and sorting every object on every frame; cache decoded assets and maintain render ordering at commit boundaries.
- Avoid full document copies per pointer sample. History records semantic transactions/snapshots at command boundaries and has an explicit memory budget.
- Coalesce autosave/cloud writes; never write a document for each input sample.
- Keep pan/zoom anchored to pointer location and use incremental gesture deltas, with no artificial finite bounds for an infinite board.
- Profile on Apple Silicon with long strokes, many objects, high-resolution images, and multi-touch/trackpad input before calling the app low-latency.

## Delivery phases

1. **Native foundation:** fix canvas navigation and gesture lifecycle; implement selection, object editing, text editing, fill brush, eraser modes, and durable local library; establish versioned import/export.
2. **Parity and quality:** implement board sizing/export ranges, layers, ruler controls, screenshot/import, accessibility, keyboard shortcuts, and high-resolution rendering; complete the acceptance checklist.
3. **Reliability:** add automated core/serialization checks, UI interaction checks, performance scenarios, crash-safe autosave, and signed/notarized macOS packaging.
4. **Online collaboration:** specify board permissions, presence, conflict handling, offline queue, account lifecycle, security rules, and server quotas; add Google sign-in and real-time sync through a storage adapter.
5. **Web and Windows:** reuse the document contract and behavioral acceptance cases. Choose platform UI/renderers deliberately; do not assume SwiftUI/CoreGraphics code can run on those platforms.

## Development workflow

1. Read this file, `docs/FEATURE_PARITY_CHECKLIST.md`, and the applicable source before changing behavior.
2. Implement a narrow vertical slice: model/command → interaction → render → persistence/export → acceptance criterion.
3. Keep web and native changes explicit about schema compatibility. Update migration/fixture coverage when persisted data changes.
4. Run `cd macos && swift build` for native compile checks. Run `cd macos && swift run HeiBanTestRunner` for core checks. For web, use the scripts in `package.json` (`pnpm lint`, `pnpm build`).
5. Manually verify pointer/trackpad behavior, Chinese IME, undo/redo, reopening saved files, and render quality on supported macOS. Record the OS/device, scenario, and result in the checklist.
6. Package using `macos/scripts/build_app.sh` only after the app has passed the acceptance gates. Signing/notarization and distribution configuration are not established yet.

The repository's current `run_checks.sh` runs both the core runner and `swift build`; it should be kept aligned with the workflow above as dedicated test targets are introduced.


## Native library and input update (2026-10-02)

`LocalBoardLibrary` owns atomic per-board persistence; `BoardEngine` coordinates document switching, legacy migration, autosave and history reset. The current document snapshot remains for backward recovery. Local metadata is derived from saved document files rather than a separate index that could drift from them. Library scans currently decode documents; a metadata index and thumbnail cache will be needed for very large libraries.

`NativePointerSurface` bridges AppKit mouse/keyboard/magnify events to the existing core gesture engine. Freehand preview has its own observable store. The committed object layer listens only to transform and geometric preview properties, so appending pen points does not invalidate all committed object rendering. Live stroke construction appends stable cubic segments into 64-segment chunks and updates only a trailing segment as samples arrive. Rendering still visits sealed chunks, and committed-object rendering still builds paths on viewport changes; measured profiling is needed before declaring drawing latency resolved.

Native home includes account/settings visibility; authentication, Firebase collaboration, export formats and advanced object editing remain tracked in the parity checklist.

Core verification uses an empty engine session via `restoreSession: false`; normal App initialization restores/migrates local documents. This prevents real user documents from contaminating isolated algorithm/gesture checks.
