# IceWeatherstation

DIY-Wetterstation auf Basis **ESP32 + Tasmota**: Temperatur, Luftfeuchte, Luftdruck, eine wasserdichte Zusatz-Temperatursonde, Wind (Geschwindigkeit + Richtung), Regenmenge, **Blitzerkennung** (AS3935/Franklin-Sensor) und ein **kalibrierter dBA-Schallpegelmesser**.

[Quellcode auf GitHub](https://github.com/icepaule/IceWeatherstation)

## Status

✅ **Erstes Gerät aufgebaut, geflasht und am Schuppen im Betrieb (Stand 2026-07-19).** DS18B20, Regenmesser, Anemometer, Windfahne, dBA-Sensor, AS3935 (Blitz) und OLED-Display sind verkabelt, kalibriert und live verifiziert; MQTT + Home-Assistant-Anbindung läuft. Noch offen: BME280 (Temperatur/Feuchte/Druck) ist bestellt, aber noch nicht geliefert/verbaut.

<p float="left">
  <img src="images/aufbau-schuppen-1.jpeg" width="45%" alt="Offenes Gehäuse mit Verkabelung, Windfahne/Anemometer im Hintergrund" />
  <img src="images/aufbau-schuppen-2.jpeg" width="45%" alt="Montage am Schuppendach, Anemometer/Windfahne auf dem Mast" />
</p>

## Dokumentation

| Seite | Inhalt |
|---|---|
| [Setup-Guide](setup-guide) | **Schritt-für-Schritt-Anleitung**: Aufbau, Flashen, Konfiguration, Home-Assistant-Einbindung |
| [Teileliste (BOM)](bom) | Vollständige Teileliste mit Bezugsquellen |
| [Verkabelung](wiring) | Pinbelegung + Verkabelungskonzept |
| [Gehäuse](enclosure) | Gehäuse, Mast-Montage, wetterfestes Mikrofongehäuse (DNMS-Design) |
| [MISOL-Kompatibilität](misol-compatibility) | Warum keine MISOL-Fertigsensorik als Plug-and-Play funktioniert |
| [Tasmota-Konfiguration](tasmota-config) | Firmware-Konfiguration, alle live gefundenen Fallstricke |
| [Firmware](https://github.com/icepaule/IceWeatherstation/tree/main/firmware) | Custom-Build, fertige Binaries, Berry-Skript |

## Hardware-Kurzüberblick

| Sensor | Bauteil | Werte |
|---|---|---|
| Temp/Feuchte/Druck | Bosch BME280 (I2C) | °C, %rH, hPa |
| Zusatz-Temperatur | DS18B20 (wasserdicht, 1-Wire) | °C |
| Wind | SparkFun Weather Meter Kit SEN-15901 | m/s, Richtung (Grad) |
| Regen | SparkFun Weather Meter Kit SEN-15901 | mm (Kippwaage) |
| Blitz | AS3935 / CJMCU-3935 (I2C) | Ereignis, Distanz (km), Energie |
| Schallpegel | DFRobot Gravity SEN0232 (analog) | dBA, 30–130 dB, A-bewertet |

## Quellen / Credits

- [ampheo.com Blog](https://www.ampheo.com/blog/how-to-build-a-smart-weather-station-with-sensors) — Grundkonzept
- [SparkFun Weather Meter Kit SEN-15901 Hookup Guide](https://learn.sparkfun.com/tutorials/weather-meter-hookup-guide) — Wind/Regen-Sensorik
- [DFRobot Gravity SEN0232 Wiki](https://wiki.dfrobot.com/Gravity_Analog_Sound_Level_Meter_SKU_SEN0232) — dBA-Kalibrierung
- [sensor.community DNMS-Projekt](https://sensor.community/en/sensors/dnms/) — Wetterschutzgehäuse-Design fürs Mikrofon
- [rtl_433 Projekt](https://github.com/merbanan/rtl_433) — `fineoffset.c`-Decoder, Grundlage der MISOL-Kompatibilitätsanalyse
- [Tasmota-Dokumentation](https://tasmota.github.io/docs/) — Firmware-Referenz

MIT-Lizenz, siehe [LICENSE](https://github.com/icepaule/IceWeatherstation/blob/main/LICENSE).
