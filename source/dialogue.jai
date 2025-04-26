
Dialogue_Player_State :: struct {
    MAX_TEXT_LENGTH :: 1024;

    text_buffer: [MAX_TEXT_LENGTH] u8;
    text_buffer_size := 0;
    text: string;

    timer : float32;
    timer_interval : float32 = 0.1;

    open := false;
}

dialogue_update :: (using dialogue_state: *Dialogue_Player_State, input: *Input_State) {
    line_finished := text.count == text_buffer_size;
    if input.just_pressed[SDL_SCANCODE_Z] {
        if line_finished {
            open = false;
        } else {
            text.count = text_buffer_size;
        }
    }

    if text.count < text_buffer_size {
        timer += FRAME_TIME;
        if timer > timer_interval {
            timer -= timer_interval;
            text.count += 1;
        }
    }
}

dialogue_set_text :: (dialogue_state: *Dialogue_Player_State, text: string) {
    memcpy(dialogue_state.text_buffer.data, text.data, text.count);
    dialogue_state.text.data = dialogue_state.text_buffer.data;
    dialogue_state.text.count = 0;
    dialogue_state.text_buffer_size = text.count;
    dialogue_state.timer = 0;
    dialogue_state.open = true;
}
