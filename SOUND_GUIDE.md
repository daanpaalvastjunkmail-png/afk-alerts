# Sounds

The public AFK ALERTS ZIP includes the project's generated built-in **Ogg Vorbis** tones. It includes no personal sound clips, MP3 files, desktop shortcuts, converters or codec libraries.

Set master volume/mute in the monitor toolbar and individual volume/mute in each alert. Both volumes multiply; the RuneScape audio channel volume also affects playback. **Sound only** previews the selection. Click ADD or SAVE to commit alert edits.

## Built-in choices

Sine (the existing tone), Saw, Square, Alarm, Ring, Beep, Chime, Siren, Double Alarm and Urgent Pulse. Saw and Square use a 165 Hz fundamental, two octaves below their original pitch. Triangle is removed; saved Triangle selections fall back to Sine. Use Edit > Sound > Alert sound and Sound only to preview. Custom imports remain available alongside these ten choices.

After updating a local development copy with these new audio files, run each command separately:

```text
poff rs3_alerts_plugin
prf
pon rs3_alerts_plugin
```

A script reload alone may not discover new resource files. Existing alert-specific names such as `prayer.mp3` remain readable and now select Sine. Original legacy OGG resources remain packaged for compatibility; they are hidden from the picker. The game plays OGG, not MP3.

## Custom OGG files in a local development installation

1. Use an editable plugin installation. Put a file you have permission to use in `resources/sounds/name.ogg`.
2. Refresh local resources using the development client console, entering separately: `poff rs3_alerts_plugin`, `prf`, `pon rs3_alerts_plugin`.
3. Open Edit → Sound → Alert sound, select the file, preview it, then SAVE.

Settings → Sounds shows the installation folder when an absolute resource path is available. Locate the folder containing `plugin.json` if that path is absent. Installation paths vary by platform. Custom files are separate from shared preset codes. Editing managed Plugin Hub resources is not a verified import workflow and updates may replace local files.

Legacy built-in `.mp3` identifiers select the built-in Sine tone. Custom `.mp3` identifiers from the Linux importer still select their own converted OGG file.

## Separate Linux development helper

The public source includes `tools/import_mp3.py`, which uses a system FFmpeg installation. A private development checkout may also retain a locally tested Linux converter; converter binaries are not part of the public source. Run it with an MP3 path to convert to OGG and update the local catalogue. It writes **afk_alerts_development.zip**, which is a personal development bundle, not the public upload ZIP. Existing local custom sounds remain untouched by the clean public-package builder.

This optional helper is not included in the public ZIP. Wider Linux compatibility and Windows/macOS conversion are unverified. The locally bundled third-party converter libraries are excluded from public distribution; completing their source/licence packaging is outside this built-in-audio release.
