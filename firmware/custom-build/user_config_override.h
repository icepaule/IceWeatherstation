#ifndef _USER_CONFIG_OVERRIDE_H_
#define _USER_CONFIG_OVERRIDE_H_

// IceWeatherstation custom build: combine AS3935 (from tasmota32/FIRMWARE_TASMOTA32
// feature set) with uDisplay/SSD1306 support (from tasmota32-display/FIRMWARE_DISPLAYS
// feature set) - no official ESP32 binary provides both simultaneously.

#define USE_DISPLAY                            // Add Display Support (+2k code)
#define USE_UNIVERSAL_DISPLAY                  // uDisplay generic display driver (replaces removed USE_DISPLAY_SSD1306)

// my_user_config.h defines USE_DISPLAY_MATRIX/USE_DISPLAY_SEVENSEG unconditionally
// (only visually indented under a commented-out USE_DISPLAY, not actually guarded).
// Enabling USE_DISPLAY above silently activates them too. MTX_ADDRESS6 defaults to
// 0x76 - identical to the BME280 I2C address - so the Matrix/SevenSeg boot-time I2C
// probe claims 0x76 before the real BME280 driver gets a chance ("SevenSeg found at
// 0x76" in the boot log, BME280 never detected). Disable both, we don't use them.
#undef USE_DISPLAY_MATRIX
#undef USE_DISPLAY_SEVENSEG

#endif  // _USER_CONFIG_OVERRIDE_H_
