
// Fit: element size is the minimum size to fit all children
// Grow: element is maximum size allowed by parent
UI_FIT :: 0.0;
UI_GROW :: -1.0;

UIElement :: struct {
    children: [..] UIElement;

    AXIS :: enum {
        X_AXIS;
        Y_AXIS;
    }
    using AXIS;

    main_axis := X_AXIS;

    position: Vector2;

    size: Vector2;

    padding: Vector2;
    background_color: Vector4;
    child_gap: float;

    #place size;
    struct {
        width: float;
        height: float;
    }
}

add_child :: (component: *UIElement, child: UIElement) {
    array_add(*component.children, child);
}

Layout_Fit_Sizing :: (head: *UIElement) {
    width_total := head.width;
    height_total := head.height;
    for *child: head.children {
        Layout_Fit_Sizing(child);
        if head.main_axis == .X_AXIS {
            if head.width == UI_FIT {
                width_total += child.width;
                height_total = max(height_total, child.height + head.padding.y * 2);
            }
        } else {
            if head.height == UI_FIT {
                height_total += child.height;
                width_total = max(width_total, child.width + head.padding.x * 2);
            }
        }
    }
    if head.children.count > 0 {
        if head.main_axis == .X_AXIS {
            if head.width == UI_FIT {
                width_total += (head.children.count - 1) * head.child_gap;
                width_total += head.padding.x * 2;
            }
        } else {
            if head.height == UI_FIT {
                height_total += (head.children.count - 1) * head.child_gap;
                height_total += head.padding.y * 2;
            }
        }
    }
    head.width = width_total;
    head.height = height_total;
}

Layout_Grow_Sizing :: (head: *UIElement) {
    remaining_width := head.width;
    remaining_height := head.height;
    grow_count := 0;
    for *child: head.children {
        if head.main_axis == .X_AXIS {
            if child.width > 0 {
                remaining_width -= child.width;
            } if child.width == UI_GROW {
                grow_count += 1;
            }
        } else {
            if child.height > 0 {
                remaining_height -= child.height;
            } if child.height == UI_GROW {
                grow_count += 1;
            }
        }
    }
    if head.main_axis == .X_AXIS {
        remaining_width -= head.padding.x * 2;
        if head.children.count > 0 {
            remaining_width -= head.child_gap * (head.children.count - 1);
        }
    } else {
        remaining_height -= head.padding.y * 2;
        if head.children.count > 0 {
            remaining_height -= head.child_gap * (head.children.count - 1);
        }
    }
    // Distribute the remaining width across all grow children
    for *child: head.children {
        if head.main_axis == .X_AXIS {
            if child.width == UI_GROW {
                child.width = remaining_width / grow_count;
            } if child.height == UI_GROW {
                child.height = head.height - head.padding.y * 2;
            }
        } else {
            if child.height == UI_GROW {
                child.height = remaining_height / grow_count;
            } if child.width == UI_GROW {
                child.width = head.width - head.padding.x * 2;
            }
        }
    }
    for *child: head.children {
        Layout_Grow_Sizing(child);
    }
}


Layout_Determine_Positions :: (head: *UIElement) {
    stride := 0.0;

    for *child: head.children {
        Layout_Determine_Positions(child);
        child.position = head.position + head.padding;
        if head.main_axis == .X_AXIS {
            child.position.x += stride;
            stride += child.size.x + head.child_gap;
        } else {
            child.position.y += stride;
            stride += child.size.y + head.child_gap;
        }
    }
}


Layout_Draw :: (head: *UIElement, position := Vector2.{0, 0}) {
    uniform(context.game_state.color_shader, "color", head.background_color);
    draw_rect(Rect.{p1 = position, p2 = position + head.size});

    for *head.children {
        Layout_Draw(it, position + it.position);
    }
}

Layout_Test :: () -> UIElement {
    panel := UIElement.{background_color = .{0.6, 0.7, 0.9, 1}, child_gap = 20, padding = .{15, 15}, size = .{UI_FIT, UI_FIT}, main_axis = .Y_AXIS};
    for 0..4 {
        button := UIElement.{background_color = .{1, 1, 1, 1}, size = .{200, 45}, padding = .{5, 5}};
        add_child(*panel, button);
    }

    Layout_Fit_Sizing(*panel);
    Layout_Grow_Sizing(*panel);
    Layout_Determine_Positions(*panel);
    return panel;
}

// Layout :: (element: UIElement, code: Code = {}) {
//     OpenElement(element);
//     #insert code;
//     CloseElement();
// }

// // Main menu
// Rect
//     Rect (header rect)
//         Text
//
//     Rect (buttons rect)
//         Rect
//             Text
//         Rect
//             Text
//         Rect
//             Text
//
