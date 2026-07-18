# Teileliste (BOM)

Für **zwei baugleiche Geräte**. Wo nichts anderes vermerkt ist, gilt die Menge pro Gerät (also ×2 bestellen).

> Preise sind Momentaufnahmen (Stand 2026-07-15) und können abweichen — vor der Bestellung selbst prüfen. Amazon-Wunschlisten zeigen beim Einfügen automatisch die aktuellen Preise an, deshalb sind hier bewusst nicht überall feste Preise hinterlegt.

## Kernkomponenten

| # | Bauteil | Modell | Menge | Bezugsquelle | Hinweis |
|---|---|---|---|---|---|
| 1 | Mikrocontroller | ESP32-WROOM-**32U**/32UE DevKitC V4, USB-C, externe Antenne (U.FL/IPEX) | 2× | Amazon.de / AZ-Delivery / AliExpress, Suche „ESP32-WROOM-32U DevKitC external antenna“ | **Bewusst 32U/32UE statt Standard-32E** — Standardmodul hat nur PCB-Antenne, keine externe Buchse |
| 2 | WLAN-Antenne | 2,4 GHz 3 dBi Antenne + U.FL/IPEX-zu-SMA-Pigtail | 2× | Amazon.de, Suche „U.FL IPEX SMA Pigtail 2.4GHz Antenne ESP32“ | Nicht direkt an Metallteilen montieren, freie Sichtlinie im Gehäuse |
| 3 | Temp/Feuchte/Druck | Bosch **BME280** I2C-Breakout (z.B. AZDelivery GY-BME280) | 2× | Amazon.de / AZ-Delivery | SDA→GPIO21, SCL→GPIO22 |
| 4 | Zusatz-Temperatur | **DS18B20** Edelstahl-Sonde, wasserdicht, 1m Kabel | 2× | Amazon.de / AZ-Delivery „DS18B20 waterproof“ | GPIO4, 4,7 kΩ Pull-up gegen 3,3V nötig |
| 5 | Wind/Regen/Windrichtung | **SparkFun Weather Meter Kit SEN-15901** | 2× | [DigiKey](https://www.digikey.de/de/products/detail/sparkfun-electronics/SEN-15901/11570533) oder [Mouser.de](https://www.mouser.de) | Auf Amazon.de/eBay nicht sinnvoll verfügbar (nicht lieferbar bzw. deutlich überteuert). RJ11-Steckkabel. Lieferzeit vor Bestellung prüfen |
| 6 | Blitzsensor (Franklin) | **AS3935** / CJMCU-3935-Modul | 2× (ggf. 1× wenn ein Modul aus einem Vorgängerprojekt wiederverwendet wird) | AliExpress / Amazon.de „CJMCU-3935 AS3935“ | Läuft zuverlässig per **I2C** (abweichend von manchen Herstellerhinweisen, die nur SPI empfehlen — bei diesem Klon in der Praxis bewährt). EMI-empfindlich: sauberes Netzteil, kein Steckbrett, Antenne freihalten |
| 7 | Schallpegel (dBA, kalibriert) | DFRobot Gravity **SEN0232** (teils als „V2.0” verkauft), 30–130 dBA, ±1,5 dB, A-bewertet | 2× | Europäischer Distributor (z.B. Botland, DigiKey) — **nicht** über Amazon.de bestellen | ⚠️ Auf Amazon.de kursiert ein ähnlich benanntes, aber **unkalibriertes** „Analog Sound Sensor”-Modul — das ist **nicht** dasselbe Bauteil. Analog, nicht I2C. Die im Handel oft als „V2.0” gelabelte Variante ist laut [DFRobot-Wiki](https://wiki.dfrobot.com/sen0232/) hard- und softwareseitig identisch zur SEN0232 (kein eigenes Datenblatt, keine geänderte Formel/Pinbelegung) — Doku in diesem Repo gilt unverändert |
| 7b | Wetterschutz Mikrofon | 25mm-Elektroinstallationsrohr + 90°-Bogen, M20 IP68-Kabelverschraubung, Schaumstoff-Windschutz | 2× | Baumarkt (Rohr/Bogen) + Elektrofachhandel (Kabelverschraubung) + Amazon.de (Windschutzschaum) | Details: [enclosure.md](enclosure.md) |

## Gehäuse, Montage, Strom

| # | Bauteil | Menge | Hinweis |
|---|---|---|---|
| 8 | Elektronik-Gehäuse, Polycarbonat/ABS, ~200×120×75mm, IP65 | 2× | Reicht für ESP32 + BME280 + AS3935 + dBA-Modul + Klemmleisten |
| 9 | Kabelverschraubungen IP68, M12/M16/M20/M25 gemischt | 1× Sortiment (deckt beide Geräte) | Je eine Verschraubung für: Wetterkabel-Bündel, DS18B20-Sonde, Stromkabel; fürs Mikrofon separate belüftete Lösung (siehe 7b) |
| 10 | Mast/Rohrhalterung, Aluminium, U-Bolzen | 2× | Windfahne/Anemometer brauchen freien, ungestörten Luftstrom |
| 11 | Stromversorgung: wetterfeste 5V/USB-Zuleitung | 2× | Zuverlässiger als Solar, insbesondere wegen kontinuierlicher Last durch AS3935 + dBA-Sensor |
| 11b | *Alternative:* Solar (6V/1W-Panel + TP4056-Lademodul + 18650-Zelle) | optional | Nur wenn kein Kabelweg möglich — kein Low-Power-Projekt, Akku großzügig dimensionieren |

## Kleinteile

| # | Bauteil | Menge | Hinweis |
|---|---|---|---|
| 12 | Widerstands-Sortiment (u.a. 4,7 kΩ) | 1× Sortiment | Für DS18B20-Pullup |
| 13 | Schraub-/Verbindungsklemmen, Dupont-Kabel, Schrumpfschlauch | 1× Sortiment | Saubere, wartbare Verkabelung im IP65-Gehäuse |
| 14 | Silikagel-Beutel, wiederverwendbar | 1× Packung | Gegen Kondenswasser im geschlossenen Gehäuse |
| 15 | SSD1306 OLED 0,96" I2C (optional) | 2× | Alternative/Ergänzung zum Web-UI — direkt ablesbar ohne Browser, siehe [setup-guide.md](setup-guide.md) |

## Warum SparkFun statt MISOL-Fertigsensorik?

Kurzfassung: MISOL-Sets sind für den eigenen Funk-Empfänger gebaut, nicht für direkten GPIO-Anschluss. Details und Alternativwege: [misol-compatibility.md](misol-compatibility.md).

## Quellen

- [SparkFun Weather Meter Kit SEN-15901 Hookup Guide](https://learn.sparkfun.com/tutorials/weather-meter-hookup-guide)
- [Original-Datenblatt Shenzhen Fine Offset Electronics (RJ11-Pinbelegung)](https://cdn.sparkfun.com/assets/d/1/e/0/6/DS-15901-Weather_Meter.pdf) — Quelle für die RJ11-Pin-Tabelle in [wiring.md](wiring.md)
- [DFRobot Gravity SEN0232 Wiki](https://wiki.dfrobot.com/Gravity_Analog_Sound_Level_Meter_SKU_SEN0232)
- [Bosch BME280 Datenblatt](https://www.bosch-sensortec.com/products/environmental-sensors/humidity-sensors-bme280/)
- [AS3935 Datenblatt (AMS/TE)](https://look.ams-osram.com/m/6ff54cea1cf87dc2/original/AS3935-Franklin-Lightning-Sensor-IC.pdf)
