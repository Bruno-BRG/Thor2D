# Thor2D Wiki

Thor2D is an Odin-native 2D game framework inspired by [LÖVE](https://love2d.org/).
This wiki mirrors the structure of `love2d.org/wiki` so LOVE developers can
find every module in the expected place. Each page lists the Thor2D Odin API,
the LOVE equivalent, and the intentional differences.

Game code imports only `thor2d`:

```odin
package game

import thor2d "thor2d"

draw :: proc(ctx: ^thor2d.Context) {
    thor2d.Clear_Screen(ctx)
    thor2d.Draw_Circle(ctx, thor2d.Vec2{100, 100}, 32, thor2d.Get_Color(ctx))
}

main :: proc() {
    thor2d.Run(thor2d.Default_Config(), thor2d.Game{Draw = draw})
}
```

## Modules (LOVE order)

| Wiki page | LOVE equivalent | Thor2D source |
| --- | --- | --- |
| [thor2d](thor2d.md) | `love` callbacks | `context.odin`, `types.odin` |
| [modules/Audio](modules/Audio.md) | `love.audio` | `audio.odin`, `love_gaps.odin` |
| [modules/Data](modules/Data.md) | `love.data` | `data.odin`, `love_gaps.odin` |
| [modules/Event](modules/Event.md) | `love.event` | `context.odin` |
| [modules/Filesystem](modules/Filesystem.md) | `love.filesystem` | `filesystem.odin`, `filesystem_extra.odin` |
| [modules/Font](modules/Font.md) | `love.font` | `graphics.odin`, `graphics_state.odin` |
| [modules/Graphics](modules/Graphics.md) | `love.graphics` | `graphics.odin`, `graphics_state.odin` |
| [modules/Image](modules/Image.md) | `love.image` | `image.odin` |
| [modules/Joystick](modules/Joystick.md) | `love.joystick` | `input.odin`, `input_extra.odin` |
| [modules/Keyboard](modules/Keyboard.md) | `love.keyboard` | `input.odin`, `input_extra.odin` |
| [modules/Math](modules/Math.md) | `love.math` | `math.odin`, `random.odin`, `love_gaps.odin` |
| [modules/Mouse](modules/Mouse.md) | `love.mouse` | `input.odin`, `input_extra.odin`, `system.odin` |
| [modules/Physics](modules/Physics.md) | `love.physics` | `physics_box2d.odin`, `physics_extra.odin` |
| [modules/Sound](modules/Sound.md) | `love.sound` | `audio.odin` |
| [modules/System](modules/System.md) | `love.system` | `system.odin`, `window.odin` |
| [modules/Thread](modules/Thread.md) | `love.thread` | `threads.odin` |
| [modules/Timer](modules/Timer.md) | `love.timer` | `context.odin`, `system.odin` |
| [modules/Touch](modules/Touch.md) | `love.touch` | `input.odin`, `input_extra.odin` |
| [modules/Video](modules/Video.md) | `love.video` | `video.odin` |
| [modules/Window](modules/Window.md) | `love.window` | `context.odin`, `system.odin`, `window.odin` |
| [modules/Net](modules/Net.md) | third-party `enet` / `socket` (LOVE has no built-in net) | `net.odin` |
| [modules/ECS](modules/ECS.md) | game-side entity/component storage | `ecs.odin` |
| [modules/Project](modules/Project.md) | project and scene manifests | `project.odin` |
| [modules/Transforms](modules/Transforms.md) | 2D transforms | `transforms.odin` |

## Guides

- [First_Game](guides/First_Game.md) — build a small playable Coin Run game step by step.
- [Getting_Started](guides/Getting_Started.md) — install, run, pack.
- [Porting_From_LOVE](guides/Porting_From_LOVE.md) — side-by-side LOVE → Thor2D table.
- [Capabilities](guides/Capabilities.md) — `Query_Capability` rules, headless, `.thor` packages.
- [Packaging](guides/Packaging.md) — manifests, hashes, mount order.
- [Editor](guides/Editor.md) — v0.9 CLI project inspector scaffolding.
- [Mobile](guides/Mobile.md) — v0.9 mobile-future stubs (vibrate, orientation).
- [Api_Reference](Api_Reference.md) — auto-generated index of every public procedure.
- [Complete_API](Complete_API.md) — one signature entry for every public procedure.
- [Documentation_Status](Documentation_Status.md) — curated coverage audit and honest backlog.

## Conventions used on every page

- `ctx: ^Context` is always the first argument (LOVE uses globals).
- `Color` channels are `u8` (0–255), not LOVE 0–1 floats.
- Functions that can fail return `(T, Error)`; hardware gaps return
  `.Unsupported` or `.Capability_Unavailable` — never a fake handle.
- `Headless` contexts run the same lifecycle without a window or GPU.
