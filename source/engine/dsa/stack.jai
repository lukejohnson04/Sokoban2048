Stack :: struct($T: Type, $MAX_SIZE: s64 = 50) {
    memory: [MAX_SIZE]T;
    count: s64;
}

stack_push :: (using stack: *Stack($T, $MAX_SIZE), value: T) -> *T {
    assert(count < stack.MAX_SIZE);
    memory[count] = value;
    count += 1;
    return *memory[count];
}

stack_peek :: (using stack: *Stack($T, $MAX_SIZE)) -> T {
    assert(stack_is_empty(stack) == false);
    return memory[stack.count-1];
}

stack_pop :: (using stack: *Stack($T, $MAX_SIZE)) -> T {
    assert(stack_is_empty(stack) == false);
    count -= 1;
    return memory[count];
}

stack_is_empty  :: (using stack: *Stack($T, $MAX_SIZE)) -> bool {
    return count == 0;
}

stack_clear :: (using stack: *Stack($T, $MAX_SIZE)) {
    stack.count = 0;
}

Stack_Circular :: struct($T: Type, $MAX_SIZE: s64 = 50) {
    memory: [MAX_SIZE]T;
    top: s64;
    count: s64;
}

stack_push :: (using stack: *Stack_Circular($T, $MAX_SIZE), value: T) {
    if top == MAX_SIZE - 1{
        top = 0;
    } else {
        top += 1;
    }
    count += 1;
    if count > MAX_SIZE {
        count = MAX_SIZE;
    }
    memory[top] = value;
}

stack_peek :: (using stack: *Stack_Circular($T, $MAX_SIZE)) -> T {
    assert(stack_is_empty(stack) == false);
    return memory[top];
}

stack_pop :: (using stack: *Stack_Circular($T, $MAX_SIZE)) -> T {
    assert(stack_is_empty(stack) == false);
    value := memory[top];
    if top == 0 {
        top = MAX_SIZE - 1;
    } else {
        top -= 1;
    }
    count -= 1;
    return value;
}

stack_is_empty  :: (using stack: *Stack_Circular($T, $MAX_SIZE)) -> bool {
    return top == -1 || count == 0;
}

stack_clear :: (using stack: *Stack_Circular($T, $MAX_SIZE)) {
    stack.top = 0;
    stack.count = 0;
}
