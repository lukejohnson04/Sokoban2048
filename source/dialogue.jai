MAX_TEXT_LENGTH :: 1024;

Dialogue_Node :: struct {
    text_buffer: [MAX_TEXT_LENGTH] u8;
    text_buffer_size := 0;
}

Dialogue_Player_State :: struct {
    nodes : Queue(Dialogue_Node, 64);
    index := 0;

    timer : float32;
    timer_interval : float32 = 0.05;

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
    queue_text :: (text: string) #expand {
        dialogue_queue_text(state, text);
    }

    if id == {
        case 0; {
            queue_text("Oh my goodness! Thank heavens you rescued me!");
            queue_text("I spent so long trying to find the perfect hiding spot for a key to my house...");
            queue_text("That I forgot I needed the key to get out as well!");
            queue_text("I've been stuck here for so long, wasting away my years just patiently waiting for someone to come by.");
            queue_text("Now that you've come by and restored my freedom, I'm now thinking nostalgically about the good times I had here.");
            queue_text("I cannot hold my emotions any longer! I should have appreciated what I had before I lost it.");
            queue_text("You know what? I think I'll stay put here after all!");
        }
        case 1; {
            queue_text("I don't know why people even bother with some puzzles.");
            queue_text("My buddy Eric told me about a puzzle where the solution involved bringing in a block from the previous room!");
            queue_text("Of course, he must be lying. A puzzle that requires that attention to detail is simply absurd!");
        }
        case 2; {
            queue_text("I don't care what my mom says. I am going to be the greatest block-pushing puzzle solver of all time!");
        }
        case 3; #through;
        case 4; {
            queue_text("Mom look what I found!");
            queue_text("Can I please keep him as a pet? Pleeeeease?");
            queue_text("For the last time, no blocks allowed inside the house!");
        }
        case 5; {
            queue_text("I've been going through all the puzzles in the area and I can't help but ask myself...");
            queue_text("Is it all just puzzles?");
            queue_text("Are we the ones pushing boxes or is the mere concept of box pushing the one pushing us?");
        }
        case 6; {
            queue_text("In order to leave, you must seal off the entrance.");
        }
    }

    // Ideas
    #if false {
        queue_text("One must wonder what the meaning of this all is. Are we put here just to push blocks?");
        queue_text("Is there a greater reason behind it all? Or are we just blocks on a grid?");

        queue_text("I had a crazy idea last night. What if there were blocks that could push themselves?");

        queue_text("I had a dream that I was in a Utopia.");
        queue_text("An endless world of blocks that push themselves.");
        queue_text("In a world like that, there's no need for us to push the blocks anymore.");
        queue_text("We could finally rest.");

        queue_text("Do you think blocks like it when we push them around?");

        // House where there's a wall 2 blocks in front of the door, so the front door must be pushed in and not out
        // And the reason the wall is there is because construction accidentally came too close to the house, so
        // they got locked in on accident, and nobody has helped them until you pushed their front door in.
        // queue_text(")
    }
}
