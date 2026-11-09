# <Board name>

TODO: one paragraph, what this board is and why the product uses it. Defined from: TODO (a link to the definition and the first 12 hex of its sha256: in this page's folder when the repo wrote it, in datasheets/ when it is a vendor's spec sheet; or "pasted YYYY-MM-DD"; a URL needs a commit or a hash too, since the page behind it changes).

<!-- jig's board template, on the page contract (.jig/RULES.md, Documentation). Filled from a
     hardware definition, then checked against the code; the code alone can't say what the
     board is. Before code for this board passes the gate, this page matches it. Stale wiring
     info is worse than none. -->

## Components
<!-- Datasheet: a relative link to the file in datasheets/ in this page's folder (in the
     nearest folder two pages share, once a second page uses it) · its source URL · the date
     retrieved · the first 12 hex of its sha256. E.g. for a made-up part QX-100: a link to
     datasheets/qx-100.pdf · https://example.com/qx-100.pdf · 2026-01-15 · 3f2a9c01b7de.
     A part whose behavior the code touches gets its own page too, a subsystem of this one.
     Verified: yes once code has driven the part on this board, no until then. -->
| Component | Part | Role | Datasheet | Verified | Notes |
|---|---|---|---|---|---|
| TODO | TODO (e.g. ESP32-S3-WROOM-1 N16R8) | TODO (e.g. processor, display, radio, sensor) | TODO | no | TODO (e.g. 16MB flash, 8MB PSRAM) |

## Board
- Board:       TODO (e.g. ESP32-S3-DevKitC-1, or "custom rev B")
- Logic level: TODO (e.g. 3.3V. Anything 5V-only is not wired to a GPIO.)
- Power:       TODO (supply, rails, peak draw)

## Toolchain
- Framework: TODO (e.g. ESP-IDF 5.x via idf.py)
- Versions:  TODO

## Flash / rollback
- flash:      `TODO` (e.g. `idf.py -p /dev/tty.usbmodem* flash monitor`)
- rollback:   `TODO` (e.g. `idf.py flash` of the last known-good tag, or `esptool.py erase_flash` + reflash)
- known-good: tag `TODO` — last build verified on this board

## Wiring
| Peripheral | Part | Bus | Pins | Notes |
|---|---|---|---|---|
| TODO | TODO | SPI/I2C/GPIO | TODO | pull-ups? polarity? |

## Emulation
- Emulator:       TODO (e.g. Wokwi)
- Models well:    TODO (e.g. core, GPIO, I2C, SPI, ST7789)
- Does NOT model: TODO (e.g. camera, USB OTG, PSRAM timing, SD)
- A pass in emulation on a peripheral it doesn't model is not evidence.

## Known failure modes
- TODO: add as discovered. One line each. (e.g. "watchdog reset when camera init runs before PSRAM is up")

## Skills
<!-- Skills to load when writing code for this board, one line each saying why. Only skills
     that exist: one jig ships (installed into the repo when listed here) or the repo's own. -->
- TODO (e.g. `esp-idf` — the framework this board's firmware is built with)

## Invariants
<!-- Check these before blaming firmware. Keep an entry only once something holds it; until
     then it is a TODO, and an entry nothing holds is deleted. -->
- Every module's logic level matches the board — a 5V signal on a 3.3V pin damages it; held by TODO (a named test, review, or on screen).
- Every input has its pull-up or pull-down set explicitly — a floating input reads noise as data; held by TODO.
- Every output is driven to a known state right after it is configured — a glitch at boot can fire a peripheral; held by TODO.
- No two devices on a shared bus share an address — a collision corrupts both; held by TODO.
- The power rail supplies the peak draw (radio, display backlight and camera together) — a brownout resets the board mid-write; held by TODO.
