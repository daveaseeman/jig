# HARDWARE.md

<!-- The agent can't infer any of this from code. Keep it current; stale wiring info is worse than none. -->

## Board
- MCU / board: TODO (e.g. ESP32-S3-DevKitC-1 N16R8)
- Framework:   TODO (e.g. ESP-IDF 5.x via idf.py)
- Logic level: 3.3V. Anything 5V-only is not wired to a GPIO.
- Toolchain:   TODO (version)

## Flash / rollback
- flash:    `TODO` (e.g. `idf.py -p /dev/tty.usbmodem* flash monitor`)
- rollback: `TODO` (e.g. `idf.py flash` of last known-good tag; or `esptool.py erase_flash` + reflash)
- known-good: tag `TODO` — last build verified on hardware

## Wiring
| Peripheral | Part | Bus | Pins | Notes |
|---|---|---|---|---|
| TODO | TODO | SPI/I2C/GPIO | TODO | pull-ups? polarity? |

## Emulation
- Emulator: TODO (e.g. Wokwi)
- Models well: TODO (e.g. core, GPIO, I2C, SPI, ST7789)
- Does NOT model: TODO (e.g. camera, USB OTG, PSRAM timing, SD)
- Rule: a pass in emulation on an unmodeled peripheral is not evidence.

## Pre-flight (check before blaming firmware)
- [ ] Every module's logic level matches the board
- [ ] Pull-ups/downs set explicitly on every input
- [ ] Outputs set to a known state immediately after config
- [ ] Shared bus addresses don't collide
- [ ] Power rail can supply the peak draw (camera, radio, display backlight together)

## Known failure modes
- TODO: add as discovered. One line each. (e.g. "watchdog reset when camera init runs before PSRAM is up")
