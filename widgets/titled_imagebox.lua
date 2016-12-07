local wibox     = require( "wibox"       )
local shape     = require( "gears.shape" )
local beautiful = require( "beautiful"   )

local function separator_fit(self, context, width,height)
    return width, 5
end

local function separator_draw(self, content, cr, width, height)
    cr:move_to(4, 3)
    cr:line_to(width - 8, 1)
    cr:stroke()
end

local theme_cache = {}

local function get_theme(prefix)
    prefix = prefix and (prefix .. "_") or ""

    if theme_cache[prefix] then return theme_cache[prefix] end

    local ret = {}

    ret.bg = beautiful["collision_"..prefix.."_bg"]
        or beautiful.collision_bg
        or beautiful.menu_bg_normal
        or beautiful.bg_normal

    ret.fg = beautiful["collision_"..prefix.."_fg"]
        or beautiful.collision_fg
        or beautiful.fg_normal

    ret.spacing = beautiful["collision_"..prefix.."_spacing"]
        or beautiful.collision_spacing
        or 0

    ret.margins = beautiful["collision_"..prefix.."_margins"]
        or beautiful.collision_margins
        or 4

    ret.shape = beautiful["collision_"..prefix.."_shape"] or shape.rectangle

    ret.border_color = beautiful["collision_"..prefix.."_border_color"]
        or beautiful.collision__border_color
        or beautiful.fg_normal

    ret.border_width = beautiful["collision_"..prefix.."_border_width"]
        or beautiful.collision_border_width
        or 2

    theme_cache[prefix] = ret

    return ret
end

return function(title, image_w, theme_prefix, orientation)
    local theme = get_theme(theme_prefix)

    local ss = {
        image_w,
        fill_horizontal = orientation ~= "horizontal",
        fill_vertical   = true,
        widget = wibox.container.place,
    }
print("\n\n\nFOO",wibox.layout.fixed[orientation or "vertical"])
    return wibox.widget {
        {
            {
                orientation == "horizontal" and ss or nil,
                {
                    text   = title,
                    wrap   = true,
                    align  = "center",
                    valign = "center",
                    widget = wibox.widget.textbox
                },
                orientation ~= "horizontal" and {
                    draw   = separator_draw,
                    fit    = separator_fit,
                    widget = wibox.widget.base.make_widget
                } or nil,
                orientation ~= "horizontal" and ss or nil,
                spacing = theme.spacing,
                layout  = wibox.layout.fixed[orientation or "vertical"],
            },
            margins = theme.margins,
            widget  = wibox.container.margin,
        },
        bg                 = theme.bg,
        fg                 = theme.fg,
        shape              = theme.shape,
        shape_border_width = theme.border_width,
        shape_border_color = theme.border_color,
        widget             = wibox.container.background
    }
end
