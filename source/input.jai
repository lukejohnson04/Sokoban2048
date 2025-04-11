Input_State :: struct {
    is_pressed : [256] bool;
    just_pressed : [256] bool;
    just_released : [256] bool;

    mouse_just_pressed : bool;
    mouse_just_released: bool;
    mouse_pressed : bool;

    rmouse_just_pressed : bool;
    rmouse_just_released: bool;
    rmouse_pressed : bool;

    mouse_motion : v2i;

    window_closed : bool;

    sdl_joystick: *SDL_Joystick;
    joystick: Joystick_State;
}

Joystick_State :: struct {
    deadzone := 8000;
    left_stick: Vector2;
    right_stick: Vector2;
}


poll_input :: (using input: *Input_State) {
    memset(*input.just_pressed, 0, size_of(bool) * 256);
    memset(*input.just_released, 0, size_of(bool) * 256);
    input.mouse_just_pressed = false;
    input.mouse_just_released = false;
    input.rmouse_just_pressed = false;
    input.rmouse_just_released = false;
    input.mouse_motion = .{0, 0};
    input.window_closed = false;

    if SDL_NumJoysticks() > 0 && sdl_joystick == null {
        sdl_joystick = SDL_JoystickOpen(0);
        if sdl_joystick == null {
            print("Failed to open joystick!\n");
        }
    }


    e : SDL_Event;
    while SDL_PollEvent(*e) {
        ImGui_ImplSdl_ProcessEvent(*e);
        io := ImGui.GetIO();
        
        if e.type == SDL_KEYDOWN && e.key.repeat == 0 {
            input.just_pressed[e.key.keysym.scancode] = true;
            input.is_pressed[e.key.keysym.scancode] = true;
        } else if e.type == SDL_KEYUP {
            input.just_released[e.key.keysym.scancode] = true;
            input.is_pressed[e.key.keysym.scancode] = false;
        }
        
        if (io.WantCaptureMouse) {
            continue;
        }

        if e.type == SDL_MOUSEBUTTONDOWN && e.button.button == SDL_BUTTON_LEFT {
            input.mouse_pressed = true;
            input.mouse_just_pressed = true;
        } else if e.type == SDL_MOUSEBUTTONUP && e.button.button == SDL_BUTTON_LEFT {
            input.mouse_pressed = false;
            input.mouse_just_released = true;
        } else if e.type == SDL_MOUSEMOTION {
            input.mouse_motion.x = e.motion.xrel;
            input.mouse_motion.y = e.motion.yrel;
        }

        if e.type == SDL_MOUSEBUTTONDOWN && e.button.button == SDL_BUTTON_RIGHT {
            input.rmouse_pressed = true;
            input.rmouse_just_pressed = true;
        } else if e.type == SDL_MOUSEBUTTONUP && e.button.button == SDL_BUTTON_RIGHT {
            input.rmouse_pressed = false;
            input.rmouse_just_released = true;
        }

        if e.type == SDL_JOYAXISMOTION {
            if e.jaxis.which == 0 {
                // X axis motion
                if e.jaxis.axis == 0 {
                    normalized_value := e.jaxis.value / 32767.0;
                    if e.jaxis.value < -joystick.deadzone {
                        joystick.left_stick.x = normalized_value;
                    } else if e.jaxis.value > joystick.deadzone {
                        joystick.left_stick.x = normalized_value;
                    } else {
                        joystick.left_stick.x = 0;
                    }
                }
                // Y axis motion
                if e.jaxis.axis == 1 {
                    normalized_value := e.jaxis.value / 32767.0;
                    if e.jaxis.value < -joystick.deadzone {
                        joystick.left_stick.y = normalized_value;
                    } else if e.jaxis.value > joystick.deadzone {
                        joystick.left_stick.y = normalized_value;
                    } else {
                        joystick.left_stick.y = 0;
                    }
                }
            }
        }


        if e.type == SDL_QUIT {
            input.window_closed = false;
            return;
        }
    }
}

get_mouse_position :: () -> s32, s32 {
    mouse_x, mouse_y : s32;
    SDL_GetMouseState(*mouse_x, *mouse_y);
    return mouse_x, mouse_y;
}
