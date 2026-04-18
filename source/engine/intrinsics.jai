
Array :: struct($T: Type, $MAX_COUNT := 256) {
    data: [MAX_COUNT] T;
    count := 0;
}

get :: (array: *Array($T, $MAX_COUNT), index: int) -> *T {
    if index < 0 {
        return null;
    }
    return *array.data[index];
}

remove_from_array :: (array: *Array, index: s64) {
    if index != array.count - 1 {
        array.data[index] = array.data[array.count-1];
    }
    array.count -= 1;
}

add_to_array :: (array: *Array) -> *array.T {
    res := *array.data[array.count];
    array.count += 1;
    
    res.* = .{};
    return res;
}


add_to_array :: (array: *Array, a: array.T) -> *array.T {
    res := *array.data[array.count];
    array.count += 1;

    res.* = a;
    return res;
}

add_to_array :: (array: *Array, to_append: ..array.T) {
    for elem: to_append {
        add_to_array(array, elem);
    }
}

is_in_array :: (array: *Array, a: array.T) -> *array.T {
    for 0..array.count-1 {
        addr := get(array, it);
        if addr.* == a {
            return addr;
        }
    }
    return null;
}

is_in_array :: (array: *Array, a: array.T, comp: (array.T, array.T) -> bool) -> *array.T {
    for 0..array.count-1 {
        addr := get(array, it);
        if comp(addr.*, a) {
            return addr;
        }
    }
    return null;
}

#load "dsa/queue.jai";
#load "dsa/stack.jai";
