MAX_TEXT_LENGTH :: 256;

Dialogue_Node :: struct {
    text_buffer: [MAX_TEXT_LENGTH] u8;
    text_buffer_size := 0;

    data_delta: Dialogue_Data_Delta;
    type := Node_Type.DIALOGUE;

    Node_Type :: enum #specified {
        DIALOGUE :: 0;
        DATA_DELTA :: 1;
    }
}

Text_Buffer :: struct {
    memory: [MAX_TEXT_LENGTH] u8;
    size := 0;
    flip_open := false;
}

DIALOGUE_TIMER_INTERVAL_REGULAR :: 0.05;
DIALOGUE_TIMER_INTERVAL_FAST :: 0.02;

Dialogue_Player_State :: struct {
    buffer: *Text_Buffer;
    index := 0;
    timer : float32;
    timer_interval : float32 = DIALOGUE_TIMER_INTERVAL_REGULAR;

    open := false;
}

// All data for dialogue that's transient throughout the game is stored here
Dialogue_Data :: struct {
    interaction_count: [256] [256] s32;
    talked_to_mayor: s32;
}

Dialogue_Data_Delta :: struct {
    variable: *s32;
    old_value: s32;
    new_value: s32;
}


// Frontend
// Interactable blocks have a texture id and a dialogue trigger id
// When you interact with a tile, the counter for the specific block and interaction id
// is incremented. For example a tile with number 5 and interaction id 3 would be incremented.
// To do this, we need a way to hash both numbers together with zero collisions.
dialogue_update :: (dialogue_state: *Dialogue_Player_State, input: *Input_State) {
    if dialogue_state.buffer == null {
        dialogue_state.open = false;
        return;
    }

    if dialogue_state.buffer.size != 0 && dialogue_state.open == false {
        dialogue_state.open = true;
        dialogue_state.timer = 0;
        dialogue_state.index = 0;
    } else if dialogue_state.open == false {
        return;
    }

    line_finished := dialogue_state.index == dialogue_state.buffer.size;
    if do_action(.REDO) {
        if line_finished {
            apply_turn();
        } else {
            dialogue_state.index = dialogue_state.buffer.size;
            return;
        }
    }

    if dialogue_state.index < dialogue_state.buffer.size {
        using dialogue_state;
        timer += FRAME_TIME;
        if timer > timer_interval {
            timer -= timer_interval;
            index += 1;
        }
    }
}

dialogue_queue_text :: (dialogue_state: *Dialogue_Player_State, text: string) {

    // node := queue_add(*dialogue_state.nodes);
    // memcpy(node.text_buffer.data, text.data, text.count);
    // node.text_buffer_size = text.count;
    // node.type = .DIALOGUE;
}

generate_interaction_queue :: (state: *Dialogue_Player_State, block: Block) {
    using context.game_state;
    assert(get_block_type(block) == .INTERACTABLE);

    new_interaction := false;
    top := turn_memory.curr;

    queue_text :: (text: string) #expand {
        if new_interaction == false || text.count == 0 {
            top.text.flip_open = true;
        }

        if new_interaction == false {
            new_interaction = true;
        }
        top.type = .DIALOGUE;
        top.next = top + 1;

        assert(text.count < MAX_TEXT_LENGTH);
        memcpy(top.text.memory.data, text.data, text.count);
        top.text.size = text.count;

        top += 1;
        top.next = null;
        top.prev = top - 1;
    }

    queue_dialogue_data_change :: (addr: *s32, value: s32) #expand {
        if new_interaction == false {
            new_interaction = true;
        }
        top.type = .DIALOGUE_CHANGE;
        top.next = top + 1;
        top.prev = top - 1;

        delta : Dialogue_Data_Delta;
        delta.variable = addr;
        delta.old_value = addr.*;
        delta.new_value = value;
        top.dialogue_delta = delta;

        top += 1;
        top.next = null;
        top.prev = top - 1;
    }

    Tile_Name :: enum u8 #specified {
        HIDDEN_HOUSE_OLD_MAN :: 0;
        ATLAS :: 8;
        PURPLE_GUY :: 9;
    }

    using Tile_Name;

    if block.interaction_id == 10_000 {
        queue_text("Game has been saved.");
        save_game();
        clear_turn_memory(*turn_memory);
        return;
    }
    assert(block.interaction_id < 256);

    count := level.dialogue_data.interaction_count[block.id][block.interaction_id];
    if block.id == {
        // Guy in hidden house
        case 112; {
            queue_text("Oh my goodness! Thank heavens you rescued me!");
            queue_text("I spent so long trying to find the perfect hiding spot for a key to my house...");
            queue_text("That I forgot I needed the key to get out as well!");
            queue_text("I've been stuck here for so long, wasting away my years just patiently waiting for someone to come by.");
            queue_text("Now that you've come by and restored my freedom, I'm now thinking nostalgically about the good times I had here.");
            queue_text("I cannot hold my emotions any longer! I should have appreciated what I had before I lost it.");
            queue_text("You know what? I think I'll stay put here after all!");
        }
        // Guy outside hot puzzle area
        case 113; {
            queue_text("I don't know why people even bother with some puzzles.");
            queue_text("Solving puzzles is already so dangerous, and some of the solutions I've seen can be kind of... complicated?");
            queue_text("I mean, not complicated. But like, involved.");
            queue_text("I saw a friend of mine solve a puzzle once and the puzzle itself was kind of messed up.");
            queue_text("As in, like, I couldn't tell if it was intentional or not, but to solve it he had to bring a block in from another room.");
            queue_text("It's always felt a little tricky for me. Too many things to consider. Puzzle solving's just not for me I guess.");
        }
        // Blue boy
        case 114; {
            if block.interaction_id == {
                // Top of town location
                case 0; {
                    queue_text("I don't care what my mom says. I am going to be the greatest block-pushing puzzle solver of all time!");
                }
                // Deep in puzzle location
                case 1; {
                    queue_text("Jeez lousie! I got so excited solving all these puzzles, that I ended up getting lost!");
                    queue_text("Thanks for finding me. You are a gentleman and a scholar!");
                }
            }
        }
        // Kid and mom
        case 115; #through;
        case 116; {
            queue_text("Mom look what I found!");
            queue_text("Can I please keep him as a pet? Pleeeeease?");
            queue_text("For the last time, no blocks allowed inside the house!");
        }
        // Guy with funny eyebrows
        case 117; {
            if block.interaction_id == {
                case 0; {
                    queue_text("I've been going through all the puzzles in the area and I can't help but ask myself...");
                    queue_text("Is it all just puzzles?");
                    queue_text("Are we the ones pushing boxes or is the mere concept of box pushing the one pushing us?");
                }
            }
        }

        // Sign
        case 118; {
            if block.interaction_id == {
                case 0; {
                    queue_text("In order to leave, you must seal off the entrance.");
                }
                case 1; {
                    queue_text("Tiletown Mines - KEEP OUT");
                }
                case 2; {
                    queue_text("WARNING: DO NOT PASS THIS POINT");
                    queue_text("The rest of this cave is uncharted. Tread at your own warning. You can and will get stuck. Rescue attempts will not be made.");
                }
                case 3; {
                    queue_text("Mineshaft is out of commission. Do not continue.");
                }
                case 4; {
                    queue_text("*It's a small stone tablet with writing engraved on it*");
                    queue_text("I know you can't see or hear me, but I am always thinking about you, and I hope you're thinking about me too.");
                    queue_text("If I had known this would have happened of course I would have done things differently.");
                    queue_text("I beg you for forgiveness and I beg God.");
                    queue_text("The fact you will always be there, stuck, thinking I abandoned you, is one I cannot accept.");
                    queue_text("I will wait a million turns and I'll wait a million more to see you again.");
                }
                case 5; {
                    queue_text("Private residential property - NO LOITERING!");
                }
                case 6; {
                    queue_text("Welcome to the Danger-Free Puzzle Zone!");
                    queue_text("All of our puzzles are ethically sourced, and developed cruelty-free!");
                    queue_text("Test your luck with our puzzles, designed so that there is no risk of getting stuck! Win a prize if you can solve one!");
                }
                case 7; {
                    if !level.dialogue_data.talked_to_mayor {
                        queue_text("Yowza!");
                    } else {
                        queue_text("Wow! You talked to the mayor?!?!");
                    }
                }
            }
        }
        // case 7; {
        //     queue_text("Jeez louise! Thank heavens you rescued me!");
        //     queue_text("I went exploring and accidentally pushed a boulder through this rooms only entrance.");
        //     queue_text("I immediately realized my horrific mistake. I got the boulder through the door, but couldn't go to the other side to unblock the exit.");
        //     queue_text("I have no idea how long I have been waiting. It felt like the first half of infinity, and longer still.");
        //     queue_text("Now that I'm free, I'm I can finally accomplish my true goal in life:");
        //     queue_text("Successfuly gerrymandering my hometown so that my cousin Jeffrey's vote no longer matters!");
        // }

        // Atlas
        case 96; {
            if block.interaction_id == {
                case 0; {
                    if count == 0 {
                        queue_text("Oh, thank God you found me!");
                        queue_text("I was starting to lose hope. I was exploring the caves, and I went rather deep, and, well, I got stuck.");
                        queue_text("I thought I knew the caves by heart, but I found this passageway I hadn't seen before. Of course I just had to explore it.");
                        queue_text("Usually, you might want to have a buddy explore with you, but I got so excited I just couldn't help myself.");
                        queue_text("There was so many new tunnels to explore...");
                        queue_text("I found a puzzle deep in the cave. I thought nobody explored the mines anymore, so I had no idea how long it had been there unsolved.");
                        queue_text("It felt like it was just calling my name, begging for me to solve it.");
                        queue_text("I spent so long lining it up and figuring it out, but when I finally solved it and was exploring the next area-");
                        queue_text("I realized I had moved a boulder in such a way that it blocked me off from escaping from the way I came!");
                        queue_text("Anyways, I appreciate the help. Guess it's my lucky day.");
                        queue_text("My name's Atlas, by the way. I haven't seen you around here before.");
                        queue_text("In fact, I haven't seen anyone around anywhere in a long time... My mom must be worried sick!");
                        queue_text("I've got to get going, but maybe I'll see you around?");
                    } else {
                        queue_text("I've got to get going, but maybe I'll see you around?");
                    }
                }
                case 1; {
                    queue_text("The town square is down South, but the only path leading into it has some kind of obstruction on the other side.");
                    queue_text("The mayor told me Jeremy, Tiletown's most legendary puzzle solver, is going to find a way through for us.");
                    queue_text("I'm willing to be patient, but the path's been blocked for a while already, so I'm getting a little worried.");
                    queue_text("It's the only path through to my family! What if they can never clear the path?");
                    queue_text("I'll have to find a new family to take me in!");
                    queue_text("Well, I mean, I guess I don't have to do that. It's not like I'm a child or anything.");
                    queue_text("But still! This whole situation has got my britches in a bunch!");
                }
            }
        }

        // Hiding person
        case 97; {
            if count == 0 {
                queue_text("Who says you can come to my home? I did not invite you.");
            } else if count == 1 {
                queue_text("Please leave immediately.");
            } else if count == 2 {
                queue_text("If you don't leave right now, I'm going to be forced to go berzerk.");
                queue_text("You know what happens when you mess with a guy like me? I'll push you around.");
                queue_text("I'll make you into a salad! Cut you up! Break you down! Huzzah!");
            } else {
                queue_text("Leave me alone.");
            }
        }

        // Mayor
        case 98; {
            if block.interaction_id == {
                case 0; {
                    queue_text("Greetings!");
                    queue_text("Welcome to Tiletown. I am the mayor of this town.");
                    queue_text("I don't think I've seen you before, you must be new around here!");
                    queue_text("We don't get visitors often.");
                    queue_text("Actually, we don't get visitors at all!");
                    queue_text("I haven't seen a single new face around here since my first turn in office!");
                    queue_text("But don't worry, we don't bite. I hope you enjoy your stay here in Tiletown!");
                    queue_dialogue_data_change(*level.dialogue_data.talked_to_mayor, 1);
                }
            }
        }

        // James Salad
        case 99; {
            queue_text("Hello there! The name's Salad. James, Salad");
            queue_text("Welcome to my little shop! You will find wares that are well worth your money.");
        }

        case; {
            queue_text(tprint("Interaction queue failed: % is not a valid interaction id", block.id));
            print("Interaction queue failed!\n");
            return;
        }
    }
    
    if new_interaction {
        addr := *level.dialogue_data.interaction_count[block.id][block.interaction_id];
        queue_dialogue_data_change(addr, addr.* + 1);
        queue_text("");
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

        queue_text("Yo mama so fat, she takes up two tiles!");
        queue_text("How could you say something so hurtful?");

        // House where there's a wall 2 blocks in front of the door, so the front door must be pushed in and not out
        // And the reason the wall is there is because construction accidentally came too close to the house, so
        // they got locked in on accident, and nobody has helped them until you pushed their front door in.
        // queue_text(")
    }
}
