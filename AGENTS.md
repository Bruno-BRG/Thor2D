# AGENTS.md — Thor2D contributor rules (humans + AI agents)

Thor2D is an Odin-native 2D game framework inspired by LÖVE (not Lua-compatible,
not a Lua compatibility layer). Game code imports only `thor2d`.

## 1. Architecture

```text
Game code (examples/*, user games)
    ↓  imports ONLY thor2d
thor2d public API — src/thor2d/*.odin, package thor2d
    ├── runtime/context.odin  Game{Load,Fixed_Update,Update,Draw,Shutdown,On_Event},
    │                         Run / Run_Headless, event queue, timer
    ├── graphics.odin, graphics_state.odin, transforms.odin, effects.odin
    ├── audio.odin, image.odin, input.odin (+*_extra.odin LOVE-parity gaps)
    ├── physics_box2d.odin (+physics_extra.odin), ecs.odin
    ├── filesystem.odin, data.odin, threads.odin, system.odin, window.odin
    ├── math.odin, random.odin, love_gaps.odin, video.odin, project.odin
    └── types.odin  ALL shared types, enums, Context, Config, Error
    ↓
Private adapters — src/thor2d/internal/{raylib,box2d,audio,video,filesystem}
    Raylib (window/input/graphics) · Box2D 3.x (physics) ·
    miniaudio (audio) · FFmpeg (optional video, capability-gated)
```

Key invariants:

- `ctx: ^Context` is always the first parameter of public procedures.
- Fallible procedures return `(T, Error)`; `Error` lives in `types.odin`.
- **Never return fake resource handles.** Unavailable hardware maps to
  `Error.Unsupported` or `Error.Capability_Unavailable`, and
  `Query_Capability(ctx, cap)` in `capabilities.odin` must reflect reality.
- Everything must be headless-safe: work headless, no-op, or return an
  explicit error under `Run_Headless` (no window, no GPU).
- Worker threads must never touch `Context`, Raylib, or the GPU.
- Pinned toolchain: Odin `dev-2026-09`
  (`$HOME/.local/opt/odin-dev-2026-09/odin`, or `$ODIN_BIN`), Linux AMD64
  primary. Collection flag: `-collection:thor2d=src`.

## 2. Wiki-first research (MANDATORY)

`docs/wiki/` is the source of truth for intended LOVE-parity semantics, ahead
of the code. Before changing ANY public behavior:

1. Read the relevant page under `docs/wiki/modules/` (index:
   `docs/wiki/Main_Page.md`), plus `docs/wiki/Api_Reference.md`.
2. Check the LOVE mapping in `docs/wiki/guides/Porting_From_LOVE.md`.
3. Then read the implementation source.

If wiki and code disagree, say so explicitly: fix the code (preferred), or fix
the wiki with a stated justification. Never silently follow one side.
For LOVE-side facts, consult the `love-api` mirror
(`github.com/love2d-community/love-api`, raw Lua files) — `love2d.org/wiki`
blocks plain fetches (403).

## 3. Wiki-update rule (MANDATORY, gated)

Every change touching the public API MUST update the wiki in the same change:

1. Update the affected module page(s) under `docs/wiki/modules/`
   (semantics, LOVE equivalent, diffs, example).
2. Regenerate the index: `python3 scripts/gen_wiki.py --gen`.
3. Extend the `Porting_From_LOVE.md` table if the change is LOVE-visible.
4. Update `docs/love2d-parity.md` if a module status or boundary changed.
5. New module? Add its page + row in `Main_Page.md` + guide if needed.

`./build.sh parity-check` runs `gen_wiki.py --check` and FAILS when any public
procedure is missing from the wiki. A change that breaks this gate is not done.

## 4. Code conventions (enforced in review)

- New LOVE-parity gap procedures go in `*_extra.odin` / `love_gaps.odin` /
  `window.odin`-style files; don't bloat the original v0.2–v0.7 files.
- `Color` channels are `u8` (0–255), never LOVE 0–1 floats.
- State lives on `Context` (see v0.8 graphics/input state fields), so headless
  runs stay deterministic.
- Examples import ONLY `thor2d` — `parity-check` greps for
  `vendor:raylib|vendor:box2d|vendor:miniaudio|foreign import` in `examples/`
  and fails on hits.
- Box2D 3.x removed pulley/rope/friction/gear joints: those kinds stay
  `.Unsupported` by design (documented in `Physics.md`).
- Pixel units are canonical; `Config.Pixels_Per_Meter` / `Set_Meter` exist only
  for LOVE formula ports.
- Fixed LE `Pack_*` is the intentional `love.data` subset (no Lua format strings).

## 5. Gates (run in order)

```sh
./build.sh check          # odin check + vet: framework and every example
./build.sh test           # odin test, single-threaded, headless-safe (27+ tests)
./build.sh parity-check   # check + test + manifest validation + wiki check + import scan
./build.sh love-port      # windowed smoke of examples/love_port_v08 (needs display :0)
./build.sh project-check examples/love_port_v08
```

Odin version notes: `os.make_directory_all` may fail when the target already
exists — always guard with `os.exists` (see `Init_Filesystem`). Test working
directory is the repo root. Display `:0` is available for windowed smokes with
`THOR2D_SMOKE=1` auto-quit.
