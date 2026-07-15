# Firmware

## Kein Custom-Build nötig

Anders als bei den MAX7219-LED-Matrix-Projekten (IceMatrix) braucht dieses Projekt **keinen** eigenen PlatformIO-Custom-Build. Verifiziert gegen die offizielle Tasmota-Dokumentation (Stand v15.5.0, 2026-07-15): Das Standard-ESP32-Binary **`tasmota32.bin`** enthält bereits alle benötigten Treiber:

| Sensor | Im Standard-`tasmota32.bin` enthalten? |
|---|---|
| BME280 (I2C) | ✅ ja |
| DS18B20 (1-Wire) | ✅ ja |
| AS3935 (Blitzsensor) | ✅ ja — laut [offizieller AS3935-Doku](https://tasmota.github.io/docs/AS3935/) nur in `tasmota-sensors` (ESP8266) und `tasmota32` (ESP32) enthalten, aber dort enthalten |
| Counter (Regen/Wind) | ✅ ja, Kernfunktion |
| ADC Range (dBA-Sensor) | ✅ ja, Kernfunktion |
| Berry-Scripting | ✅ ja, Standard ab Tasmota32 |

## Bezug

Offizielle Release-Binaries: **https://ota.tasmota.com/tasmota32/release/**

Benötigte Dateien für den ESP32-WROOM-32U DevKitC V4:

| Datei | Zweck |
|---|---|
| `tasmota32.factory.bin` | **Erstes Flashen** über USB (kompletter Flash-Inhalt inkl. Partitionstabelle) |
| `tasmota32.bin` | **Spätere Updates** per OTA (Web-UI → Firmware-Upgrade) oder erneutes Serial-Flashen |

> Die exakte Dateiliste kann sich mit neueren Tasmota-Versionen leicht ändern — vor dem Flashen immer den aktuellen Stand unter obigem Link prüfen, insbesondere ob `tasmota32.bin` weiterhin AS3935 enthält (Release Notes / [Tasmota-Changelog](https://github.com/arendst/Tasmota/releases) durchsuchen, falls Zweifel bestehen).

## Erstes Flashen (USB, esptool)

```bash
esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 460800 write_flash -z 0x0 tasmota32.factory.bin
```

Alternativ [Tasmotizer](https://github.com/tasmota/tasmotizer) (GUI) verwenden — nimmt die gleiche `.factory.bin`-Datei.

## Nach dem Flashen

1. Mit dem ESP32-eigenen Access Point `tasmota-XXXX` verbinden, WLAN-Zugangsdaten eintragen (siehe [docs/setup-guide.md](../docs/setup-guide.md))
2. GPIOs über *Konfiguration → Konfiguriere Modul* setzen (siehe [docs/wiring.md](../docs/wiring.md))
3. [config/backlog.txt](config/backlog.txt) — Konsolen-Befehle für Counter/ADC/AS3935/WebSensor einfügen
4. [berry/autoexec.be](berry/autoexec.be) — über den Datei-Manager (*Konsole* → *Verwalte Dateisystem*) hochladen, Datei **muss exakt `autoexec.be` heißen**

Details und Reihenfolge: [docs/setup-guide.md](../docs/setup-guide.md), Befehlsreferenz: [docs/tasmota-config.md](../docs/tasmota-config.md).

## Falls doch ein Custom-Build nötig wird

Sollte sich beim realen Aufbau herausstellen, dass ein Standard-Binary etwas nicht mitbringt (z.B. wegen einer künftigen Tasmota-Version, die Features anders aufteilt), ist ein Custom-Build über [PlatformIO](https://tasmota.github.io/docs/Compile-your-build/) mit eigener `user_config_override.h` möglich — analog zum bestehenden IceMatrix-Setup. Bisher (Stand dieser Doku) ist das für dieses Projekt **nicht erforderlich**.
