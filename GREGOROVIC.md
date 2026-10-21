# Gregorovic AFK presets

Based on the [PvME Gregorovic guide](https://pvme.io/pvme-guides/afk/afk-gregorovic/) and its linked [AFK overview](https://pvme.io/pvme-guides/afk/afk-overview/), checked 20 October 2026.

Choose **Presets**, select **Gregorovic AFK - Magic**, **Melee**, **Necromancy** or **Ranged**, then **Load**. Loading replaces the running alert list; it does not overwrite saved presets. Save your current alerts first if you want to keep them. The matching `presets/gregorovic_*.txt` files can also be imported separately.

Each variant monitors low health and prayer, overload, weapon poison, powder of penance and enhanced luck. Inventory and loot alerts are included. The style-specific timer choices are:

| Method | Additional effects |
| --- | --- |
| Magic | Kwuarm, Irit if used instead of Venomblood, Amascut book charge |
| Melee | Kwuarm, Irit if used, Vampyrism aspect, vampyrism scrimshaw charge |
| Necromancy | Ful book charge |
| Ranged | Irit if used, Amascut book charge |

All variants warn when Darkness is active. Player-poison detection is unavailable: the previously used poison timer also reacts to weapon poison, so that warning has been removed. Darkness is an unwanted effect for these methods, not an expiry reminder. Vampyrism aspect and Vampyrism aura are different effects: this plugin cannot currently monitor the ranged aura or the necromancy Equilibrium aura. Check those manually.

## Alert thresholds

These are editable plugin choices, not thresholds prescribed by PvME:

- Health below 40%, repeating every 10 seconds until reset; prayer below 20%, repeating every 15 seconds.
- Overload and weapon poison below 30 seconds.
- Powder, luck and relevant incense below 60 seconds; pocket timer below 120 seconds. Expiry reminders repeat every 30 seconds.
- Darkness warns above zero remaining time and repeats every 30 seconds.
- Backpack above 27 occupied slots; owned ground drops above 100,000 coins in GE guide value. GE requires HTTP permission.

Familiar duration is included but paused until you choose to use it. Melee's optional bonfire reminder is also paused.

## What still needs checking in-game

An expiry timer only arms after an active effect has been observed. A never-used, missing or unavailable effect does not produce a setup-failure warning. Compare every enabled timer with your HUD; several exported bindings remain unverified. Book and scrimshaw bindings are shared and cannot verify the correct item or whether it is switched on.

These presets do not check gear, perks, relics, positioning, Revolution bars, active prayers, aura, ammunition, familiar health or instance/lobby time. Follow the guide for those. Do not add Vulnerability or Smoke Cloud reminders unless you deliberately change the method to apply them manually. Loading a preset does not equip items, cast abilities or activate prayers.
