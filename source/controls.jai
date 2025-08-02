
Action :: struct {
    keys: [2] SDL_Scancode;
    timer: float;
    pressed: bool;
    repetitions: int;
    do_action: bool;

    repeat_interval_initial := 0.5;
    repeat_interval := 0.4;
    repeat_interval_fast := 0.1;
    repeat_initial: bool;
    repeat_fast: bool;
}

Bindings :: struct {
    actions: [6] Action;

    using Action_Type :: enum s32 #specified {
        LEFT :: 0;
        RIGHT :: 1;
        UP :: 2;
        DOWN :: 3;
        UNDO :: 4;
        REDO :: 5;
    }

    repeat_fast_repitition_threshold :: 25;

    actions[LEFT].keys[0] =   SDL_SCANCODE_LEFT;
    actions[LEFT].keys[1] =   SDL_SCANCODE_A;
    actions[RIGHT].keys[0] =  SDL_SCANCODE_RIGHT;
    actions[RIGHT].keys[1] =  SDL_SCANCODE_D;
    actions[UP].keys[0] =     SDL_SCANCODE_UP;
    actions[UP].keys[1] =     SDL_SCANCODE_W;
    actions[DOWN].keys[0] =   SDL_SCANCODE_DOWN;
    actions[DOWN].keys[1] =   SDL_SCANCODE_S;

    actions[LEFT].repeat_initial =  false; 
    actions[RIGHT].repeat_initial = false;
    actions[UP].repeat_initial =    false;
    actions[DOWN].repeat_initial =  false;

    actions[UNDO].keys[0] =   SDL_SCANCODE_R;
    actions[REDO].keys[0] =   SDL_SCANCODE_Z;
    actions[UNDO].repeat_fast = true;
    actions[REDO].repeat_fast = true;
}

do_action :: (action: Bindings.Action_Type) -> bool {
    res := context.game_state.bindings.actions[action].do_action;
    if res {
        context.game_state.bindings.actions[action].do_action = false;
        context.game_state.bindings.actions[action].repetitions += 1;
    }
    return res;
}

controls :: (input: *Input_State) {
    using context.game_state.bindings;
    for *action: actions {
        action.do_action = false;

        just_pressed := false;
        keys_pressed := 0;
        for key: action.keys {
            if input.is_pressed[key] {
                keys_pressed += 1;
            }
        }
        if keys_pressed == 0 && action.pressed {
            action.pressed = false;
            action.timer = 0;
            action.repetitions = 0;
            continue;
        } else if keys_pressed && action.pressed == false {
            action.pressed = true;
            action.timer = ifx action.repeat_initial {
                action.repeat_interval_initial;
            } else {
                action.repeat_interval;
            }
            just_pressed = true;
        }

        if action.pressed {
            if just_pressed || action.timer <= 0 {
                action.do_action = true;
                if action.timer <= 0 {
                    if action.repeat_fast && action.repetitions > repeat_fast_repitition_threshold {
                        action.timer = action.repeat_interval_fast;
                    } else {
                        action.timer = action.repeat_interval;
                    }
                }
            }
            action.timer -= FRAME_TIME;
        }
    }
}
