# IceWeatherstation — Stephans Version

Reduzierte Variante des [IceWeatherstation](../README.md)-Projekts: gleiche ESP32/Tasmota-Basis, aber
weniger Sensoren. Gebaut für den Nachbau bei Stephan, dokumentiert hier als eigenständige, gekürzte
Abzweigung der Hauptdokumentation.

## Unterschied zum Originalgerät

| | Originalgerät | Stephans Version |
|---|---|---|
| Temperatur/Feuchte/Druck | BME280 | BME280 |
| Zusatztemperatur | DS18B20 | DS18B20 |
| Wind/Regen | SEN-15901 (3-teilig) | SEN-15901 (3-teilig) |
| Display | OLED | OLED |
| Blitzsensor (AS3935) | ✅ | ❌ nicht verbaut |
| Schallpegel (SEN0232) | ✅ | ❌ nicht verbaut |
| Luftqualität (MQ135) | ❌ nicht verbaut | ✅ intern, geschlossenes Gehäuse |
| MQTT / Home Assistant | ✅ | ❌ bewusst nicht — reines Web-UI |
| Status-LED | blinkt bei MQTT-Aktivität | blinkt bei Web-UI-Zugriff (siehe [tasmota-config.md](docs/tasmota-config.md)) |

## Inhalt

- [docs/bauanleitung.pdf](docs/bauanleitung.pdf) — vollständige Schritt-für-Schritt-Anleitung inkl. Verkabelung, zum Ausdrucken/Mitnehmen
- [docs/wiring.md](docs/wiring.md) — Pin-Tabelle (Board-Beschriftung), Widerstandswerte, Schaltbilder
- [docs/tasmota-config.md](docs/tasmota-config.md) — GPIO-Konfiguration, MQ135-Eigenkalibrierung, gefundene Fallstricke
- [firmware/autoexec.be](firmware/autoexec.be) — Dashboard-Skript (muss auf dem Gerät exakt `autoexec.be` heißen)

Die verwendete Sonder-Firmware selbst (Tasmota mit AS3935+OLED-Unterstützung) ist identisch zum
Originalgerät — siehe [../firmware/README.md](../firmware/README.md) für Bezug/Eigenbau. Der
Blitzsensor-Treiber ist darin enthalten, aber ungenutzt (kein AS3935 verbaut) — harmlos.

## Kein MQTT/Home Assistant

Bewusste Entscheidung: Stephans Standort hat keine Home-Assistant-Instanz. Alle Werte sind live über die
Tasmota-eigene Weboberfläche abrufbar (kein Cloud-Konto, keine App nötig).
