<div align="center">

# 🏙️ KASSERINE CITY

### A native 3D open-world game inspired by Kasserine, Tunisia

[![Godot 4.4](https://img.shields.io/badge/Godot-4.4-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)](https://godotengine.org)
[![Android](https://img.shields.io/badge/Android-arm64-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Gass-OS/Kasserine-City/actions)
[![Version 0.4.2](https://img.shields.io/badge/version-0.4.2-blue?style=for-the-badge)](https://github.com/Gass-OS/Kasserine-City/releases/tag/v0.4.2)
[![Build](https://github.com/Gass-OS/Kasserine-City/actions/workflows/android.yml/badge.svg)](https://github.com/Gass-OS/Kasserine-City/actions)

**You are a police officer on your first week in Kasserine. Patrol the streets, meet its people, answer the radio — and when night falls, hunt the criminals hiding in the dark.**

</div>

---

## 📖 What it is

**Kasserine City** is an open-world 3D game built with **Godot 4.4** (GL Compatibility renderer) for **Android arm64**. The city, its people, its traffic and its day/night cycle are generated in GDScript at runtime — the same Kasserine that [Phantom-Ops](https://github.com/Gass-OS/Phantom-Ops) patrols, but a different game: here you explore, patrol and investigate, in a full day that lasts 40 real minutes.

- 🗺️ **A procedural city** — streets, buildings with balconies and shops, mosque with dome and minaret, hospital, park with fountain, market stalls, palms, benches, bus stops
- 👮 **You are the police** — missions, a drivable police car with siren and flashing lights, night criminals to arrest, and a most-wanted fugitive to track down
- 🕌 **Respectful detail** — the adhan plays from the mosque five times a day, and men gather for prayer; citizens greet you in Tunisian Arabic, French and English
- 🌞🌙 **Day & night** — a full 24-hour cycle (20 minutes of day, 20 of night), weather with rain, thunder and lightning, street lamps and lit windows after dark
- 📻 **Police radio** — walkie-talkie chatter from headquarters, with a real on/off toggle

---

## 🆕 Current version — v0.4.2

### 📚 The story: your first week on the job

| Chapter | Title | What happens |
|:---:|---|---|
| 1 | **First Patrol** | Meet Amine, learn the city, your first missions |
| 2 | **The Souk Robbery** | A robbery in the market — respond fast |
| 3 | **Night Shift** | Night criminals appear — arrest them all |
| 4 | **The Most Wanted** | Track the fugitive through the market, the garage and the park |

- 🚔 **Drivable police car** — walk up to the white police car by the station, press USE to get in, drive with the joystick (RUN boosts), and switch on the **siren** with its red/blue light bar
- 🌧️ **Weather** — clear, cloudy and rainy days; rain streaks, thunder, lightning flashes, and a darker city under the clouds
- 💡 **Night lamps** — street lamps light up after dark, and the nearest cars switch on their headlights
- 📻 **Radio that respects you** — each message is a short walkie-talkie burst (a real phrase, faded out), and OFF really stops the sound
- 🚗 **Modern cars** — Kenney sports cars, race car, luxury SUV and hatchback, parked properly on the roadside, driving on the right with real following distance

### 🎯 Missions

A 7-step trail with dinar rewards: visit the school, check the police station, visit the hospital, meet at the café after dark, patrol the new park, deliver a parcel to the police station — then the **MOST WANTED** fugitive, worth 500 dinars.

### 🌙 Night in Kasserine

- **Night criminals** — three suspects with red `!` markers roam after dark; get close and press USE to arrest them (+100 points each)
- **Prayer times** — five a day on the game clock (05:00 / 12:30 / 16:00 / 18:30 / 20:00): the adhan plays and men walk to the mosque, pray, and disperse
- **Day length** — a full day is 40 real minutes by default (20 min day + 20 min night), adjustable from 1 to 60 minutes in Settings

---

## 🎮 Controls (touch)

| Control | Action |
|:---|---|
| Left joystick | Move (steer the car while driving) |
| Drag on screen | Look around |
| **JUMP** / **RUN** | Jump / sprint (boost while driving) |
| **USE** | Talk to citizens, follow missions, enter/exit the police car |
| **3RD** | Switch 1st / 3rd person camera |
| **RADIO** | Police radio on/off |
| **MENU** / **HELP** / **MISSIONS** / **MAP** | Menus, help, mission list, map |

The menu opens with a short boot animation, then an **intro film** — a drone flyover of the mosque, the market, the plaza and the police station (SKIP anytime). Android back opens the pause menu (never quits the game directly).

---

## 📦 Get the game

Every push to `main` builds an APK with GitHub Actions and publishes it as a **GitHub Release** — download **`KasserineCity.apk`** from the latest release ([Releases page](https://github.com/Gass-OS/Kasserine-City/releases)). Current APK is about **32 MB**.

> The game is not on Google Play yet — the GitHub Release is the way to install it for now.

---

## 🛠️ Build it yourself

```bash
git clone https://github.com/Gass-OS/Kasserine-City.git
cd Kasserine-City
# Open project.godot with Godot 4.4.1 — project files live at the repo root
# Android export: arm64-v8a, package com.gassos.kasserinecity
```

Pushing to `main` triggers the same build in CI — no local Android SDK needed.

### Project details

| | |
|:---|---|
| **Engine** | Godot 4.4.1, GL Compatibility renderer |
| **Language** | GDScript |
| **Genre** | 3D open-world exploration / police patrol |
| **Orientation** | Landscape 1280×720 |
| **Android** | arm64-v8a — package `com.gassos.kasserinecity` |
| **Save data** | Settings in `user://settings.cfg` |
| **Languages** | English / Français / العربية |
| **Audio** | `assets/audio/` — city ambience, adhan.mp3, police.mp3 |

> **Adhan note:** the game plays `adhan.mp3` from `assets/audio/` (bundled in the APK). Dropping your own `adhan.mp3` into the phone's `Download` folder also works. The Settings screen has **TEST ADHAN** and **TEST RADIO** buttons to check the sounds instantly.

### Project layout

```
├── menu.tscn / main.tscn   # animated menu + intro film, then the 3D city
├── scripts/
│   ├── world.gd            # procedural city, traffic, citizens, prayer
│   ├── player.gd           # touch controls, camera, driving
│   ├── gameplay.gd         # HUD, radio, story cards, missions UI
│   ├── menu.gd             # boot animation, settings, test buttons
│   ├── daynight.gd         # sun/moon cycle + clock
│   ├── missions_plus.gd    # 7-step mission trail + most wanted
│   ├── city_audio.gd       # ambience, adhan, rain, thunder
│   ├── intro_film.gd       # drone flyover intro
│   └── night_glow.gd       # lamps, headlights, lit windows
├── assets/
│   ├── cars/               # Kenney Car Kit models (CC0)
│   ├── audio/              # city ambience, adhan, police radio
│   └── characters/         # Kenney character models (CC0)
└── icon.png                # teal-sunset city icon
```

> **Build note:** Android export uses the prebuilt template (`use_gradle_build=false`) with ETC2/ASTC texture import enabled. Don't re-enable Gradle.

---

## 📜 Version history

| Version | Highlights |
|:---:|---|
| **0.4.2** | Drivable police car, night lamps, modern cars, radio burst, parked cars fixed, night-transition hardening |
| 0.4.1 | Night light floor, grounded cars, radio burst, fullscreen, less glare |
| 0.4.0 | Intro film, story chapters, Kenney cars, weather + rain, radio toggle, adhan timing |
| 0.3.2 | MP3 loader fix (adhan + radio now load from the APK) |
| 0.3.1 | Moving cars, sound fix, adhan + police MP3, 20+20 min day/night |
| 0.3.0 | 1st/3rd person camera, hospital + park, radio, night criminals, more missions |
| 0.2.0 | Facing/animations, car collision, ground fix, balconies, icon, back-button menu |
| 0.1.0 | First playable city — missions, citizens, day/night |

---

<div align="center">

**Made with Godot in Kasserine, Tunisia 🇹🇳**

*A Gass-OS game — explore the city, meet its people.*

</div>
