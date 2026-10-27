---
name: PLATFORM-PERIPHERAL                # e.g. esp-idf-st7789
description: One line - what this covers and when to load it.
platform: MCU or board
framework: ESP-IDF 5.x | Arduino | Zephyr
peripheral: part number or bus
verified: false                          # true only after code written with this skill ran on real hardware
sources:                                 # where this came from; "experience" counts
  - url-or-experience-YYYY-MM-DD
---


<!-- Prose over code. One peripheral+framework per skill. Delete sections you have nothing for. -->

## Init constraints
Order of operations, what must be ready first, what the SDK does for you vs. what you must do.

## Configuration that bites
Pull-ups, polarity, clock speeds, buffer sizes, PSRAM requirements, pin restrictions on this board.

## Known failure modes
Symptom → cause → fix. One line each. The watchdog resets, the hangs, the silent nothings.

## Patterns that work
The approach that produced working code. Prefer naming the API and the sequence over pasting a snippet.

## Don't
Things the model tends to do here that are wrong on this platform.
