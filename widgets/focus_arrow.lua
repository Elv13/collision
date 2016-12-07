local wibox     = require( "wibox"          )
local surface   = require( "gears.surface"  )
local beautiful = require( "beautiful"      )
local shape     = require( "gears.shape"    )
local col_utils = require( "collision.util" )

local angle = {
    up    = 1,
    right = 2,
    down  = 3,
    left  = 4,
    cente = 5,
}

return function(dir)
    local s        = beautiful.collision_focus_shape or shape.rounded_rect
    local bw       = beautiful.collision_focus_border_width
    local bc       = beautiful.collision_focus_border_color
    local padding  = beautiful.collision_focus_padding or 7
    local bg       = beautiful.collision_focus_bg or beautiful.bg_alternate or "#ff0000"
    local fg       = beautiful.collision_focus_fg or beautiful.fg_normal    or "#0000ff"
    local bg_focus = beautiful.collision_focus_bg_center or beautiful.bg_urgent or "#ff0000"

    local w = wibox {
        height = 75,
        width  = 75,
        ontop  = true
    }

    local r_shape = dir == "center" and shape.circle or s
    local r_bg    = dir == "center" and bg_focus    or bg

    w:setup {
        dir ~= "center" and {
            {
                {
                    widget = wibox.widget.imagebox
                },
                shape  = shape.transform(col_utils.arrow_path2)
                    : rotate_at(55/2, 55/2, (angle[dir]-1)*(2*math.pi)/4),
                bg     = fg,
                widget = wibox.container.background
            },
            margins = padding,
            widget  = wibox.container.margin,
        } or {
            widget = wibox.widget.imagebox
        },
        bg                 = r_bg,
        shape              = r_shape,
        shape_border_width = bw,
        shape_border_color = bc,
        widget             = wibox.container.background
    }

    surface.apply_shape_bounding(w, r_shape)

    return w
end
