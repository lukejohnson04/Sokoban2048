Queue :: struct($T: Type, $MAX_SIZE: s64 = 50) {
    memory: [MAX_SIZE]T;
    count: s64;
    front: s64;
    back: s64;
}

queue_clear :: (queue: *Queue($T, $MAX_SIZE)) {
    queue.count = 0;
    queue.front = 0;
    queue.back = 0;
}

queue_add :: (using queue: *Queue($T, $MAX_SIZE), value: T) {
    assert(count < MAX_SIZE);
    memory[back] = value;
    count += 1;
    back = (back + 1) % MAX_SIZE;
}

queue_add :: (using queue: *Queue($T, $MAX_SIZE)) -> *T {
    assert(count < MAX_SIZE);
    addr := *memory[back];
    addr.* = .{};
    count += 1;
    back = (back + 1) % MAX_SIZE;
    return addr;
}

queue_remove :: (using queue: *Queue($T, $MAX_SIZE)) -> T {
    value := memory[front];
    count -= 1;
    front = (front + 1) % MAX_SIZE;
    return value;
}

queue_peek :: (using queue: *Queue($T, $MAX_SIZE)) -> T {
    return memory[front];
}

queue_get_front :: (using queue: *Queue($T, $MAX_SIZE)) -> *T {
    return *memory[front];
}

queue_is_empty :: (using queue: *Queue($T, $MAX_SIZE)) -> bool {
    return count == 0;
}
