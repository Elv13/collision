--- Display extension points for the dynamic layouts
-- This module allow both mouse and keyboard spliting of the layout

local capi = {
    client     = client,
    screen     = screen,
    keygrabber = keygrabber
}

local utils     = require( "collision.util"       )
local wibox     = require( "wibox"                )
local beautiful = require( "beautiful"            )
local placement = require( "awful.placement"      )
local tag       = require( "awful.tag"            )
local util      = require( "awful.util"           )
local textbox   = require( "wibox.widget.textbox" )
local color     = require( "gears.color"          )
local cairo     = require( "lgi"                  ).cairo
local shape     = require( "gears.shape"          )

local module = {}

local current_context = nil

-- By default, use the US ASCII 104 key keyboard map, this map can be
-- monkeypatched to support other keyvoard layouts like cyrillic.
module.key_map = {
    "1", "2", "3", "4", "5",
    "6", "7", "8", "9", "0",
    "q", "w", "e", "r", "t",
    "y", "u", "i", "o", "p",
    "a", "s", "d", "f", "g",
    "h", "j", "k", "l", "z",
    "x", "c", "v", "b", "n",
    "m", "-", "=", ",", ".",
    ";", "'", "[", "]", "/",
    "!", "@", "#", "$", "%",
    "^", "&", "*", "(", ")",
    "+", "{", "}", ":", '"',
    "<", ">", "?", "`", "\\",
}

local dir_to_angle = {
    left   = math.pi * 1.5,
    right  = math.pi * 0.5,
    bottom = math.pi      ,
    top    = 0            ,
    middle = 0            ,
    stack  = 0            ,
}

local dir_to_width_offset_ratio = {
    internal = {
        left   = -0.5, right  = -0.5, top    = -0.5, bottom = -0.5, middle = -0.5, stack = -0.5,
    },
    sides = {
        left   =  -1 , right  =  0  , top    = -0.5, bottom = -0.5, middle = -0.5,
    }
}

local dir_to_height_offset_ratio = {
    internal = {
        left   = -0.5, right  = -0.5, top    = -0.5, bottom = -0.5, middle = -0.5, stack = -0.5,
    },
    sides = {
        left   = -0.5, right  = -0.5, top    =  0  , bottom = -1  , middle = -0.5,
    }
}

local dir_to_size = {
    left   = 60, right  = 60, top    = 60, bottom = 60, middle = 50, stack = 50,
}

local type_to_size_ratio = {
    internal =  0.7,
    sides    =  1  ,
}

-- Draw 2 rectangles, one with a background and the other stroke only
local function internal_rect_pattern(size, direction)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, size, size)
    local cr  = cairo.Context(img)

    cr:set_source(color(beautiful.collision_bg_splitter or beautiful.bg_normal or "#0000ff"))
    cr:paint()

    local fg = color(beautiful.collision_fg_splitter or beautiful.fg_normal or "#ffffff")
    local s,r,g,b,a = fg:get_rgba()
    cr:set_source_rgba(r,g,b,0.4)

    -- This one is different
    if direction == "stack" then
        cr:rectangle(3, 3, size - 12, size - 12)
        cr:stroke()
        cr:rectangle(9, 9, size - 12, size - 12)
        cr:stroke_preserve()
        cr:set_source_rgba(r,g,b,0.2)
        cr:fill()
        return cairo.Pattern.create_for_surface(img)
    end

    cr:translate(size/2,size/2)
    cr:rotate(dir_to_angle[direction])
    cr:translate(-size/2,-size/2)


    cr:rectangle(3, 3, size-6, size/2-6)
    cr:stroke()
    cr:rectangle(3, size/2+3, size-6, size/2-6)
    cr:stroke_preserve()
    cr:set_source_rgba(r,g,b,0.2)
    cr:fill()

    return cairo.Pattern.create_for_surface(img)
end

local type_to_bg = {
    internal = internal_rect_pattern
}

local function arrow_splitter(cr, width, height, direction)
    cr:move_to(width/2, height/2)
    cr:rotate(dir_to_angle[direction])
    utils.arrow_path(cr, width, 10)
end

local function box_splitter(cr,  width, height, direction)
    utils.draw_round_rect(cr,0,0,width,height,5)
end

local type_to_shape = {
    internal = box_splitter,
    sides    = arrow_splitter,
}

local function add_splitter(context, args)

    local s_type, direction = args.type or "sides" , args.direction or "middle"
    local points, size      = args.points or {args}, dir_to_size[direction] * type_to_size_ratio[s_type]

    local bg = beautiful.collision_bg_splitter or beautiful.bg_alternate or beautiful.bg_normal or "#0000ff"
    local width = size * #points

    local top_level_l = wibox.layout.flex.vertical()

    local l = wibox.layout.flex.horizontal()

    for k, point in ipairs(points) do
        context.count  = context.count + 1
        local dir      = point.direction or direction
        local shortcut = module.key_map[context.count]

        l:add(wibox.widget {
            {
                nil,
                {
                    nil,
                    {
                        {
                            {
                                markup = "<b>"..util.quote_pattern(shortcut).."</b>",
                                widget = wibox.widget.textbox
                            },
                            margins = 5,
                            widget  = wibox.container.margin
                        },
                        shape  = shape.circle,
                        fg     = beautiful.bg_normal,
                        bg     = beautiful.fg_normal,
                        widget = wibox.container.background,
                    },
                    nil,
                    expand = "none",
                    layout = wibox.layout.align.vertical
                },
                nil,
                expand = "none",
                layout = wibox.layout.align.horizontal
            },
            bg     = type_to_bg[s_type] and type_to_bg[s_type](size, dir) or nil,
            widget = wibox.container.background
        })

        context.hooks[shortcut] = point
    end

    local height = size

    if args.label then
        local tb = wibox.widget.textbox()
        tb:set_align("center")
        tb:set_text(args.label)
        tb:set_wrap("mode")
        height = height + tb:get_height_for_width(width)

        top_level_l:add(tb)
    end

    top_level_l:add(l)

    -- Create a wibox
    local w = wibox {
        width  = width,
        height = height,
        ontop  = true,
        bg     = bg  ,
    }

    if placement[args.position] then
        placement[args.position](w, args)
    end

    w:set_widget(top_level_l)

    utils.apply_shape_bounding(w, function(cr) type_to_shape[s_type](cr, w.width, w.height, direction) end)

    w.visible = true

    table.insert(context.points, w)

end

--- Loop in the hierarchy to find spliting points
local function drill(context, root, source)
    local widget = root:get_widget()
    if widget.splitting_points then
        local matrix = root:get_matrix_to_device()
        local x, y = matrix:transform_point(0, 0)
        local width, height = root:get_size()

        -- The client cannot be both the source and the target
        if not source and widget._client == context.client then
            context.client_widget = widget
            source = widget
        else
            local points = widget:splitting_points {
                x      = x + context.add_x,
                y      = y + context.add_y,
                width  = width,
                height = height,
            }

            if points and #points > 0 then
                for k, point in ipairs(points) do
                    add_splitter(context, point)
                end
            elseif points and points.points and #points.points > 0 then
                add_splitter(context, points)
            end
        end


    end

    for _, child in ipairs(root:get_children()) do
        source = drill(context, child, source)
    end

    return source
end

--- Search screens for compatible layouts
local function find_split_points(context)

    for s = 1, capi.screen.count() do
        local t = capi.screen[s].selected_tag
        if t then
            local layout = tag.getproperty(t, "layout")
            if layout and layout.is_dynamic then
                if layout.hierarchy then
                    local wa = layout.param.workarea
                    context.add_x, context.add_y = wa.x, wa.y
                    local source = drill(context, layout.hierarchy, nil)
                    if source then
                        context.source_root = layout.hierarchy:get_widget()
                    end
                end
            end
        end
    end
end

--- Hide all wiboxes, hopefully let them be GCed
local function hide(context)
    for k,w in ipairs(context.points) do
        w.visible = false
    end
    current_context = nil
end

-- Intercept the dynamic shortcut associated with a split point
local function start_keygrabber(context)
    capi.keygrabber.run(function(mod, key, event)
        local hook = context.hooks[key]
        if hook and hook.callback and event == "press" then
            context.hooks[key]:callback(context)
        end

        if event == "press" and not (key == "Shift_Lt" or key == "Shift_R") then
            hide(context)
            capi.keygrabber.stop()
        end
    end)
end

function module.display_layout_split(layout, client)
    if current_context then
        hide(current_context)
        return
    end

    -- Select the client
    local c = client or capi.client.focus

    if not c then return end

    --TODO set the client border red

    local context = {
        add_splitter = add_splitter,
        count        = 0 ,
        client       = c ,
        points       = {},
        hooks        = {},
    }

    find_split_points(context)

    current_context = context

    start_keygrabber(context)
end

function module.display_client_split(layout)
    --TODO once the client drawable are flexible enough to place more than 1
    -- client, tabs and drawable level layouts will be possible. The idea is
    -- to share the whole layout framework bwtween wibox, client layouts and
    -- client drawable.
end

function module.drag(c)
    --TODO
end

function module.add_prompt_hook(hook_key)
    --TODO Allow somehting like shift+enter in the prompt to add the new
    -- client in a specific position
end

return setmetatable(module, { __call = function(_, ...) return module.display_layout_split(...) end })
