# Config File Overrides

This directory contains machine-specific config file overrides that replace entire files from `configs/`.

When syncing, gravity.nvim checks this directory first:

1. If `configs.overrides/.gitconfig` exists → use it
2. If not → fall back to `configs/.gitconfig`

## Example

```bash
cp configs/.gitconfig configs.overrides/.gitconfig
# Edit configs.overrides/.gitconfig with machine-specific values
```

Next sync will use your override instead of the base file.

## Full Documentation

**https://sao.bros.ninja/projects/gravity/**

**Note**: This directory is gitignored - changes here stay local to this machine.
