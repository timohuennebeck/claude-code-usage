# Claude Usage (menu bar)

A macOS menu bar item showing how much of your Claude Code rate limit is used and when it resets, for both the 5-hour and 7-day windows.

- Bar and percent turn amber at 60% and red at 85%.
- Two dots show which window is displayed. **Hover** swaps the percent for the window label ("5h"/"7d") without shifting the layout. **Left click** flips between 5h and 7d.
- **Hover** for a moment to open a card with both windows, the weekly per-model breakdown, and the plan.
- **Right click** shows both windows with reset times, Refresh, and Quit.
- Refreshes every minute and after wake.

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
swift run ClaudeUsageBar --render out/   # PNGs of the item states and hover card
```
