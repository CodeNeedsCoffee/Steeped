# Library Features Plan (Phase 4 follow-ups + Glass mini-player fix)

Covers PLAN.md 4.5 (Authors / Collections / Playlists), 4.6 (filter & sort), 4.7 (search categories),
quality-of-life additions, and the Glass Modern mini-player visibility fix. Written 2026-10-07.

## Decisions (from evan)

- **Navigation:** the Library tab gets a sub-filter (segmented control): **Books | Authors | Collections | Playlists**.
  Home and Series tabs are unchanged.
- **Glass mini-player:** lighter frosted fill + accent edge, staying "glass".
- **Editing:** full playlist and collection editing (create, rename, delete, add/remove, reorder playlists).
  Collection mutations are server-gated (`canUpdate`), so those actions are hidden for accounts without it.
- **QoL included:** grid/list toggle + sort memory, global search upgrade, long-press quick actions, playlist play queue.

## Testing policy: everything is tested in the Linux app

No phone testing for this plan. All verification runs through the Linux target (see `linux/README.md`):

- Headless run: `xvfb-run -a flutter test integration_test/<file>.dart -d linux` against `https://audiobooks.dev` (demo/demo).
- Unit/widget tests: `flutter test` (no device needed) for models, sort/filter query building, contrast math.
- Linux has no audio engine: for anything needing the mini-player, set `currentPlaybackItemProvider` to a fake item
  (pattern from the mini-player repro test). Playback behaviour itself (queue advance) is tested at the controller level
  with a fake handler, not by listening to audio.
- Visual checks (glass bar): run under Xvfb and capture screenshots (`xwd`/`import`) for both skins; supplement with a
  numeric contrast-ratio unit test so the fix is checkable without eyeballing.
- Admin-gated paths (collection edit) first try the demo account; if it lacks `canUpdate`, run the local server
  (`~/Code/audiobookshelf`, v2.36.0, `node index.js`) with an admin user and point the Linux app at it.
- Caveat to note on completion: Linux passing does not prove Android/iOS behaviour; list anything platform-specific as unverified.

## Work items

### G0. Glass mini-player visibility (do first, small)
Cause: `MiniPlayer` on Glass wraps content in `GlassSurface` = `surface` (#12151B) at 55% alpha over a #12151B scaffold,
with a black shadow. Dark on dark, no edge, so it disappears. Brown skin uses opaque `surfaceContainerHigh`, so it reads.
- In `GlassSurface`/`MiniPlayer`: fill with a lighter tint (white ~10-12% or `primary` ~14% over blur), 1px border
  (white ~22%), shadow tinted with `primary` instead of black, thin accent progress line along the bottom.
- Keep Bookshelf untouched. Add an optional `border`/`elevationGlow` parameter to `GlassSurface` rather than skin-branching in `MiniPlayer`.
- Tests: contrast unit test (bar fill vs scaffold >= ~1.4:1, icon/text vs fill >= 4.5:1); Xvfb screenshots of both skins.

### L1. Library models and data layer
- Models: `Author`, `Collection`, `Playlist` (+ `PlaylistItem` with optional `episodeId`), parsed defensively
  (coerce numbers/strings, per the earlier `ebookLocation` crash).
- Repositories/endpoints (all confirmed in server `ApiRouter.js`):
  - Authors: `GET /libraries/:id/authors`, `GET /authors/:id` (include=items,series), image `GET /authors/:id/image`.
  - Collections: `GET /libraries/:id/collections`, `GET/PATCH/DELETE /collections/:id`, `POST /collections`,
    `POST/DELETE /collections/:id/book`, batch add/remove.
  - Playlists: `GET /libraries/:id/playlists`, `GET/PATCH/DELETE /playlists/:id`, `POST /playlists`,
    `POST/DELETE /playlists/:id/item`, batch add/remove, `POST /playlists/collection/:collectionId`.
- Providers follow the existing `library_providers.dart` pattern; invalidate on mutation and on socket events
  (`playlist_*`, `collection_*`) if the socket service already surfaces them.

### L2. Library tab sub-filter + browse screens (4.5)
- Segmented control at the top of the Library tab; selection persisted per library.
- Authors: grid of avatar + name + book count; author detail (image, description, books grid, series).
- Collections / Playlists: list of cards with cover mosaic (up to 4 covers), name, item count, duration.
- Detail screens: item list, Play all, Download all (reuse download engine), overflow menu (rename/delete when permitted).
- Podcast libraries: hide Authors/Collections; Playlists kept (episodes allowed).
- Empty and error states for every list.

### L3. Playlist/collection editing
- Create (from a book's menu or the list screen), rename, delete with confirmation.
- Add to playlist/collection sheet (choose existing or create new) from item detail and quick actions.
- Reorder playlist items with `ReorderableListView`; persist via `PATCH /playlists/:id` items order.
- Remove item (swipe or menu). Optimistic UI with rollback on failure.
- Collection edits shown only when `user.canUpdate`; playlist edits always (per-user).

### L4. Filter and sort (4.6)
- Sort menu: title, author, added date, published year, duration, progress/last played, with asc/desc
  (`sort` + `desc` query params on `/libraries/:id/items`).
- Filter sheet: genre, tag, author, narrator, series, language, progress state (in progress / finished / not started),
  has ebook. Options come from `GET /libraries/:id/filterdata`. Filter value encoding is `<group>.<base64(value)>`.
- Active filters shown as removable chips; "Clear all".
- QoL: remember sort/filter per library (drift `KeyValueEntries` or `AppSettings`), grid/list view toggle, pull-to-refresh.

### L5. Search upgrade (4.7)
- Add Authors, Narrators, Tags, Genres result sections (response already groups them); tapping applies a filter (L4)
  or opens the author detail (L2).
- Recent searches (last ~10, clearable), shown when the box is empty.
- Podcast libraries: optional RSS/term search deferred (admin-gated create), noted only.

### L6. Quick actions (QoL)
- Long-press on any book/episode card: Play, Download/Remove download, Add to playlist, Add to collection (if permitted),
  Mark finished/not finished, Go to author / series. One shared bottom sheet widget used from grids, shelves, search, detail.

### L7. Playlist play queue (QoL)
- Playing from a playlist records the queue; when an item finishes the next plays automatically (books and episodes).
- Now Playing gets a small "Queue" sheet (reorder/remove). Existing single-item behaviour unchanged when no queue.
- Respect download-first rule and cellular settings per item.

## Suggested order
G0 -> L1 -> L4 (sort/filter, quickest visible win) -> L2 (Authors, then Collections/Playlists read-only) -> L3 -> L5 -> L6 -> L7.
Each step ends with its Linux integration test passing and the PLAN.md/ROADMAP.md entries updated.

## Risks / open items
- Demo server content may lack authors/collections/playlists; tests create their own playlist and clean it up, and the
  local server fallback covers collections.
- Playlist reorder payload shape should be confirmed against `PlaylistController.update` before building.
- Glass visuals are subjective; expect one round of tuning after you see screenshots.
- No Android/iOS verification in this plan by decision; platform-specific behaviour stays flagged as unverified.
