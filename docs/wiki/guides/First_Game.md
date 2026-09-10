# Build a Small Game

This tutorial makes **Coin Run**, a tiny game with movement, collection, a
score and a quit action. It uses only the public `thor2d` package.

## 1. Prepare Thor2D

```sh
git clone https://github.com/Bruno-BRG/Thor2D.git
cd Thor2D
./build.sh deps
```

Thor2D currently targets Odin `dev-2026-09` on Linux AMD64.

## 2. Read the example

The complete example is in `examples/guide_game_v11/main.odin`. It imports no
backend package:

```odin
import thor2d "thor2d:thor2d"
```

`Update` changes player and score state; `Draw` only renders it.

## 3. Move and collect

```odin
if thor2d.Key_Down(ctx, .D) { player.X += speed * delta }
player.X = thor2d.Clamp(player.X, 24, 616)

if thor2d.Vec2_Length_Squared(thor2d.Vec2_Sub(player, coin)) < 28 * 28 {
    score += 1
}
```

`delta` is elapsed time in seconds, so movement remains consistent across
frame rates. The example accepts WASD and arrow keys and moves the coin with a
deterministic rule after each collection.

## 4. Run and package

```sh
./build.sh project-check examples/guide_game_v11
./build.sh guide-game
./build.sh pack examples/guide_game_v11
```

`guide-game` opens the playable window. Press `Esc` to close it. Packaging
creates `build/guide_game_v11.thor` with a manifest and file hashes.

## 5. Continue

- Add images with [Graphics](../modules/Graphics.md) and [Image](../modules/Image.md).
- Add simulation and collisions with [Physics](../modules/Physics.md).
- Run logic without a window using `./build.sh headless <project>`.
- Read [Packaging](Packaging.md) before distributing a `.thor` archive.
