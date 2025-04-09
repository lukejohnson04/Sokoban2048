
FRAME_TIME : float32 : 1.0 / 60.0;
last_frame_time : s64 = 0;
global_clock : s64 = 0;

sleep_till_next_update :: () {
    delay_time := last_frame_time + (FRAME_TIME * 1000) - SDL_GetTicks();
    if delay_time > 0 {
        SDL_Delay(cast(u32) delay_time);
    }
    global_clock = SDL_GetTicks();
    last_frame_time = global_clock;
}


Stack :: struct($T: Type, $MAX_SIZE: s64 = 50) {
    memory: [MAX_SIZE]T;
    count: s64;
}

stack_push :: (using stack: *Stack($T), value: T) {
    assert(count < stack.MAX_SIZE);
    memory[count] = value;
    count += 1;
}

stack_peek :: (using stack: *Stack($T)) -> T {
    assert(stack_is_empty(stack) == false);
    return memory[stack.count-1];
}

stack_pop :: (using stack: *Stack($T)) -> T {
    assert(stack_is_empty(stack) == false);
    count -= 1;
    return memory[count];
}

stack_is_empty  :: (using stack: *Stack($T)) -> bool {
    return count == 0;
}
