# dev-bootstrap

A small interactive bootstrapper for a new Mac. It checks Homebrew and Git first, then lets you select Warp, DataGrip, Bruno, Raycast, mise, and your zsh setup. Installed items are skipped, and every change is shown before it runs.

## Quick start

Download this repository as a ZIP from GitHub, unzip it, open Terminal in the extracted folder, and run:

```sh
./bootstrap.sh
```

Type item numbers to select them, `0` to review the plan, and `y` to apply it. See [the new Mac guide](docs/usage.md) for the full sequence and notes about restoring the prompt.

The zsh option includes the Powerlevel10k prompt imported from the original Mac, Meslo font, command suggestions, completion, searchable history, and mise activation when installed. The script supports macOS only. It does not copy secrets or sign in to apps.
