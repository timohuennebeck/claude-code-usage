# Claude Usage (menu bar)

A macOS menu bar item showing how much of your Claude Code rate limit is used and when it resets, for both the 5-hour and 7-day windows.

- Bar and percent turn amber at 60% and red at 85%.
- Two dots show which window is displayed: left is 5h, right is 7d, and the active one is stretched into a pill. **Left click** flips between them.
- **Right click** shows both windows with reset times, Refresh, and Quit. plus the weekly per-model usage.
- Refreshes every 5 minutes and after wake. The usage API rate-limits harder than that, so on HTTP 429 it backs off up to 30 minutes. The item dims when the last successful refresh is over 15 minutes old, and the right-click menu shows the error and last update time.

It reads the OAuth session Claude Code already stores in the macOS Keychain (`Claude Code-credentials`), falling back to `~/.claude/.credentials.json`. Nothing is written; if the session has expired, run `claude` once to sign in again.

## Build and run

```sh
./build.sh                      # -> dist/ClaudeUsageBar.app
open dist/ClaudeUsageBar.app
```

Start at login: System Settings → General → Login Items → add `ClaudeUsageBar.app`.

## Develop

```sh
swift test                      # formatting, thresholds, decoding
swift run ClaudeUsageBar --check   # print current usage to the terminal
swift run ClaudeUsageBar --raw     # raw usage API JSON
swift run ClaudeUsageBar --render out/   # PNGs of the item states
```
