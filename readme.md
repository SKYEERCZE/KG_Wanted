# KG_Wanted (Kafíčko NONRP wanted stars)

## Features
- GTA-style wanted stars (0–5)
- Auto stars for hurting/killing players
- Police see wanted:
  - 3D "WANTED ★★★" above head (police only)
  - Search zone map blip for wanted >= 2★
- Police interaction (ox_target): "Poslat do basy"
  - No handcuffs system, only optional anim + progress
  - Immediately teleports target to jail for X minutes based on stars
- Built-in simple jail (teleport + countdown)

## Requirements
- es_extended
- ox_lib
- ox_target

## Install
1) Put folder `KG_Wanted` into your resources.
2) Ensure dependencies:
   - ensure ox_lib
   - ensure ox_target
   - ensure KG_Wanted

## Config
Edit `config.lua`:
- PoliceJob name (default: police)
- Stars values
- Visibility distances
- Jail coords and minutes per star
