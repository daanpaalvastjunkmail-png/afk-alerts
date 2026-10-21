# Contributing to AFK ALERTS

You are welcome to try the plugin, share presets, report problems or submit code. The project is MIT licensed. Contributions are made under the same license.

## Find your way around

- `main.lua`: runtime subscriptions and cleanup.
- `src/core`: settings, presets, thresholds and shared state.
- `src/ui`: monitor, editor, settings and sharing controls.
- `src/chat.lua`, `src/prices.lua`, `src/timers.lua`: live inputs and permission boundaries.
- `src/recorder.lua`: opt-in effect diagnostics, available through Settings > Developer.
- `presets`: shareable Gregorovic imports.
- `tests`: Lua API/UI mocks and Python packaging/audio checks.
- `tools`: release builders, sound generation and diagnostic analysis.

Install Python 3.10+ and Lua 5.4, then run `python3 -B tools/check_release.py`. FFmpeg/ffprobe are needed only for `--audio-assets`, `--audio-tools` or sound generation. No game client is needed for automated tests. A real client and PrettyUI are needed to check UI rendering and live bindings.

Keep changes focused. Explain the user-visible behaviour and how you checked it. A mock passing does not establish native client behaviour. Document new timer bindings as experimental until activation, refresh and expiry match the HUD. Keep unknown readings explicit; never make up a zero value or duration. Preserve saved keys/preset compatibility, and do not introduce gameplay automation.

Do not commit personal imported audio, presets containing private phrases, effect recordings, account information or converter binaries. Public builders use file allowlists. `src/custom_sounds.lua` is an empty public catalogue; local users may edit it. Add a custom audio file only when you own redistribution rights and intend it to be public.

## Reporting an issue

Open an issue with the plugin version, operating system/client, steps, expected result, actual result and relevant console error. For a timer include its exact alert name and HUD comparison. For UI bugs include window dimensions and a screenshot with personal information removed.

If useful for a specific timer problem, use Settings > Developer to start a recording, activate/refresh the effect, then Stop and Show recording. Review any exported file before sharing. Recording is optional and does not run by default. Do not post received chat or account credentials.


## AI origin and code review

The creator does not code; AI (OpenAI Codex) wrote the implementation under the creator’s direction. See AI_DISCLOSURE.md. Experienced developers can help by reviewing small, concrete areas, explaining the behaviour and risks to the creator, and proposing focused changes. Please distinguish automated/mock checks from live testing and independent human review. Jagex requires the submitting creator to personally review and understand submitted code; this project does not claim that has already happened.
