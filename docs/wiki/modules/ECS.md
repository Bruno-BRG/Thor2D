# Entity-component storage

Source: `src/thor2d/ecs.odin`. These utilities do not take a `Context` and work
headlessly. A registry stores game-defined component types in dense arrays.
Entity IDs contain an index and a generation; reusing an index does not revive
an old entity ID. Physics bodies are separate handles.

## Registry and entity lifecycle

| Function | Contract |
| --- | --- |
| `New_Registry()` | Returns a registry with an allocated component-store map. The caller owns it. |
| `Destroy_Registry(^Registry)` | Frees all stores and registry arrays. Nil is a no-op. Do not reuse or destroy the same registry twice. |
| `Create_Entity(^Registry)` | Returns a live generational ID. Nil registry returns `Entity(0)`. |
| `Entity_Alive(^Registry, Entity)` | Checks the index, alive flag and generation. Nil, zero and stale IDs return false. |
| `Destroy_Entity(^Registry, Entity)` | Removes every component, marks the slot dead and increments its generation. Invalid IDs are ignored. |

## Components

| Function | Contract |
| --- | --- |
| `Add_Component(registry, entity, value)` | Infers the component type from `value`. Copies it into storage, replacing the existing value of that type. Returns a pointer or nil for a dead entity. |
| `Get_Component(registry, entity, T)` | Returns a borrowed pointer to component type `T`, or nil if absent/dead. |
| `Has_Component(registry, entity, T)` | True when `Get_Component` returns a pointer. |
| `Remove_Component(registry, entity, T)` | Removes the value using swap-with-last storage; absent values are ignored. |

Component pointers can be invalidated by array growth, removal or registry
destruction. Do not retain them across structural mutations. Components are
copied as Odin values: the registry does not run a destructor for memory owned
inside your component. Release that memory yourself before removal/destruction.

## Iteration

`Query(registry, T)` creates a single-component iterator. `Query_Next(&iterator)`
returns `(entity, value: ^T, ok: bool)`. At the end it returns `(0, nil, false)`.
An absent store is an empty query. Avoid adding/removing entities or components
while iterating: dense storage can move and invalidate both pointers and order.

`Transform_2D_Default()` returns a transform with unit scale `{1, 1}`; remaining
fields are zero-initialized.

## Example

```odin
registry := thor2d.New_Registry()
defer thor2d.Destroy_Registry(&registry)

entity := thor2d.Create_Entity(&registry)
thor2d.Add_Component(&registry, entity, thor2d.Vec2{10, 20})
iterator := thor2d.Query(&registry, thor2d.Vec2)
for {
    _, position, ok := thor2d.Query_Next(&iterator)
    if !ok { break }
    position.X += 1
}
thor2d.Destroy_Entity(&registry, entity)
assert(!thor2d.Entity_Alive(&registry, entity))
```
