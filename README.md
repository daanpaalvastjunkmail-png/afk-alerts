# AFK ALERTS

**0.7.0 public testing release** for the RuneScape Client API. Create configurable audio and visual reminders while you play. Feedback, bug reports, presets and code contributions are welcome.

Requires **[PrettyUI](https://mod.io/g/runescape/m/prettyui)** (mod.io ID **6398181**). AFK ALERTS is a community project, with no Jagex endorsement. The 0.7 release is for public testing; wider effect coverage and platform compatibility still need in-game feedback.

## Download and try it

Download the ready-to-run plugin ZIP from [Releases](https://github.com/daanpaalvastjunkmail-png/afk-alerts/releases). This repository's source archive includes tests and build tools; the plugin ZIP is the smaller package intended for installation. Releases will appear there after publication.

For a local test installation using a client with local-plugin support:

1. Install/enable PrettyUI through Plugin Hub.
2. Extract the plugin ZIP into a folder named `rs3_alerts_plugin`, directly containing `plugin.json`, `main.lua`, `src` and `resources`.
3. In the client developer console, set `plugins_setpath` to the **parent** of that folder. This changes the client's local plugin search path; use your existing plugins directory if you already have local plugins.
4. Run `prf`, then `pon rs3_alerts_plugin` as separate commands. Use `prl rs3_alerts_plugin` for later script reloads. After adding resources, disable the plugin, run `prf`, then enable it again.
5. Open AFK ALERTS from the plugin ribbon. Allow optional Chat/HTTP access only if you want those features.

These console commands are documented in the [official local-plugin guide](https://developer.runescape.com/rs/managing.html). If your client does not expose local-plugin support, use the Plugin Hub distribution once it has been submitted and approved. GitHub publication does not imply Plugin Hub approval.

If you already use AFK ALERTS, export personal presets before updating and preserve your existing plugin identity/storage. Do not delete or reinstall it to update. Moving between a local copy and a managed Hub copy is not a verified storage migration; keep exported backups.

## What it does

- Threshold reminders for health, prayer, adrenaline and Summoning points.
- Supported effect timers, searchable by partial words and abbreviations (`eal`, `hp`, `ovl`). Many expanded bindings are experimental.
- Inventory-full and skilling-stopped reminders.
- Owned ground-item drop alerts by item count, GE guide value or High Alch value.
- Incoming chat word/phrase alerts, with a clickable picker of recent messages.
- Persistent text popups, monitor progress bars and optional flashes/row circles. A bar stays red while its real alert condition is active, independently of the sound cooldown.
- Master and individual volume/mute, with ten built-in sounds and optional custom OGG audio.
- Personal presets with save, rename, load, delete/Undo and code import/export. Includes four general presets and four Gregorovic AFK variants.

AFK ALERTS reads game data and displays reminders. It does not click, cast, equip, switch prayers or otherwise automate gameplay.

## Add an alert

Open **+**, choose or search for an alert, then configure **Trigger**, **Sound** and **Display**. Click **ADD**. **Edit → SAVE** commits changes; Cancel discards the draft. Up to 32 independent alerts can run, including multiple alerts of the same type.

Each monitor row has pause, Edit, Test, remove and volume controls. Test previews presentation; it does not prove a live timer or chat trigger is connected. Use a real matching event to check detection. Repeat, cooldown and reset controls are directly under Trigger. Numeric thresholds use strict above/below comparisons; hysteresis controls rearming.

**Presets** opens the controls at the top right. Select a preset and Load to replace the running alerts; save your current set first. The disk saves to the selected personal preset, the pencil renames and the trash deletes with confirmation. Export/share codes include configured trigger phrases but no custom audio or received chat history. See [PRESETS.md](PRESETS.md) and [GREGOROVIC.md](GREGOROVIC.md).

## Settings

- **General:** global help text (on by default) and optional Chat/HTTP permissions with current access status.
- **Audio:** master volume/mute, game audio channel and sound preview.
- **Sounds:** instructions for adding your own Ogg Vorbis files to an editable local installation.
- **Developer:** connection status, API snapshots, resource-limit diagnostics and optional effect recording/export. Recording is off until you start it. You do not need these tools for normal alerts.

Built-in sounds: Sine, Saw, Square, Alarm, Ring, Beep, Chime, Siren, Double Alarm and Urgent Pulse. Saw/Square use 165 Hz; old Triangle selections fall back to Sine. Built-in legacy names remain readable. Personal sound clips and converter binaries are excluded from public downloads. See [SOUND_GUIDE.md](SOUND_GUIDE.md).

## Permissions and local data

**Chat access** is optional, for incoming-message triggers and their temporary history picker. **HTTP access** is optional, for GE guide prices from `https://secure.runescape.com`. These permissions are independent. Use **Settings → General → Manage permissions**, or the AFK ALERTS padlock in Plugin Hub. A request does not grant access automatically. GE editors offer Request HTTP access and Test GE connection.

No developer telemetry is collected. Settings, presets and explicitly saved diagnostic recordings use the client's local PersistentDB. Received chat history is temporary; configured trigger phrases are part of saved/shared alert settings. Item-price requests contain item IDs and ordinary HTTPS connection metadata, not chat text. See [PRIVACY.md](PRIVACY.md).

## Known limits

- Many effect bindings need HUD validation. Timers arm after an active effect is observed; a never-observed missing buff does not produce a setup-failure alarm.
- Shared book/scrimshaw timers cannot verify the correct item or activation. Player-poison detection is unavailable; weapon poison is an expiry reminder, not a poisoned-player warning.
- Exceptional raised prayer/adrenaline/Summoning caps are unverified. Health/effective maximum and overhealing work in the owner's tested states.
- GE prices are guide prices, not guaranteed sale prices. Only matching owned ground drops count; bank withdrawals/trades do not.
- Monitor circles belong to plugin rows, not the native HUD or cursor. Highlights are experimental tile outlines, not model silhouettes.
- The new permissions flow still needs native acceptance. A client refusal to change a permission cannot be overridden by plugin code.
- Windows/macOS compatibility needs independent feedback. Automated API mocks cannot prove client rendering or platform compatibility. Custom OGG installation through managed Hub resources and Windows MP3 import are unverified.
- Earlier missing personal presets have not been recovered. Storage protections/backups help prevent overwrites; they cannot recover data already absent before those protections existed.

See [EFFECT_COVERAGE.md](EFFECT_COVERAGE.md), [BUFF_DURATIONS.md](BUFF_DURATIONS.md) and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for detailed checks.

## Build, test and contribute

Requires Python 3.10+ and Lua **5.4** (`lua` and `luac` on PATH). No Python packages are needed. From the repository root:

```sh
python3 -B tools/check_release.py
```

This runs the Lua tests, syntax checks, recording analyzer, public/source packaging checks and builds `../afk_alerts_plugin.zip`. The installable ZIP has `main.lua` and `plugin.json` at its root. Add `--audio-assets` to decode/check the tones, or `--audio-tools` for the optional MP3 helper; both need system FFmpeg/ffprobe. Public source includes the helper script, with no converter binaries or personal clips.

`python3 -B tools/build_source.py` builds the clean source archive. [CONTRIBUTING.md](CONTRIBUTING.md) explains the project layout and how to report a problem. [PUBLISHING.md](PUBLISHING.md) describes GitHub and mod.io release preparation.

## License and support

MIT: see [LICENSE](LICENSE). Original generated built-in tones are included under the same license. External dependencies, client artwork and RuneScape/Jagex names remain their owners' property; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Source/project: [daanpaalvastjunkmail-png/afk-alerts](https://github.com/daanpaalvastjunkmail-png/afk-alerts) (publication pending). Support: **daan9_9@hotmail.com**. For bugs include version, platform, reproduction steps and console errors; remove personal chat from screenshots and recordings before sharing.
