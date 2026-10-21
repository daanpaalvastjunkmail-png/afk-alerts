# Alerts and presets — AFK ALERTS 0.7.0

## One monitor for everyday editing

Click **+** to add an alert or named effect. Alert name sits above the Select alert button; expand it to browse a category or search all alerts. Category and search share one framed chooser at equal widths. Click a result, or press Enter for the first result. Partial words (eal), extra words (health alert), and abbreviations (hp, ovl, afk, inv) are supported. Changing category selects its first alert. Large categories use pages of at most 20 choices.

The editor has Trigger, Sound and Display tabs. Repeat, cooldown and applicable reset controls are directly under Trigger. Settings > General > Show help text controls explanations for all alerts and defaults on. Recent chat remains an optional clickable list. Test, Sound only, Cancel and ADD/SAVE remain in a fixed footer. The editor defaults to 820 × 580 interface units and is resizable. ADD creates an entry; a monitor checkbox pauses it, Edit changes it, Test previews it, and × removes it. Up to 32 independent alerts can run.

## Presets dropdown

Click **Presets** at the top right of the monitor to expand the compact preset controls below the toolbar. Click again to hide them. Loading closes the dropdown automatically. There is no bottom bar. The dropdown contains preset selection, Load, Export, a disk for Save, a rename pencil and a trash icon. The top toolbar has Add, the native Settings cog and master audio controls. The volume slider fills the space before Presets. The native audio icon shows a red slash when muted. An open preset dropdown has a bottom separator and an underlined Presets button. Action labels use a small font. Routine hints and success messages do not occupy a dropdown row; errors still appear. Undo sits beside the dropdown.

1. Choose a saved or included preset, then click **Load** to apply it. Selecting alone leaves running alerts unchanged.
2. Use +, Edit, pause or remove on the monitor to change that setup.
3. Click **Save** to update the selected personal preset.

There is no second full preset editor in the normal workflow. Alert forms still use drafts: SAVE commits an alert's edits; Cancel discards them. The monitor's preset Save stores the running setup, not any uncommitted alert form. Loading another preset closes an alert form to prevent committing its old draft into the new setup.

## Save, name and rename

The dropdown contains real presets only. The disk saves your current running alerts into the selected personal preset. Selecting an included preset and saving creates a personal version. Use the pencil to enter a different name when creating a personal version.

Click the **pencil** to rename a saved preset inline. Enter the name and press Enter or Save. Cancel retains the old name. Renaming changes saved metadata without replacing current alerts. Renaming to a different personal preset's name is rejected.

Saving a new setup with an existing personal name updates that preset, consistent with earlier versions. Names ignore case and outer spaces. Up to eight personal presets can be stored. Failed library writes retain the existing stored data.

Included presets are AFK Skilling, Overload Timer, Drop Alert and Bossing. Saving one creates a personal version. A personal version with the same name is shown once in the quick list; the included original reappears if the personal version is deleted. Included originals cannot be deleted. The full original remains defined in the bundled catalogue.

## Delete and Undo

Select a personal preset and click the **trash** icon. Check its name, then Delete or Cancel. Deleting keeps the running alerts. Undo restores the latest deleted preset into its old slot, or another free slot, without overwriting a replacement.

After loading a preset, Undo restores the preceding running setup. Undo history is session-only. The selected preset is remembered across reloads, but reopening the monitor does not reload that preset over the persisted current alerts.

## Sharing instead of another full editor

The **Export** button opens the sharing window with the selected saved preset code ready to copy. Click Save first to include changes to your running alerts. The sharing window also offers:

- **Export current alerts** produces the current setup with the selected preset name. This includes committed edits even if preset Save has not been clicked.
- Select the code field and press Ctrl+A / Ctrl+C. Large codes use 8,000-character pages; copy all parts in order using Next part.
- Paste a complete code into Import preset code, then click **Import & load**. It is validated, saved as a personal preset and loaded into the monitor.
- For multiple pages, paste one exported part at a time and click **Add part** after each. Then click **Import & load**. **Clear import** discards accumulated parts so you can start again. Pasting an entire code at the native 9,999-character field limit is rejected.
- New exports begin with `AFKPRESET/1` and include the payload length and a checksum. Missing, reordered or damaged parts are rejected. These transfers require AFK ALERTS 0.6.46 or newer; existing RS3ALERTS/1 and RS3ALERTS/2 codes remain importable.
- A personal-name collision on import creates a separate copy. If all eight slots are full, import fails without replacing running alerts.
- **Edit entity highlights** opens optional highlight settings.

Shared presets contain alert/highlight configuration, not received chat messages, global master audio or sound files. Transfer custom audio files separately. Existing v1/v2 codes and eight personal storage slots remain compatible.

## Activity reminders

Add **Skilling stopped** and choose a skill. The monitor arms after it observes that skill gain XP, then measures seconds without another gain. Use a delay longer than your activity's normal cycle. Separate entries can monitor different skills independently. Pausing/editing one does not clear another entry's XP baseline.

The monitor cannot distinguish a stopped action from delayed XP, long actions, waiting or an XP cap. It does not automate the game or prevent logout.

Add **Inventory full** for occupied backpack slots. Above 27 triggers at 28 occupied slots, resetting when a slot becomes free. Pouches and other containers are outside this source.

## Chat reminders

Choose **+ → Category: Chat messages → Chat message**, enter a trigger phrase, choose its channel and click ADD. Grant the optional Chat access permission. The Recent messages picker updates automatically, showing eight messages per page from the last minute for the selected channel (up to 80 retained messages). Use Newer/Older messages to navigate; Click a message row to copy it into the trigger field without saving it. Edit the phrase as needed, then ADD/SAVE. Received messages are kept only in memory; chosen trigger text is saved as alert configuration. The editor shows recommended filters for that channel; game-message triggers should be tested with Game messages set to All. Presets save the phrase, matching options and cooldown, never received chat messages. Multiple independent chat entries are supported. Numeric thresholds/hysteresis do not apply to this event trigger.

## Preset entity highlights

Presets → **Export** → **Edit entity highlights** configures matching NPCs/world objects and tile outlines for the running alerts. Save the preset afterward to include those settings. Names use case-insensitive exact or plain-text contains matching. These are world-depth-tested tile markers, not model silhouettes.

## Version 2 format

Stored presets still use Version 2. The sharing UI wraps that data in `AFKPRESET/1;<payload byte length>;<eight-digit FNV-1a checksum>;<payload>`. This is a transfer integrity check, not proof of the sender's identity. It prevents incomplete native-field pastes from silently becoming default settings. The wrapper does not change existing saved slots.

Codes start with `RS3ALERTS/2`, followed by semicolon-separated `key=value` records. `count` declares the number of entries. Entries have contiguous numeric indices and a required type. Values use percent escapes; `%20` is a space. Export produces one line, which is convenient for the game's input field. Comments starting with `#` and newline-separated records are supported in text files too.

Example with two independent health entries:

```text
RS3ALERTS/2;name=Two%20health%20warnings;count=2;entries.1.type=health;entries.1.enabled=true;entries.1.threshold=50;entries.2.type=health;entries.2.enabled=true;entries.2.threshold=10;entries.2.volume=100;entries.2.visuals.flash=true
```

Fields not specified start from that entry type's defaults. An explicit `count=0` represents an empty alert list. Highlighter settings use `highlighter.*`. Global audio and saved slots are outside the format. Exporting through the UI is the easiest way to create a complete code.

Validation rejects unknown paths/types/options, invalid escapes, duplicate keys, missing/sparse entries, non-finite or out-of-range numbers, more than 32 entries and input over 64 KiB. Imported text never runs as Lua, shell commands or URLs.

Version 1 codes and old saved slots remain readable. Their listed/enabled types become independent entries in the new model. Old persisted configuration migrates the same way; new list records prevent removed entries from reappearing from legacy keys.

## Current limitations

New effect bindings, target reminders and the latest preset controls still need native acceptance. User-confirmed features are listed in V1_READINESS.md. Automated tests use mocks and do not certify every live effect or platform.

## Gregorovic AFK

Four requested method variants are included alongside the four general presets: Gregorovic AFK - Magic, Melee, Necromancy and Ranged. Select one and press Load. See [GREGOROVIC.md](GREGOROVIC.md) before use; effect timers require HUD validation and do not verify your equipment or active prayers. Standalone imports: `presets/gregorovic_magic.txt`, `gregorovic_melee.txt`, `gregorovic_necromancy.txt`, `gregorovic_ranged.txt`.

## Monitor warning state

The progress bar stays red while the alert engine considers the condition active, including any configured reset gap. It stays red between repeated sounds and after dismissing a popup. Even an empty progress bar has a red track when triggered. Each firing briefly highlights the status text gold and adds ALERT for 1.2 seconds. Reset, pause or unavailable live data clears the red bar. Test highlights a firing preview without changing the live trigger state.
