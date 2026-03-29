
TEXT_BUFFER_COUNT :: 1024;
MAX_TEXT_LENGTH :: 128;

UI_Memory :: struct {
    text: [TEXT_BUFFER_COUNT][MAX_TEXT_LENGTH] u8;
    text_count : u16 = 0;
}

UIElement :: struct {
    children: [..] UIElement;
    parent: *UIElement;

    type: UI_Type = .GENERIC;
    id: u16;

    sizing: Sizing;
    size: Vector2;

    background_color: Vector4;
}

Sizing :: enum {
    FILL;
    ABSOLUTE;
}

UI_Type :: enum {
    GENERIC;
    BUTTON;
    VERTICAL_CONTAINER;
    HORIZONTAL_CONTAINER;
}

add_child :: (element: *UIElement, child: UIElement) {
    to_add := child;
    to_add.parent = element;
    array_add(*element.children, to_add);
} 

create_button :: () -> UIElement {
    button: UIElement;
    button.id = context.game_state.ui_memory.text_count;
    button.type = .BUTTON;
    context.game_state.ui_memory.text_count += 1;
    assert(button.id < TEXT_BUFFER_COUNT);
    return button;
}

create_button :: (str: string) -> UIElement {
    button: UIElement = create_button();
    button_set_text(*button, str);
    return button;
}

is_button :: (element: UIElement) -> bool {
    return element.type == .BUTTON;
}


button_set_text :: (button: *UIElement, str: string) {
    assert(str.count <= MAX_TEXT_LENGTH);
    memset(context.game_state.ui_memory.text[button.id].data, 0, MAX_TEXT_LENGTH);
    memcpy(context.game_state.ui_memory.text[button.id].data, str.data, str.count);
}

Pause_Menu :: () -> UIElement {
    canvas: UIElement;
    canvas.sizing = .FILL;

    button_list: UIElement;
    button_list.type = .VERTICAL_CONTAINER;
    button_list.sizing = .FILL;
    button_list.size.x = 0.5;
    button_list.size.y = 1.0;

    button1 := create_button("Resume");
    button2 := create_button("Settings");
    button3 := create_button("Exit level");
    button4 := create_button("Main menu");

    for UIElement.[button1, button2, button3, button4] {
        add_child(*button_list, it);
    }

    add_child(*canvas, button_list);

    return canvas;
}


UI_Draw :: (element: *UIElement) {

}
