# Release checklist - 0.7.0 public test

The owner selected 0.7 as an early public testing release, rather than claiming 1.0 completeness. Existing reports confirm the basic chat triggers, search, sounds/popups, inventory, XP inactivity, GE values/thresholds, Penance and stable use. Those reports do not independently verify every effect or platform.

## Release preparation

- General, Audio, Sounds and Developer settings tabs; API/connection diagnostics and recording/export live under Developer. Recording stays opt-in.
- Optional Chat/HTTP permission requests and separate live status; no automatic grants or startup test requests.
- MIT license and original generated tones, required external PrettyUI dependency.
- Clean installable ZIP and clean source ZIP with tests/build tools; no personal audio, recordings or bundled converters.
- Source and manifest version 0.7.0; current readme, release notes, listing description and privacy explanation.
- Reproducible package checks and extracted-source verification. Automated checks do not prove native API/UI behaviour.

## In-game checks / feedback still needed

1. Save a personal preset, reload and fully restart. Confirm names, alerts and audio settings remain; verify export/import against a backup. Earlier missing presets have not been recovered.
2. Allow/deny Chat and HTTP separately through the native client, check current status, real chat triggers and Test GE connection. Test revocation. A client refusal cannot be fixed by plugin code.
3. Switch Penance to another aspect and back; replaced timer/popup should clear without a false expiry alarm.
4. Compare enabled effect timers with HUD activation, refresh and expiry, especially incense and shared book/scrimshaw timers. Keep unverified bindings marked experimental.
5. Confirm persistent red condition bars through cooldown, repeat/reset, mute and all ten sounds. Resize/switch editor tabs with a dropdown open; lobby/login/reload should not leave duplicate alarms or console errors.
6. Try the packaged ZIP with PrettyUI, without development files, preserving existing storage. Verify platform-specific playback and rendering before advertising tested support.

Exceptional raised prayer/adrenaline/Summoning caps remain deferred because the owner cannot currently test them. Platform support beyond the owner's tested environment needs independent feedback. No universal buff coverage or public native MP3 import is promised.

## Publication

Run `python3 -B tools/check_release.py --audio-assets --audio-tools` with Lua 5.4 and FFmpeg/ffprobe, then `python3 -B tools/build_source.py`. Publish the clean repository to daanpaalvastjunkmail-png/afk-alerts and attach the versioned plugin/source ZIPs to a GitHub pre-release. Keep the personal development archive private.

See PUBLISHING.md for the mod.io draft, dependency, permission tags, media and remaining submission details. Public testing does not claim Jagex approval. The owner must personally review the submitted source and applicable submission terms; the official guidelines require readable, vetted code, including when AI assisted.
