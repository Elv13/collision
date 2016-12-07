local wibox     = require("wibox")
local placement = require("awful.placement")
local shape     = require("gears.shape")
local beautiful = require("beautiful")
local color     = require("gears.color")
local tag_header= require("collision.widgets.tag_header")

local module = {}

local function highlight(self)
    self:get_children_by_id("bg")[1].bg = beautiful.bg_focus
    self:get_children_by_id("bg")[1].fg = beautiful.fg_focus
end

local function unhighlight(self)
    self:get_children_by_id("bg")[1].bg = beautiful.bg_normal
    self:get_children_by_id("bg")[1].fg = beautiful.fg_normal
end

local function create_element(text, shortcut)
    return wibox.widget {
        {
            {
                text   = text,
                align  = "center",
                valign = "center",
                widget = wibox.widget.textbox,
            },
            {
                {
                    {
                        {
                            text   = shortcut,
                            align  = "center",
                            valign = "center",
                            widget = wibox.widget.textbox,
                        },
                        left = 10,
                        right = 10,
                        widget = wibox.container.margin
                    },
                    bg     = beautiful.fg_normal,
                    fg     = beautiful.bg_normal,
                    shape  = shape.rounded_rect,
                    widget = wibox.container.background,
                },
                widget = wibox.container.place
            },
            layout     = wibox.layout.flex.vertical,
        },
        id                 = "bg",
        highlight          = highlight,
        unhighlight        = unhighlight,
        shape_border_color = beautiful.fg_normal,
        shape_border_width = 2,
        shape              = shape.rounded_rect,
        bg                 = beautiful.bg_normal,
        widget             = wibox.container.background
    }
end

local function new(s)
    -- A wibox with client launch options
    local w = wibox {
        x       = s.geometry.x,
        y       = s.geometry.y,
        visible = true,
        ontop   = true,
        height  = 40,
        bg      = awesome.composite_manager_running and 
                    color.transparent or beautiful.menu_bg_normal,
    }

    -- Place it
    placement.bottom(w,{parent = nil, honor_workarea = true })
    placement.maximize_horizontally(w, {parent = nil, honor_workarea = true })

    -- Add the widgets
    local wdg = wibox.layout.flex.horizontal()
    wdg:set_spacing(20)

    -- Add some automatic launcher element
    local widgets = {
        auto    = create_element("Automatic"             , "Return"      ),
        cur_tag = create_element("Current tag"           , "ALT+Return"  ),
        float   = create_element("Current tag + Floating", "Shift+Return"),
        new_tag = create_element("New tag"               , "CTRL+Return" ),
    }

    for _, k in ipairs {"auto", "cur_tag", "float", "new_tag"} do
        wdg:add(widgets[k])
    end

    w:set_widget(wdg)

    -- Check if radical is used, awful.widgets.taglist isn't supported yet
    local w2, tags_by_id = tag_header(s)

    return {
        widgets = widgets,
        tags_by_id = tags_by_id,
        wiboxes = {
            generic = w,
            tags    = w2,
        }
    }

end

function module.hide(s)
    
end

return setmetatable(module, {__call = function(_, ...) return new(...) end})
