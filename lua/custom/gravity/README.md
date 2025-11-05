# gravity.nvim

Intelligent config file sync plugin for Neovim with three-way conflict detection and machine-specific overrides.

## Documentation

For complete documentation, including usage guide, testing, and architecture, see:

**https://sao.bros.ninja/projects/gravity/**

## Quick Start

```vim
" Check what needs syncing
:GravityStatus

" Interactive sync workflow
:GravitySync

" View diff for specific file
:GravityDiff .bashrc
```

## What It Does

- Syncs config files from `~/.config/nvim/configs/` to system locations
- Detects conflicts using three-way comparison (repo, system, last-sync)
- Supports machine-specific overrides via `configs.overrides/`
- Automatic backups before overwriting files
- Interactive menus for reviewing changes

## Features

- 7 status states tracked (unchanged, source_changed, system_changed, conflict, etc.)
- Dual override system (manifest + file overrides)
- Color-coded interactive workflow
- Comprehensive test coverage (14 tests)
- Works with any file type (configs, agent prompts, scripts)

---

**Full Documentation**: https://sao.bros.ninja/projects/gravity/
**Testing Guide**: https://sao.bros.ninja/projects/gravity/testing/
**Project Plan**: https://sao.bros.ninja/projects/gravity/plan/
