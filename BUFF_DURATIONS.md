# Automatic buff duration references — 0.6.20

Remaining time always comes from the live effect-end timestamp (`end / 50 - Logic seconds`). Looking up a duration never starts a synthetic countdown or establishes that a buff is active. The manual full-duration field has been removed from every supported timer editor. Old `timerMaximum` values remain readable in saved presets for compatibility but are ignored by runtime timer readers.

| Binding / effect | Researched duration | Automatic percentage reference |
| --- | --- | --- |
| Overload | 6-minute ordinary base | Base 360 seconds, expanded when a longer live timer is seen |
| Dungeoneering overload | Exact binding-specific base not established | Longest observed remainder |
| Antifire | 6-minute ordinary base | Base 360 seconds, expanded by live observations |
| Super antifire | 6 minutes; extended variant 12 minutes | Longest observed remainder; shared timer does not identify the variant |
| Aggression potion | 6-minute base | Base 360 seconds, expanded by live observations |
| Familiar | Varies by familiar and extensions | Longest observed remainder; no invented universal lifetime |
| Prayer renewal | Ordinary potion 5:10; combination potion effects 6:00 | Longest observed remainder; shared binding does not identify the potion |
| Summoning renewal | 6-minute base | Base 360 seconds, expanded by live observations |
| Animate Dead | 12-minute base | Base 720 seconds, expanded by live observations |
| Darkness | 12-minute base | Base 720 seconds, expanded by live observations |
| Weapon poison | Ordinary 2:30; + 5:00; ++ 10:00; +++ 12:00 | Longest observed remainder; shared timer does not identify the strength |

These were the original 11 timer bindings; see EFFECT_COVERAGE.md for the 0.6.31 expansion. The catalogue is not a universal source for every game buff/debuff. Known bases are references, not a claim that every extended or stacked state has exactly that total lifetime. In particular, incense, combinations, event boosts and stackable casts can produce longer live timers. No extension cap is imposed by the lookup table.

The automatic reference stays fixed while counting down and expands if a larger remainder is observed. It resets after observed expiry/reapplication, lost timer data, a backwards clock or changing the selected timer. An extension or reapplication without an observed inactive interval preserves the larger reference. If tracking starts midway through a variable/extended buff, its original full lifetime cannot be recovered from an end timestamp alone. Its percentage is therefore explicitly an observed reference. Use an absolute seconds-remaining threshold when the alert must be independent of that uncertainty.

An expiry can alert only after the entry has observed an active effect. Missing data never counts as expiry. Animate Dead functioning in the client was confirmed by the user; other lifecycle/variant checks remain separate from duration research.

## Research sources

Checked 19 October 2026. Search excerpts were used where direct wiki fetches were unavailable. Sources describe gameplay durations, not the native variable bindings or their units.

- [RuneScape Wiki: Aspects](https://runescape.wiki/w/Aspects) — Animate Dead and Darkness base durations.
- [Jagex: Necromancy Community Feedback Update #2](https://secure.runescape.com/m=news/necromancy-community-feedback-update---2) — Darkness increased to 12 minutes.
- [PvM Encyclopedia: Magic abilities](https://pvme.io/pvme-guides/miscellaneous-information/ability-information/magic-abilities/) — Animate Dead duration.
- [RuneScape Wiki: Recommended equipment for PvM](https://runescape.wiki/w/Recommended_pvm_gear) — ordinary/extended antifire and weapon poison variants.
- [RuneScape Wiki: Potions](https://runescape.wiki/w/Potions) — overload/combination potion effects and renewal variants.
- [RuneScape Wiki: Aggression potion](https://runescape.wiki/w/Aggression_potion) — six-minute dose.
- [RuneHQ: Summoning renewal](https://www.runehq.com/item/summoning-renewal-4) — six-minute renewal.
- [RS PocketBook: Prayer potions](https://www.rspocketbook.com/consumables/potions/prayer) — 310-second ordinary prayer renewal.
- [RuneScape Wiki: Firemaking](https://runescape.wiki/w/Firemaking) — lantadyme incense extends eligible potion timers.

## Expanded automatic policies (0.6.31)

Penance and Vampyrism use a 720-second aspect base reference, expanded when longer live remainders are observed. All 18 incense endpoints use a 600-second initial reference with observed stacking. Powder of penance uses 1,800 seconds as the initial reference, expanded by a longer live timer. Shared pocket-item charge endpoints and other new endpoints use observed references without an invented lifetime. Each new binding is explicitly marked as requiring HUD validation.

Vulnerability/Smoke Cloud reminders are binary NPC-target status checks. They have no duration reference or fabricated spell expiry; they alert after two seconds of known missing status.

Research: [Jagex staff aspect announcement](https://www.reddit.com/r/runescape/comments/1snv4ap/aspects_solomons_store_news_update_2/) describes 12-minute aspect casts and multicasting. [PvM Encyclopedia consumables](https://pvme.io/pvme-guides/upgrading-info/consumables/) documents incense stacking and powder stacking. Gameplay durations do not validate API variable units or pocket-item bindings.
