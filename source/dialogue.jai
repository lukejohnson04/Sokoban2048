MAX_TEXT_LENGTH :: 1024;

Dialogue_Node :: struct {
    text_buffer: [MAX_TEXT_LENGTH] u8;
    text_buffer_size := 0;
}

Dialogue_Player_State :: struct {
    nodes : Queue(Dialogue_Node, 64);
    index := 0;

    timer : float32;
    timer_interval : float32 = 0.1;

    open := false;
}

dialogue_update :: (using dialogue_state: *Dialogue_Player_State, input: *Input_State) {
    if queue_is_empty(*nodes) {
        open = false;
        return;
    }

    node := queue_peek(*dialogue_state.nodes);
    if nodes.count != 0 && dialogue_state.open == false {
        dialogue_state.open = true;
        dialogue_state.timer = 0;
        dialogue_state.index = 0;
    } else if dialogue_state.open == false {
        return;
    }

    line_finished := dialogue_state.index == node.text_buffer_size;
    if input.just_pressed[SDL_SCANCODE_Z] {
        if line_finished {
            queue_remove(*nodes);
            if queue_is_empty(*nodes) {
                open = false;
                return;                
            } else {
                dialogue_state.timer = 0;
                dialogue_state.index = 0;
            }
        } else {
            dialogue_state.index = node.text_buffer_size;
            return;
        }
    }

    if dialogue_state.index < node.text_buffer_size {
        timer += FRAME_TIME;
        if timer > timer_interval {
            timer -= timer_interval;
            dialogue_state.index += 1;
        }
    }
}

dialogue_queue_text :: (dialogue_state: *Dialogue_Player_State, text: string) {
    node := queue_add(*dialogue_state.nodes);
    memcpy(node.text_buffer.data, text.data, text.count);
    node.text_buffer_size = text.count;
}



generate_dialogue_queue :: (using state: *Dialogue_Player_State, id: u8) {
    if id == {
        case 0; {
            dialogue_queue_text(state, "Oh my goodness! Thank heavens you rescued me!");
            dialogue_queue_text(state, "I spent so long trying to find the perfect hiding spot for a key to my house...");
            dialogue_queue_text(state, "That I forgot I needed the key to get out as well!");
            dialogue_queue_text(state, "I've been stuck here for so long, wasting away my years just patiently waiting for someone to come by.");
            dialogue_queue_text(state, "Now that you've come by and restored my freedom, I'm now thinking nostolgically about the good times I had here.");
            dialogue_queue_text(state, "I cannot hold my emotions any longer! I should have appreciated what I had before I lost it.");
            dialogue_queue_text(state, "You know what? I think I'll stay put here after all!");
        }
    }
}