# Global Rec Mute Solo Box

Compact global Rec / Mute / Solo controls for REAPER.

## Features
- Global Rec, Mute and Solo track-state controls.
- Main Toolbar default placement.
- Drag and drop to compatible REAPER UI areas.
- Ctrl + left click configuration menu.
- Sizes: 75%, 100%, 125%, 150%, 175%, 200% (100% = 28 × 28 px).
- Persistent size and placement.
- Optional automatic launch at REAPER startup.
- Delayed hover tooltips:
  - Rec — `Toggle armed tracks`
  - Mute — `Toggle muted tracks`
  - Solo — `Toggle solo tracks`
- Tooltips are hidden while dragging.

## Author
**doomfred**, with OpenAI.


## v1.1.4

Hover tooltips are now refreshed continuously after the delay while the
pointer remains over Rec, Mute or Solo. They disappear only when the pointer
leaves the button or a drag starts.


## v1.1.5 — portable startup path

The startup block no longer stores an absolute Windows path.

Instead, `Scripts/__startup.lua` builds the path dynamically with
`reaper.GetResourcePath()`, making startup configuration portable across
different Windows user accounts and REAPER installations.


## v1.1.6 — right-click configuration

Right-clicking Rec, Mute or Solo now opens the same configuration menu as
Ctrl + left click. Native REAPER right-click/context-menu messages are
intercepted while the component is active so the underlying toolbar menu
does not replace the Global Rec Mute Solo menu.
