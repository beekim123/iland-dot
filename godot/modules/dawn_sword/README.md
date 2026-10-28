# 晨曦之剑：龙塔救援 — implementation in progress

Independent pure-2D Godot 4.7.2 module. Entry `main.tscn`; protocol `start(context={})`, `exit_requested`. No host/other-module resources or singleton dependencies. Standalone auto-start opens the title screen; normal exit retires local audio and closes the process. Hosted exit only emits once.

## Controls
A/D or arrows / stick or D-pad: movement. Space / bottom face: variable jump. J / left face: three-hit sword combo. K / right face: roll. L / left shoulder: shield. U / top face: Dawn slash after chapter 4 shrine. H / Back: healing. E / right shoulder: interaction. W: climb, S+jump: drop ledges. Esc / Menu: pause. Keyboard bindings, volume, fullscreen, flash, subtitles and difficulty in Settings. No shared InputMap modifications.

## Structure
- `data/campaign.gd`: 5 chapters × 4 sections, explicit route layouts, 9 normal enemy archetypes, 4 regional bosses + dragon.
- `scripts/rules.gd`: deterministic RefCounted fixed-step simulation, buffered jump/coyote, attack/guard/roll/heal, enemy tells/recovery, projectiles, pits, moving/crumbling platforms, ladders, shrine/seal/cooperative gates, epilogue and ending.
- `scripts/game.gd`: input queue, renderer, real PNG atlas frame selection, UI, audio adapter, menu lifecycle.
- `scripts/storage.gd`: versioned isolated `user://games/dawn_sword/v1/profile.json`, atomic same-dir replacement. Corrupt/future/foreign saves are retained and writing refused.
- `art/manifest.json`: source/animation/pending status is authoritative; missing actors are conspicuous labelled greybox ONLY.
- `audio/`: module-local original synthesized music/cues and director.

## Verification
Run tests with a fresh external `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`:
```
Godot_v4.7.2-stable_linux.x86_64 --headless --path godot --script res://modules/dawn_sword/tests/test_rules.gd
# test_campaign_route.gd: actual abstract input-only end-to-end. No actor teleport,
# HP/boss edits, progress/phase forcing, or debug completion shortcuts.
# optional user argument -- --normal selects adventure difficulty.
# test_state_regressions.gd: deliberately local fixtures, NOT completion evidence.
# test_storage.gd requires XDG_DATA_HOME containing dawn-storage-test, prevents
# accidentally running destructive fixtures against a real player profile.
```
`test_runtime.gd` verifies hosted pause/settings/substep input/exit. `test_standalone_exit.gd` checks automatic standalone start and genuine process closure (no --quit-after).

## Honest delivery status / open work
This is an integrated development build, **not final art/content acceptance**. The full 20-section story state machine is playable through rescue, dragon's three health phases, an interactive walk-out and ending. An input-only expert bot traversed the prior layout in ~8m15s: this is neither a first-player duration nor evidence of the 60–90 minute design target. That target is presently **not reached/validated**; substantial authored encounter/puzzle/content depth and playtesting remain, not extra enemy HP padding.

Art is AI-assisted original raster illustration, not a claim of human-drawn production. Only assets flagged accepted after motion/runtime review should count as finished. Missing enemy animations/props remain visible greyboxes, and incomplete animations fall back to idle; these must not be presented as final screenshots. Check manifest pending entries. Five backgrounds and hero/princess/bandit/dragon trial atlases exist as of this checkpoint. Platform terrain skin, full animation sets, richer regional encounter patterns, climb/ledge behavior polish, dragon presentation, hand-controller physical testing, subjective listening, target performance, and full first-player timing remain acceptance work.

No claims of 60–90 minute completion, graphical completion, subjective audio approval, or shipped build should be inferred from headless tests. Root controls registry/hub activation and commits.
