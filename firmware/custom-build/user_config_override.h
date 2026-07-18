#ifndef _USER_CONFIG_OVERRIDE_H_
#define _USER_CONFIG_OVERRIDE_H_

// IceWeatherstation custom build: combine AS3935 (from tasmota32/FIRMWARE_TASMOTA32
// feature set) with uDisplay/SSD1306 support (from tasmota32-display/FIRMWARE_DISPLAYS
// feature set) - no official ESP32 binary provides both simultaneously.

#define USE_DISPLAY                            // Add Display Support (+2k code)
#define USE_UNIVERSAL_DISPLAY                  // uDisplay generic display driver (replaces removed USE_DISPLAY_SSD1306)

#endif  // _USER_CONFIG_OVERRIDE_H_
