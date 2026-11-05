# Tests
A small fake of the WoW API (`harness.py`) loads the addon in the TOC's order and runs scenario
scripts against it: timing, kiting/retry rhythm, jitter smoothing, replayed in-game logs,
ammo counter, options menu validation, presets, slash commands and more.

    pip install lupa
    tests/run_tests.sh

Each `scenarioN.lua` prints `OK<N>` at the end when it ran through. They're simulations: the real
client is the final word.
