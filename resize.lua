local capi      = { client = client }
local wibox     = require( "wibox"         )
local beautiful = require( "beautiful"     )
local awful     = require( "awful"         )
local surface   = require( "gears.surface" )
local shape     = require( "gears.shape"   )

local module,indicators,cur_c = {},nil,nil

local values = {"top"     , "top_right"  , "right" ,  "bottom_right" ,
                "bottom"  , "bottom_left", "left"  ,  "top_left"     }

local invert = {
    left  = "right",
    right = "left" ,
    up    = "down" ,
    down  = "up"   ,
}

local r_ajust = {
    left  = function(c, d) return { x      = c.x      - d, width = c.width   + d } end,
    right = function(c, d) return { width  = c.width  + d,                       } end,
    up    = function(c, d) return { y      = c.y      - d, height = c.height + d } end,
    down  = function(c, d) return { height = c.height + d,                       } end,
}

-- Resize tiled using the keyboard
local layouts_all = {
    [awful.layout.suit.floating]    = { right = "" },
    [awful.layout.suit.tile]        = { right = {mwfact= 0.05}, left = {mwfact=-0.05}, up ={wfact=-0.1  }, down = {wfact = 0.1 } },
    [awful.layout.suit.tile.left]   = { right = {mwfact=-0.05}, left = {mwfact= 0.05}, up ={wfact= 0.1  }, down = {wfact =-0.1 } },
    [awful.layout.suit.tile.bottom] = { right = {wfact=-0.1  }, left = {wfact= 0.1  }, up ={mwfact=-0.05}, down = {mwfact= 0.05} },
    [awful.layout.suit.tile.top]    = { right = {wfact=-0.1  }, left = {wfact= 0.1  }, up ={mwfact= 0.05}, down = {mwfact=-0.05} },
    [awful.layout.suit.spiral]      = { right = {wfact=-0.1  }, left = {wfact= 0.1  }, up ={mwfact= 0.05}, down = {mwfact=-0.05} },
    [awful.layout.suit.magnifier]   = { right = {mwfact= 0.05}, left = {mwfact=-0.05}, up ={mwfact= 0.05}, down = {mwfact=-0.05} },
    -- The other layouts cannot be resized using variables
}

local function create_indicators()
    local ret     = {}
    local angle   = -((2*math.pi)/8)

    -- Get the parameters
    local size     = beautiful.collision_resize_width or 40
    local s        = beautiful.collision_resize_shape or shape.circle
    local bw       = beautiful.collision_resize_border_width
    local bc       = beautiful.collision_resize_border_color
    local padding  = beautiful.collision_resize_padding or 7
    local bg       = beautiful.collision_resize_bg or beautiful.bg_alternate or "#ff0000"
    local fg       = beautiful.collision_resize_fg or beautiful.fg_normal    or "#0000ff"
    local arrow_bc = beautiful.collision_resize_arrow_border_color
    local arrow_bw = beautiful.collision_resize_arrow_border_width or 0

    for k,v in ipairs(values) do
        local w = wibox {
            width   = size,
            height  = size,
            ontop   = true,
            visible = true
        }

        angle = angle + (2*math.pi)/8

        local tr = (size - 2*arrow_bw - 2*padding) / 2

        w:setup {
            {
                {
                    {
                        widget = wibox.widget.imagebox
                    },
                    shape = shape.transform(shape.arrow)
                        : translate( tr,tr   )
                        : rotate   ( angle   )
                        : translate( -tr,-tr ),
                    bg           = fg,
                    border_color = arrow_bc,
                    border_width = arrow_bw,
                    widget       = wibox.container.background
                },
                margins = padding,
                widget  = wibox.container.margin,
            },
            bg                 = bg,
            shape              = s,
            shape_border_width = bw,
            shape_border_color = bc,
            widget             = wibox.container.background
        }

        if awesome.version >= "v4.1" then
            w.shape = s
        else
            surface.apply_shape_bounding(w, s)
        end

        ret[v] = w
    end

    return ret
end

function module.hide()
    if not indicators then return end

    for k,v in ipairs(values) do indicators[v].visible = false end

    if not cur_c then return end

    cur_c:disconnect_signal("property::geometry", module.display)
    cur_c = nil
end

function module.display(c,toggle)
    if type(c) ~= "client" then --HACK
        c = capi.client.focus
    end

    if not c then return end

    indicators = indicators or create_indicators()

    if c ~= cur_c then
        if cur_c then
        cur_c:disconnect_signal("property::geometry", module.display)
        end
        c:connect_signal("property::geometry", module.display)
        cur_c = c
    elseif toggle == true then
        module.hide()
    end

    for k,v in ipairs(values) do
        local w = indicators[v]
        awful.placement[v](w, {parent=c})
        w.visible = true
    end
end

function module.resize(mod,key,event,direction,is_swap,is_max)
    local c = capi.client.focus
    if not c then return true end

    local del = is_swap and -100 or 100
    direction = is_swap and invert[direction] or direction

    local lay = awful.layout.get(c.screen)

    if c.floating or lay == awful.layout.suit.floating then
        c:emit_signal("request::geometry", "mouse.resize", r_ajust[direction](c, del))
    elseif layouts_all[lay] then
        local ret = layouts_all[lay][direction]
        if ret.mwfact then
            awful.tag.incmwfact(ret.mwfact)
        end
        if ret.wfact then
            awful.client.incwfact(ret.wfact, c)
        end
    end

    return true
end

-- Always display the arrows when resizing
awful.mouse.resize.add_enter_callback(module.display, "mouse.resize")
awful.mouse.resize.add_leave_callback(module.hide   , "mouse.resize")

return module
-- kate: space-indent on; indent-width 4; replace-tabs on;
