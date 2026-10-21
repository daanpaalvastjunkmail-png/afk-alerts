# License, dependencies and asset provenance

AFK ALERTS project code, documentation, preset definitions and original generated built-in OGG tones are distributed under the MIT license in LICENSE. Copyright (c) 2026 AFK ALERTS contributors. The license does not grant rights to third-party content.

The built-in tones were generated locally for this project. Sine retains the existing health OGG. The other nine selectable tones are synthesized by `tools/generate_builtin_sounds.py` using Python mathematics and an external FFmpeg/libvorbis installation. Legacy generated OGG tones remain for saved-selection compatibility. Both supported resource layouts contain the same audio payloads. The public source includes the generator; generated audio does not embed the converter software.

PrettyUI is a required external dependency (mod.io ID 6398181), supplied separately by its author. Its code and assets are not bundled or relicensed by this project. Declare this dependency on the mod.io listing as well as in plugin.json. Documentation: https://prettyui.j3.gg/

RuneScape, Jagex, game interfaces, API identifiers and native UI artwork belong to their respective owners. Native icons are referenced through the installed client/library; image files are not redistributed. AFK ALERTS is a community plugin and has no claim of Jagex endorsement.

Public plugin/source archives exclude personal imported audio, MP3 source files, converter executables and codec libraries. The optional importer invokes an external converter installed by the user. A private development checkout may contain a local converter bundle with separate notices; it is excluded from this open-source release.

Gregorovic preset definitions are original plugin configuration, informed by the linked PvME guide. The guide's text, screenshots and embedded inventory assets are not bundled. Follow the current guide for gameplay setup; the preset is not a validation of gear or prayers.
