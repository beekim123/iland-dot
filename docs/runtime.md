# 当前运行入口（2026-10-28）

当前为八款模块化游戏及海岛大厅。用 Godot 4.7.2 打开 `godot/project.godot`；玩法、四门随机推荐和分页目录以根 README 为准。海岛运行成品由 `docs/active_asset_manifest.json` 显式列出，统一保留在 Godot 目录；作者目录中的重复导出可缺省。同步/哈希校验见 `docs/project/ASSET_POLICY.md`，不扫描旧导出目录覆盖当前资源。

以下 v2/v4 内容全部是历史记录，不是当前操作/资产清单；其中旧截图、试听和模型路径可从整理前提交 `7b16265` 恢复。保留历史测试结论不代表本次重新进行图形/声音验收。

---

# Current runtime: approved art + actual skeletal animation v4
User-approved v3 environment and true-armature animals are now integrated. Current implementation, rollback, exact asset manifest, clip timing, terrain COLOR_0 conversion and capture steps are documented in [revisions/godot-approved-rigged-v4.md](revisions/godot-approved-rigged-v4.md). The following v2 notes are retained as historical evidence and are **not the active mesh-pivot animation implementation**.

Current controls also include3for swimmer close view and4for flight close view. `--shots` writes five `v4_*.png` actual viewport images; `--gif` uses `gif_frames_v4/` and the encoders produce new `motion_v4.gif/mp4` files. Original music/ocean loops remain unchanged.

---

# Living island v2 — current runtime
Godot **4.7.2** Compatibility renderer. Independent chibi-island project.

## V2 motion and integration
`island.gd` creates the imported environment and three imported animals, then drives three independent modules from one elapsed-time clock:
- `wildlife_motion.gd`: real gull flight path at about7.7–8.4m height, bank and shoulder-wing flaps; turtle swimming route in foreground water with shoulder flippers; side-scuttling crab with alternating leg gait. Original model roots retained.
- `fish_school.gd`: sixteen authored Blender fish in two coordinated schools, with curved routes, tangent heading, body buoyancy, articulated tails and fins.
- `living_water.gd` and `shaders/living_ocean.gdshader`: rolling transparent wave surface, traveling foam, underwater caustics and a deeper seabed. The old static GLB sea/apron/foam meshes are hidden. Procedural tessellated water surfaces are deliberate new water effects, not substitutes for authored terrain/wildlife.

The old small root wiggles are no longer executed. Modules have no independent time source; one clock drives both normal playback and fixed-step capture, including water shader uniforms. Space pauses all motion together. Camera reset now uses34m distance and target(0,2.2,3.5) to include airborne gull and foreground sea; shore view uses27m and target(0,1.7,6).

## V2 verification and capture
Current headless checks cover scene initialization, imported model bounds, original audio loops, camera/mute controls, actual turtle/crab/gull displacement over four seconds, gull altitude, sixteen fish with underwater positions and displacement, wing/flipper joints, and deterministic water shader time. Results: `docs/runtime_checks.json`; latest run passes. Shader appearance and underwater transparency require actual graphical inspection; headless checks are not visual QA.

`tools/run.sh --shots` captures overview, shore and clean overview from a graphical window.
`tools/run.sh --gif` captures120 actual viewport frames at12fps /10seconds to `art/previews/runtime/gif_frames_v2_final/`. Camera travels smoothly from overview to the foreground sea and back. `tools/encode_gif.sh` writes a 640×400 /10fps normal-speed `sunny_shell_island_motion_v2.gif`, preserving the already-delivered v1 GIF. Capture is fixed-step regardless of software-render speed and does not interpolate still images. GIF is silent. `tools/encode_video.sh` also creates a 960×600 /12fps H.264 MP4 from exactly the same120frames, with existing original music/ocean mixed at the runtime gains and short edge fades. It does not synthesize new imagery or audio. Normal runtime resumes afterward.

Final motion refinement: gull uses32°forward-flight posture with tucked original feet/legs; fish follow two leaders in loose staggered tangent-space cohorts, with small asynchronous adjustments, rather than evenly spaced circular rings. Cohort spacing and60-second movement were separately tested by the fish worker.

The following is retained as **v1 production/QA history**, not a claim that its static-water implementation is still active.

---

# 晴贝小岛 / Sunny Shell — Godot runtime
Independent authored 3D island scene, Godot **4.7.2 stable**. No Valley Deck reuse.

## Reproduce
From the project root:
- `python3 tools/sync_resources.py` — copy finished `art/export/*.glb` and `audio/export/*_loop.wav` into Godot, hash manifest in `docs/resource_manifest.json`. Audition mix is deliberately not copied/played.
- `tools/run.sh --import` — headless editor import.
- `tools/run.sh --test` — headless initialization/control/resource checks; writes `docs/runtime_checks.json`.
- `tools/run.sh` — graphical runtime.
- `tools/run.sh --shots` — **graphical instance only**; captures the actual viewport, then remains open. Uses no offline Blender render.
  - `art/previews/runtime/01_island_overview.png`
  - `art/previews/runtime/02_beach_friends.png`
  - `art/previews/runtime/03_island_clean.png`

Launcher pins the installed 4.7.2 executable in sibling `../tools/godot-4.7.2/`. Override `GODOT_BIN` when moving to another machine. It stores user/cache data under project `.runtime/` rather than restricted home directories. Headless checks are not visual or listening verification. Use the cloud desktop terminal for graphical launch; do not infer access from shell DISPLAY.

## Interaction
Drag left mouse to orbit, scroll to zoom; R resets, 2 focuses beach friends, M mutes all audio, Space pauses gentle animation, H hides HUD. Buttons duplicate camera/mute controls. Volume slider controls music and ocean together. Mouse UI consumes input before orbit.

## Assets and placement
All landscape and animals are authored GLBs. No runtime mesh stand-ins. Environment comprises 16 material-group meshes; shared static terrain/plants. Palms intentionally remain static because material-group merging does not preserve independent branch pivots. Only shallow-water/foam geometry moves vertically ±0.014m. Flippers, wings, claws animate at local mesh centers; crab drifts ±0.1m, otherwise animals remain on authored beach positions.

Blender coordinates (x,y,z), local uniform scale, Blender Z yaw:
- turtle (-2.2,-4.8,.70), 1.55, -0.40rad
- crab (2,-6.1,.68), 1.75, +0.15rad
- seagull (5.5,-3.7,.64), 1.65, -0.65rad

Mapping: Godot(x,z,-y). Ground raycasts reported .668614/.649625/.604097; small positive clearance avoids base clipping. Height includes foot origin 0. Parent graphical review confirmed all three animals visible in the beach view.

## Rendering and sound
Compatibility renderer, 2×MSAA, one shadow sun and inexpensive fill, ambient color, linear tonemapping. No SSAO, SSR, glow, GI or postprocess fog. 42° perspective orbit, clamp9–49m, target near island center. Final lighting after actual screenshot correction: sun energy 0.35, ambient 0.22, fill 0.06. The original brighter settings visibly overexposed sand/leaves and were rejected. The authored 100m sea mesh is scaled 4× in X/Z at runtime (no replacement mesh), with an unshaded #4b9eaa material matching the clear background; parent graphical review confirmed no visible polygon boundary in the overview.

Original PCM16 stereo44100Hz audio loops are48s/2,116,800frames. Music gain−3dB, ocean−12dB, master65%; exact full-length looping. The separate15s audition file is not part of runtime. Mute/volume exposed in UI. Playback resource and loop settings validated, but hearing requires actual audio access.

## Verification
`docs/runtime_checks.json` records engine version, imported AABBs and mesh counts, failures array. Tests cover scene init, required four models, nondegenerate reasonable bounds, eight flipper/wing/claw animation nodes, two48s loop resources, camera drag/zoom/clamps/reset, and mute/unmute. Latest run: zero failures. Headless checks remain distinct from visual or listening verification.

### Actual graphical QA — 2026-10-26
The parent agent launched the real Godot 4.7.2 application on the cloud desktop through CUA and inspected the refreshed viewport captures after the lighting correction. Reported PASS: corrected pastel colors, no far-ocean polygon edge in the overview, all three animals visible in beach view. Actual interaction checks: key 2 changes to beach view; H toggles HUD; M changes Sound/Mute state; drag and scroll visibly alter the camera. The three PNGs listed above were captured by the running graphical app, not Blender or headless rendering, and were sent to the user.

### Limitations
- No subjective listening verification is claimed; audio resource/loop/playback initialization and mute-state checks are available.
- Cloud desktop QA does not establish performance on every user device.
- Palm geometry is intentionally static because it is merged by material; no unsupported individual leaf bending is fabricated.
- This is a small interactive scene viewer, not a navigation/collision/gameplay system.
- The cloud convenience launcher has a local executable path; portable use is to open godot/project.godot in Godot 4.7.2.

## Actual moving GIF — 2026-10-26
User requested a view of the island in motion. Run `tools/run.sh --gif` on the graphical cloud desktop, then `tools/encode_gif.sh` after `art/previews/runtime/gif_frames/capture.json` appears. Capture uses the same live Godot scene and original motion functions with deterministic 1/12-second simulation steps, 72 actual viewport frames. A gentle ±0.07rad camera orbit helps show depth; no animal movement is exaggerated. It restores normal runtime after capture. Headless capture is rejected.

Output: `art/previews/runtime/sunny_shell_island_motion.gif`, 720×450, 72 unique frames, exactly6.000seconds, infinite loop, 3,961,052bytes. GIF has **no audio**. Parent launched the actual graphical capture through CUA. Source frame0 and a four-timepoint contact sheet were visually inspected; all three animals remain readable and pastel colors are retained. Adjacent image deltas verify frame variation. The natural actor animation does not exactly repeat over six seconds, so a small motion reset remains at the loop boundary; camera orbit loops smoothly. `gif_qa.json` records measured timing and frame variation. This is actual rendered scene movement, not an AI-generated animation or interpolated still.

## V2 final graphical and export verification
Final source frames: `art/previews/runtime/gif_frames_v2_final/` (120 PNGs,10seconds at12fps). Parent CUA checked real runtime water/fish/flight, and final frame020; integration inspected frames040/060 and four-timepoint contact sheet. All19wildlife/fish objects stayed within the camera over the120frame capture, verified from mesh-bounds projections by `tests/check_capture.gd`; minimum edge margin2.47px at1280×800. `docs/capture_bounds_checks.json` retains that result. This tests framing, not occlusion or contact realism.

Final GIF:640×400/10fps/100unique frames/exact10s,9,717,595bytes, silent infinite-loop preview. Final MP4:960×600/12fps/120frames/exact10s,1,562,601bytes,H.264 withAAC44100Hzstereo. Audio stream detected and decoded; measured mean−26.8dB/peak−11.6dB. This is not subjective listening. Both encode the same real final scene at normal simulation speed; theGIF drops source frames to10fps rather than slowing playback. Animal routes need not close at10seconds, so the clip visibly restarts at the loop boundary.

Intermediate `gif_frames_v2/` contained the superseded evenly spaced fish rings; do not use those frames for final delivery. Existing v1 GIF remains unchanged.
