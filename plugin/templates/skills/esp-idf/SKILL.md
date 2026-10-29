---
name: esp-idf
description: Base ESP-IDF conventions for ESP32-family boards — GPIO, build, flash, PSRAM. Load for any firmware task built with ESP-IDF.
platform: ESP32 family (seeded on an ESP32-S3-DevKitC-1)
framework: ESP-IDF 5.x
peripheral: core / GPIO
verified: false
sources:
  - https://arxiv.org/html/2603.19583v1 (Appendix D, ESP-IDF GPIO excerpt)
  - TODO: ESP-IDF programming guide sections as consulted
---

<!-- SEED. Starts from the one ESP-IDF excerpt published in the Duke paper. Expand from docs + experience; flip verified when it has produced working code. -->

## Init constraints
- Call `gpio_config()` then immediately `gpio_set_level()` so every output has a deterministic state before any peripheral power-up delay.
- Install the ISR service once (`gpio_install_isr_service()`) before adding per-pin handlers.
- TODO: PSRAM init order relative to camera/display buffers. ESP32-S3: boards often carry 8–16MB PSRAM; large buffers must be allocated with `MALLOC_CAP_SPIRAM`.

## Configuration that bites
- Set pull-up/pull-down explicitly on every input. Floating inputs read noise.
- Microsecond delays: `ets_delay_us()` from `rom/ets_sys.h`, not `vTaskDelay` (tick-granular).
- TODO: strapping pins and USB-JTAG pins to avoid; they differ per chip, so check the board page's Components and Wiring.
- TODO: `sdkconfig` items that must be set (PSRAM, flash size, partition table).

## Known failure modes
- Transient inputs under ~5 ms missed → polling; fix: edge interrupt (`GPIO_INTR_NEGEDGE` / `POSEDGE`).
- 5V module on a 3.3V GPIO → instability firmware can't fix. Check the board page's Pre-flight.
- TODO: add as discovered.

## Patterns that work
- Interrupt-driven edge detection for buttons/encoders/pulses; polling only for slow analog.
- TODO.

## Don't
- Don't assume Arduino-style defaults (pinMode pull-ups, delay()) — ESP-IDF sets nothing for you.
- Don't trust LLM-written "best practices" for ESP-IDF without a doc reference; the paper measured them making things worse.
