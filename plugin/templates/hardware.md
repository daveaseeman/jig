# <Board name>

Defined from: TODO (the definition's file path, or "pasted YYYY-MM-DD")

<!-- jig's board template. Filled from a hardware definition, then checked against the code;
     the code alone can't say what the board is. Before code for this board passes the gate,
     this page matches it. Stale wiring info is worse than none. -->

## Pre-flight (check before blaming firmware)
- [ ] Every module's logic level matches the board
- [ ] Pull-ups/downs set explicitly on every input
- [ ] Outputs set to a known state immediately after config
- [ ] Shared bus addresses don't collide
- [ ] Power rail can supply the peak draw (camera, radio, display backlight together)

## Components
| Component | Part | Role | Notes |
|---|---|---|---|
| TODO | TODO (e.g. ESP32-S3-WROOM-1 N16R8) | TODO (e.g. processor, display, radio, sensor) | TODO (e.g. 16MB flash, 8MB PSRAM) |

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
- Rule: a pass in emulation on an unmodeled peripheral is not evidence.

## Known failure modes
- TODO: add as discovered. One line each. (e.g. "watchdog reset when camera init runs before PSRAM is up")

## Skills
<!-- Skills to load when writing code for this board, one line each saying why. Only skills
     that exist: one jig ships (installed into the repo when listed here) or the repo's own. -->
- TODO (e.g. `esp-idf` — the framework this board's firmware is built with)
