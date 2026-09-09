package thor2d

Sparse_Store :: struct($T: typeid) {
	sparse: [dynamic]int,
	dense_entities: [dynamic]Entity,
	dense_values: [dynamic]T,
}

Store_Entry :: struct {
	data: rawptr,
	remove: proc(rawptr, Entity),
	destroy: proc(rawptr),
}

Registry :: struct {
	generations: [dynamic]u32,
	alive: [dynamic]bool,
	free_indices: [dynamic]u32,
	stores: map[typeid]Store_Entry,
}

Query_Iterator :: struct($T: typeid) {
	store: ^Sparse_Store(T),
	index: int,
}

New_Registry :: proc() -> Registry {
	return Registry{stores = make(map[typeid]Store_Entry)}
}

Destroy_Registry :: proc(registry: ^Registry) {
	if registry == nil {
		return
	}
	for _, entry in registry.stores {
		if entry.destroy != nil {
			entry.destroy(entry.data)
		}
	}
	delete(registry.stores)
	delete(registry.generations)
	delete(registry.alive)
	delete(registry.free_indices)
}

make_entity :: proc(index: u32, generation: u32) -> Entity {
	return Entity((u64(generation) << 32) | u64(index))
}

entity_index :: proc(entity: Entity) -> u32 {
	return u32(u64(entity) & 0xffffffff)
}

entity_generation :: proc(entity: Entity) -> u32 {
	return u32(u64(entity) >> 32)
}

Create_Entity :: proc(registry: ^Registry) -> Entity {
	if registry == nil {
		return Entity(0)
	}
	if len(registry.free_indices) > 0 {
		index := pop(&registry.free_indices)
		registry.alive[index] = true
		return make_entity(index, registry.generations[index])
	}
	index := u32(len(registry.generations))
	append(&registry.generations, 1)
	append(&registry.alive, true)
	return make_entity(index, 1)
}

Entity_Alive :: proc(registry: ^Registry, entity: Entity) -> bool {
	if registry == nil || entity == Entity(0) {
		return false
	}
	index := entity_index(entity)
	return int(index) < len(registry.alive) && registry.alive[index] && registry.generations[index] == entity_generation(entity)
}

destroy_store_entity :: proc($T: typeid, raw: rawptr, entity: Entity) {
	store := cast(^Sparse_Store(T))raw
	index := entity_index(entity)
	if int(index) >= len(store.sparse) {
		return
	}
	dense_index := store.sparse[index]
	if dense_index < 0 || dense_index >= len(store.dense_entities) || store.dense_entities[dense_index] != entity {
		return
	}
	last := len(store.dense_entities)-1
	if dense_index != last {
		moved := store.dense_entities[last]
		store.dense_entities[dense_index] = moved
		store.dense_values[dense_index] = store.dense_values[last]
		store.sparse[entity_index(moved)] = dense_index
	}
	pop(&store.dense_entities)
	pop(&store.dense_values)
	store.sparse[index] = -1
}

destroy_store :: proc($T: typeid, raw: rawptr) {
	store := cast(^Sparse_Store(T))raw
	delete(store.sparse)
	delete(store.dense_entities)
	delete(store.dense_values)
	free(store)
}

get_store :: proc(registry: ^Registry, $T: typeid, create: bool) -> ^Sparse_Store(T) {
	if registry == nil {
		return nil
	}
	id := typeid_of(T)
	if entry, ok := registry.stores[id]; ok {
		return cast(^Sparse_Store(T))entry.data
	}
	if !create {
		return nil
	}
	store := new(Sparse_Store(T))
	registry.stores[id] = Store_Entry{
		data = rawptr(store),
		remove = proc(raw: rawptr, entity: Entity) { destroy_store_entity(T, raw, entity) },
		destroy = proc(raw: rawptr) { destroy_store(T, raw) },
	}
	return store
}

ensure_sparse :: proc(store: ^Sparse_Store($T), index: u32) {
	for len(store.sparse) <= int(index) {
		append(&store.sparse, -1)
	}
}

Add_Component :: proc(registry: ^Registry, entity: Entity, value: $T) -> ^T {
	if !Entity_Alive(registry, entity) {
		return nil
	}
	store := get_store(registry, T, true)
	index := entity_index(entity)
	ensure_sparse(store, index)
	if dense_index := store.sparse[index]; dense_index >= 0 {
		store.dense_values[dense_index] = value
		return &store.dense_values[dense_index]
	}
	dense_index := len(store.dense_entities)
	append(&store.dense_entities, entity)
	append(&store.dense_values, value)
	store.sparse[index] = dense_index
	return &store.dense_values[dense_index]
}

Get_Component :: proc(registry: ^Registry, entity: Entity, $T: typeid) -> ^T {
	if !Entity_Alive(registry, entity) {
		return nil
	}
	store := get_store(registry, T, false)
	if store == nil {
		return nil
	}
	index := entity_index(entity)
	if int(index) >= len(store.sparse) {
		return nil
	}
	dense_index := store.sparse[index]
	if dense_index < 0 {
		return nil
	}
	return &store.dense_values[dense_index]
}

Has_Component :: proc(registry: ^Registry, entity: Entity, $T: typeid) -> bool {
	return Get_Component(registry, entity, T) != nil
}

Remove_Component :: proc(registry: ^Registry, entity: Entity, $T: typeid) {
	if registry == nil {
		return
	}
	if entry, ok := registry.stores[typeid_of(T)]; ok {
		entry.remove(entry.data, entity)
	}
}

Destroy_Entity :: proc(registry: ^Registry, entity: Entity) {
	if !Entity_Alive(registry, entity) {
		return
	}
	index := entity_index(entity)
	for _, entry in registry.stores {
		if entry.remove != nil {
			entry.remove(entry.data, entity)
		}
	}
	registry.alive[index] = false
	registry.generations[index] += 1
	if registry.generations[index] == 0 {
		registry.generations[index] = 1
	}
	append(&registry.free_indices, index)
}

Query :: proc(registry: ^Registry, $T: typeid) -> Query_Iterator(T) {
	return Query_Iterator(T){store = get_store(registry, T, false)}
}

Query_Next :: proc(iterator: ^Query_Iterator($T)) -> (entity: Entity, value: ^T, ok: bool) {
	if iterator == nil || iterator.store == nil || iterator.index >= len(iterator.store.dense_entities) {
		return Entity(0), nil, false
	}
	entity = iterator.store.dense_entities[iterator.index]
	value = &iterator.store.dense_values[iterator.index]
	iterator.index += 1
	return entity, value, true
}

Transform_2D_Default :: proc() -> Transform_2D {
	return Transform_2D{Scale = Vec2{1, 1}}
}
