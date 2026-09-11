# thor2d.ECS

Thor2D includes a small generational entity-component store. ECS is separate
from the physics world: entities are identifiers, while gameplay data remains
in components owned by the game.

## Status

The ECS API is implemented in `src/thor2d/ecs.odin`. Its public procedures are
listed in [Api_Reference](../Api_Reference.md), but this page is still being
expanded with component-storage examples and lifecycle guidance. Do not treat
an entity ID as a physics body; keep an explicit mapping when both systems are
used.

## Related

- [Physics](Physics.md) — fixed-step bodies and collision callbacks.
- [Core Concepts](../guides/Core_Concepts.md) — context and handles.
