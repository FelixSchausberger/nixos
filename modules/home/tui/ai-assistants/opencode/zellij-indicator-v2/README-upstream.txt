# opencode-zellij-indicator

> This TUI plugin is for OpenCode v2. For OpenCode v1, use the [`v1` branch](https://github.com/aidan-gallagher/opencode-zellij-indicator/tree/v1).  

**Know which of your OpenCode agents needs you — without switching tabs.**

When you run several [OpenCode](https://opencode.ai/v2/docs/) clients across
[Zellij](https://zellij.dev) tabs, they all look identical. You can't see which
one is still grinding, which is silently waiting for you to approve something,
and which finished five minutes ago.

The plugin follows the session selected in each client and uses its title and status for the Zellij tab.

## The four states

| Icon | When | What it means for you |
| ------ | ------ | ----------------------- |
| ⏳ | working | OpenCode or one of its subagents is busy — ignore it for now |
| ❓ | needs you | blocked on a permission prompt or a question — go unblock it |
| 🔔 | done, unseen | it finished while you were away — go check the result |
| ✅ | done, seen | finished, and you've already looked |

### Example

![OpenCode status icons on each Zellij tab](docs/tab-states.png)

## Naming

OpenCode gives each session an auto-generated title, and the plugin uses that as the Zellij tab name. To change it, run OpenCode's built-in `/rename` slash command.

## Stopwatch

Show how long a session has been running. After a minute, the elapsed minutes appear next to the icon:

![Stopwatch on a running tab](docs/stopwatch.png)

To disable the stopwatch set env variable `OPENCODE_ZELLIJ_STOPWATCH=0`.

## Sound

When a non-focused Zellij tab finishes (🔔) or needs you (❓), the plugin asks OpenCode to play a notification sound.

## Install

**1. Install Zellij and OpenCode.**
Requires OpenCode 2 beta 18414 or newer and Zellij ≥ 0.44.0

**2. Enable the plugin.**

```sh
opencode2 plugin add opencode-zellij-indicator
```

**3. Disable OpenCode's built-in notifications.**

To prevent duplicate sounds, update the `plugins` list in `~/.config/opencode/cli.json`:

```json
{
  "plugins": [
    "-opencode.notifications",
    "opencode-zellij-indicator"
  ]
}
```

The leading `-` disables OpenCode's built-in notification plugin.

**4. Enable notification sounds.**

Enable sounds in `~/.config/opencode/cli.json`:

```json
{
  "attention": {
    "enabled": true,
    "sound": true,
    "volume": 0.4
  }
}
```

**5. Disable OpenCode's built-in tab bar.**
This plugin uses Zellij's tab bar, so disabling OpenCode's built-in session tabs is recommended. Add this to `~/.config/opencode/cli.json`:

```json
{
  "tabs": {
    "enabled": false
  }
}
```

Outside Zellij the plugin does nothing, so it's safe to leave enabled everywhere at no cost.

**6. Run OpenCode inside Zellij.**

```sh
zellij      # opens the Zellij workspace
opencode2   # run this inside Zellij
```

That single tab now shows OpenCode's status. To feel the point of the plugin,
open more tabs and run OpenCode in each — press `Ctrl t` then `n` for a new
tab (`Ctrl t` then the arrow keys to switch between them).
