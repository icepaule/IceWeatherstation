# Firmware

## Custom-Build nötig (AS3935 + Display zusammen)

⚠️ **Korrektur (2026-07-18, live an echter Hardware verifiziert):** Frühere Version dieser Doku ging davon aus, dass die offiziellen Tasmota32-Binaries für dieses Projekt ausreichen. Das stimmt nur, solange kein OLED-Display verbaut wird. Sobald AS3935 **und** Display gleichzeitig gebraucht werden, reicht **kein** offizielles ESP32-Release-Binary:

| Sensor/Feature | `tasmota32.bin` | `tasmota32-display.bin` |
|---|---|---|
| BME280 (I2C) | ✅ | ✅ |
| DS18B20 (1-Wire) | ✅ | ✅ |
| Counter (Regen/Wind) | ✅ | ✅ |
| ADC Range (dBA-Sensor) | ✅ | ✅ |
| Berry-Scripting | ✅ | ✅ |
| **AS3935 (Blitzsensor)** | ✅ | ❌ **fehlt** (I2CDriver 48 nicht kompiliert, alle `AS3935*`-Befehle "Unknown") |
| **OLED-Display (uDisplay/SSD1306)** | ❌ **fehlt** (`DisplayModel`/`DisplayText` "Unknown") | ✅ |

Grund (Tasmota-Quellcode `tasmota_configurations_ESP32.h`): `USE_AS3935` wird nur vom `FIRMWARE_TASMOTA32`-Flag gesetzt, `USE_DISPLAY`+`USE_UNIVERSAL_DISPLAY` nur vom separaten `FIRMWARE_DISPLAYS`-Flag — beide Flags schließen sich in den offiziellen Release-Envs gegenseitig aus. Für ESP32 gibt es (anders als bei ESP8266 mit `tasmota-sensors.bin`) keine dritte Variante, die beides kombiniert.

## Eigener Build: beide Features kombinieren

Lösung: eigener PlatformIO-Build mit [`custom-build/user_config_override.h`](custom-build/user_config_override.h) (in diesem Repo), der beide Defines zusätzlich zum normalen `tasmota32`-Featureset (inkl. AS3935) aktiviert:

```c
#define USE_DISPLAY
#define USE_UNIVERSAL_DISPLAY
```

Kein eigenes PlatformIO-Environment nötig — der Standard-`tasmota32`-Env bringt die nötige `lib_display`-Bibliothek bereits über `lib_extra_dirs` mit, es fehlten nur die beiden Compile-Defines.

### Build-Schritte

```bash
git clone --depth 1 --branch v15.5.0 https://github.com/arendst/Tasmota.git
cp user_config_override.h Tasmota/tasmota/user_config_override.h   # aus diesem Ordner
cd Tasmota
pio run -e tasmota32
# Ergebnis: .pio/build/tasmota32/firmware.bin (App-Image, ~2,1 MB, für OTA/erneutes Serial-Flashen)
#           .pio/build/tasmota32/firmware.factory.bin, falls vorhanden (Ersteinrichtung über USB)
```

Kompilierzeit ca. 5 Minuten. Speicherbedarf verifiziert: Flash 74 % belegt (2.184.647 / 2.949.120 Byte), RAM 24 % — ausreichend Reserve für spätere Erweiterungen (z.B. BME280 braucht keinen zusätzlichen Treiber-Code, ist bereits Teil des Basis-Featuresets).

⚠️ Vor jedem Build-Versuch prüfen, ob sich `tasmota_configurations_ESP32.h` in einer neueren Tasmota-Version geändert hat (Github-Suche nach `USE_AS3935` und `FIRMWARE_TASMOTA32`/`FIRMWARE_DISPLAYS`) — die Trennung könnte sich mit künftigen Releases ändern oder eine offizielle Kombi-Variante entstehen.

## Bezug (falls doch nur ein Feature gebraucht wird)

Offizielle Release-Binaries: **https://ota.tasmota.com/tasmota32/release/**

| Datei | Zweck |
|---|---|
| `tasmota32.factory.bin` | Erstes Flashen über USB, falls **kein** Display gebraucht wird |
| `tasmota32.bin` | OTA-Update ohne Display-Bedarf |
| `tasmota32-display.bin` | Falls **kein** AS3935 gebraucht wird |

## Erstes Flashen (USB, esptool)

```bash
esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 460800 write_flash -z 0x0 tasmota32.factory.bin
```

Für den eigenen Custom-Build: gleicher Befehl, aber mit dem selbst gebauten `firmware.factory.bin` (bzw. beim späteren Wechsel von einem offiziellen Release auf den Custom-Build reicht ein OTA-Update mit dem App-Image `firmware.bin` an der App-Partition — Sensor-/GPIO-Konfiguration bleibt dabei erhalten, da sie in einer separaten Flash-Partition liegt).

Alternativ [Tasmotizer](https://github.com/tasmota/tasmotizer) (GUI) verwenden — nimmt die gleiche `.factory.bin`-Datei.

### OTA-Update im eigenen Netz (kein öffentliches Hosting nötig)

Der ESP32 lädt die Firmware über `OtaUrl` + `Upgrade 1` von jeder erreichbaren HTTP-Quelle, nicht zwingend `ota.tasmota.com`. Praktikabel: `firmware.bin` per `python3 -m http.server` von einem Host im selben (V)LAN bereitstellen und die eigene IP als `OtaUrl` setzen — funktioniert ohne Umweg über externe Server, solange Absender-Host und ESP32 im selben Netzsegment liegen (Firewall-Regeln zwischen VLANs beachten).

## Nach dem Flashen

1. Mit dem ESP32-eigenen Access Point `tasmota-XXXX` verbinden, WLAN-Zugangsdaten eintragen (siehe [docs/setup-guide.md](../docs/setup-guide.md))
2. GPIOs über *Konfiguration → Konfiguriere Modul* setzen (siehe [docs/wiring.md](../docs/wiring.md))
3. [config/backlog.txt](config/backlog.txt) — Konsolen-Befehle für Counter/ADC/AS3935/WebSensor einfügen
4. [berry/autoexec.be](berry/autoexec.be) — über den Datei-Manager (*Konsole* → *Verwalte Dateisystem*) hochladen, Datei **muss exakt `autoexec.be` heißen**
5. OLED-Einrichtung (uDisplay, GPIO-Marker, Display-Descriptor): [docs/tasmota-config.md](../docs/tasmota-config.md) Abschnitt 6

Details und Reihenfolge: [docs/setup-guide.md](../docs/setup-guide.md), Befehlsreferenz: [docs/tasmota-config.md](../docs/tasmota-config.md).
