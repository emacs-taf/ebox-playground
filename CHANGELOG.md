# Changelog

## Unreleased

### Changed

- Desktop title bars use Ebox's shared `:drag` keymap callback. The companion
  owns only pane position and stacking; Ebox owns the native input loop.
  Leaving the original text window ends the gesture at its last position.
