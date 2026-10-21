# Publishing 0.7.0

Target source repository: https://github.com/daanpaalvastjunkmail-png/afk-alerts
License: MIT. This document prepares a release; it is not evidence that anything has been uploaded or approved.

## Build artifacts

Requires Python 3.10+, Lua 5.4, and FFmpeg/ffprobe for optional audio checks:

```sh
python3 -B tools/check_release.py --audio-assets --audio-tools
python3 -B tools/build_source.py
```

Outputs beside the checkout: `afk_alerts_plugin.zip` (installable, files at ZIP root) and `afk_alerts_source_0.7.0.zip` (clean editable project inside `afk-alerts/`). The personal `afk_alerts_development.zip` is private and must not be uploaded.

## GitHub

Create the public `afk-alerts` repository under daanpaalvastjunkmail-png, initially empty if pushing the prepared Git repository. Push the clean source, not the private development directory. The local clean repository is prepared separately with an empty custom-sounds catalogue. Its workflow runs tests/builds when pushed; a prepared workflow has not necessarily run on GitHub yet.

Create release `v0.7.0`, titled **AFK ALERTS 0.7.0 - Public Test**, marked as a pre-release. Attach `afk_alerts_0.7.0.zip`, `afk_alerts_source_0.7.0.zip` and `SHA256SUMS.txt`. Use MODIO_RELEASE_NOTES.txt as the release body. The repository source remains editable and MIT licensed.

If publishing manually, GitHub's [new-repository form](https://github.com/new?owner=daanpaalvastjunkmail-png&name=afk-alerts&visibility=public) can create the destination. Push the prepared local `main` branch using your own GitHub authentication. Do not post access tokens into issues or chat. See [GitHub's repository guide](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository).

## mod.io submission

Follow the current [Jagex submission process](https://developer.runescape.com/rs/submission/process.html) and [guidelines](https://developer.runescape.com/rs/submission/guidelines.html):

1. Create/edit AFK ALERTS under [RuneScape on mod.io](https://mod.io/g/runescape). Use MODIO_SUMMARY.txt, MODIO_DESCRIPTION.txt and the GitHub homepage.
2. Add `media/listing.png` (1280x720) and current in-game screenshots. The listing image is branding, not a runtime screenshot.
3. Add **PrettyUI (6398181)** as a required listing dependency, matching plugin.json, plus the permission tags for optional Chat and HTTP access.
4. Upload **afk_alerts_0.7.0.zip**, version **0.7.0**, with MODIO_RELEASE_NOTES.txt. Do not upload the source/development ZIP as the runnable plugin. Select the platforms required by the submission form; availability selections do not prove platform testing.
5. Before submitting, the owner must personally review the EULA and confirm the applicable data-protection case for the official GE endpoint. The description states what is actually transmitted; do not classify all processing as local while HTTP requests are enabled. Link the published PRIVACY.md as the privacy notice.
6. Submit for moderation. If a moderator starts a submission freeze, preserve the submitted files/listing until instructed otherwise.

A GitHub release is independent of Plugin Hub approval. Native verification and any remaining listing/endpoint questions should be resolved before submitting; moderation is not a substitute for testing.
