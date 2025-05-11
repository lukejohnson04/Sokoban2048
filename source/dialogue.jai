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


// All data for dialogue that's transient throughout the game is stored here
Dialogue_Data :: struct {
    interaction_count: [256] [256] u16;
}


// Frontend
// Interactable blocks have a texture id and a dialogue trigger id
// block.type = .INTERACTABLE;
// block.number = 5;
// block.interaction_id := hash_string("Guy");

// When you interact with a tile, the counter for the specific block and interaction id
// is incremented. For example a tile with number 5 and interaction id 3 would be incremented.
// To do this, we need a way to hash both numbers together with zero collisions.

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

generate_interaction_queue :: (state: *Dialogue_Player_State, using game_state: *Game_State, block: Block) {
    assert(block.type == .INTERACTABLE);

    new_interaction := false;

    queue_text :: (text: string) #expand {
        dialogue_queue_text(state, text);
        new_interaction = true;
    }

    Tile_Name :: enum u8 #specified {
        HIDDEN_HOUSE_OLD_MAN :: 0;
        ATLAS :: 8;
        PURPLE_GUY :: 9;
    }

    using Tile_Name;

    if block.interaction_id == 10_000 {
        queue_text("Game has been saved.");
        save_game(game_state);
        stack_clear(*move_stack);
        stack_clear(*checkpoint_stack);
        return;
    }
    assert(block.interaction_id < 256);

    count := level.dialogue_data.interaction_count[block.number][block.interaction_id];
    if block.number == {
        // Guy in hidden house
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
            queue_text("Solving puzzles is already so dangerous, and some of the solutions I've seen can be kind of... complicated?");
            queue_text("I mean, not complicated. But like, involved.");
            queue_text("I saw a friend of mine solve a puzzle once and the puzzle itself was kind of messed up.");
            queue_text("As in, like, I couldn't tell if it was intentional or not, but to solve it he had to bring a block in from another room.");
            queue_text("It's always felt a little tricky for me. Too many things to consider. Puzzle solving's just not for me I guess.");
        }
        // Blue boy
        case 2; {
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
        case 3; #through;
        case 4; {
            queue_text("Mom look what I found!");
            queue_text("Can I please keep him as a pet? Pleeeeease?");
            queue_text("For the last time, no blocks allowed inside the house!");
        }
        // Guy with funny eyebrows
        case 5; {
            if block.interaction_id == {
                case 0; {
                    queue_text("I've been going through all the puzzles in the area and I can't help but ask myself...");
                    queue_text("Is it all just puzzles?");
                    queue_text("Are we the ones pushing boxes or is the mere concept of box pushing the one pushing us?");
                }
            }
        }

        // Sign
        case 6; {
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
                    // queue_text("My love, I'm so so sorry things had to happen like this.");
                    // queue_text("I would have gladly offered myself in your place, if I had known you would get stuck the way you did.");
                    queue_text("I know you can't see or hear me, but I am always thinking about you, and I hope you're thinking about me too.");
                    queue_text("If I had known this would have happened of course I would have done things differently.");
                    queue_text("I beg you for forgiveness and I beg God.");
                    queue_text("The fact you will always be there, stuck, thinking I abandoned you, is one I cannot accept.");
                    queue_text("I will wait a million turns and I'll wait a million more to see you again.");
                }
                case 5; {
                    queue_text("Private residential property - NO LOITERING!");
                }
            }
        }
        case 7; {
            queue_text("Jeez louise! Thank heavens you rescued me!");
            queue_text("I went exploring and accidentally pushed a boulder through this rooms only entrance.");
            queue_text("I immediately realized my horrific mistake. I got the boulder through the door, but couldn't go to the other side to unblock the exit.");
            queue_text("I have no idea how long I have been waiting. It felt like the first half of infinity, and longer still.");
            queue_text("Now that I'm free, I'm I can finally accomplish my true goal in life:");
            queue_text("Successfuly gerrymandering my hometown so that my cousin Jeffrey's vote no longer matters!");
        }

        // Atlas
        case 8; {
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
        case 9; {
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
        case 10; {
            if block.interaction_id == {
                case 0; {
                    queue_text("Greetings!");
                    queue_text("Welcome to Tiletown. I am the mayor of this town.");
                    queue_text("I don't think I've seen you before, you must be new around here!");
                    queue_text("We don't get visitors often.");
                    queue_text("Actually, we don't get visitors at all!");
                    queue_text("I haven't seen a single new face around here since my first turn in office!");
                    queue_text("But don't worry, we don't bite. I hope you enjoy your stay here in Tiletown!");
                }
            }
        }

        case; {
            queue_text("Interaction queue failed!");
            print("Interaction queue failed!\n");
            return;
        }
    }
    
    if new_interaction {
        level.dialogue_data.interaction_count[block.number][block.interaction_id] += 1;
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
