# Changelog

## Unreleased

### Added

- Restored the standalone `desktop-reference.ebox` gesture sample. It remains
  an Ebox-only layout and interaction fixture; application-level desktop
  management belongs to the independent `etaf-desktop` package.

### Changed

- The example companions update retained nodes through `ebox-selector-query-buffer`,
  `ebox-node-set-props` and `ebox-with-batch`, replacing the removed region
  update API.
- Example interaction timing moved to `benchmarks/performance-scenarios.el`
  for the workspace performance tool (`make perf-check`).

### Removed

- The flex-resize, scroll and interaction evaluator and `make performance`;
  they measured the removed publication pipeline.
