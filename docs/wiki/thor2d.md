# thor2d (runtime)

LOVE equivalent: `love` callbacks + `love.run`. Source: `context.odin`, `types.odin`.

`Game{Load, Fixed_Update, Update, Draw, Shutdown, On_Event}` run by `Run(config, game)` or headless `Run_Headless(config, game, max_frames)`. `Create/Destroy`, `Begin_Frame/End_Frame`, `Delta_Time/Elapsed_Time`, `Set_Target_FPS`, `Window_Size/Set_Window_Title/Set_Window_Size/Toggle_Fullscreen`, `Is_Running/Quit`.

v0.9 runtime gaps: `Game.On_Error(ctx, err)` (mirrors `love.errorhandler`)
is invoked by `Run`/`Run_Headless` when `Create` fails — `ctx` is nil there
because no `Context` was created, so handlers must accept nil. `Game.On_Low_Memory(ctx)`
(mirrors `love.lowmemory`) is never invoked on desktop (no OS signal;
reserved as mobile-future). Version: `THOR2D_VERSION_MAJOR/MINOR/PATCH`
(`0/11/0`), `Thor2D_Version()`, `Is_Version_Compatible(major, minor)`
(mirrors `love.getVersion` / `love.isVersionCompatible`).

See [Api_Reference](Api_Reference.md) and [Porting_From_LOVE](guides/Porting_From_LOVE.md).
