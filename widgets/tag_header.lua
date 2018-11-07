local wibox     = require("wibox")
local placement = require("awful.placement")
local shape     = require("gears.shape")
local beautiful = require("beautiful")
local color     = require("gears.color")

local module = {}

local function get_taglist()
    return require("radical.impl.taglist")
end

local function pointer_fit(self, context, width, height)
    return width, height
end

local function add_widget_to_widget(self, w1, w2)
    table.insert(self._private.w2w, {w1, w2})
    self:emit_signal("widget::redraew_needed")
end

local function add_point_to_widget(self, point, w, align)
    self._private.p2w[w] = point
    self:emit_signal("widget::redraew_needed")
end

local function set_text(self, text)
    self:get_children_by_id("text")[1].text = "  "..text.."  "
end

local function highlight(self)
    self:get_children_by_id("bg")[1].bg = "#ff0000"
end

local function unhighlight(self)
    self:get_children_by_id("bg")[1].bg = color.transparent
end

local function highlightable_label(text)
    local w = wibox.widget {
        {
            {
                text   = "  "..text.."  ",
                align  = "center",
                valign = "center",
                id     = "text",
                wrap   = false,
                widget = wibox.widget.textbox,
            },
            id          = "bg",
            bg          = beautiful.fg_normal,
            fg          = beautiful.bg_normal,
            shape       = shape.rounded_rect,
            widget      = wibox.container.background,
        },
        highlight   = highlight,
        unhighlight = unhighlight,
        widget      = wibox.container.place
    }
    assert(w.highlight)
    rawset(w,"set_text", set_text)
    return w, w:get_children_by_id("bg")[1]
end

local radius = 3

local function pointer_draw(self, context, cr, width, height)
    -- This assumes the "layout()" function has already been called

    local line_y_offset, max_line_y_offset = nil
    local line_spacing = cr.line_width * 2
    local last_x, last_w_x = 0,0
    local clear_at = 0

    local ret = {}

    local function handle_hierarchy(h, count, next_count)
        local widget = h:get_widget()

        -- All sub-areas of a stack are to be displayed in a "fair" grid.
        local matrix = h:get_matrix_to_device()
        local x, y = matrix:transform_point(0, 0)
        local width, height = h:get_size()

        if self._private.p2w[widget] then

            local point = self._private.p2w[widget]

            local dx = (point.x == 0 and radius or 0) + (point.width and point.width/2 or 0)
            local dy = point.y == 0 and radius or 0

            if count and not line_y_offset then
                local free_height = (y-radius) - (dy+point.y) - line_spacing
                max_line_y_offset = math.min(free_height, line_spacing*count)
                line_y_offset = max_line_y_offset
            end


            -- TODO Corner case 0: There less than max_line_y_offset/(line_spacing*2)
            -- lines remaining
            if line_y_offset == max_line_y_offset and last_w_x < point.x+dx then
                -- Corner case 1: Possible to access the left side |___
                cr:move_to(dx+point.x, dy+point.y)
                cr:line_to(dx+point.x, y+height/2)
                cr:line_to(x+width/2, y+height/2)
                cr:stroke()

                cr:arc(dx+point.x, dy+point.y, radius, 0, 2*math.pi)
                cr:fill()

                cr:arc(x-radius/2, y+height/2, radius, 0, 2*math.pi)
                cr:fill()
            elseif line_y_offset == max_line_y_offset and last_w_x < point.x+point.width-point.height then
                -- Corner case 2: Possible to access the left side by moving the origin |___
                cr:move_to(point.x+point.width-point.height, dy+point.y)
                cr:line_to(point.x+point.width-point.height, y+height/2)
                cr:line_to(x+width/2, y+height/2)
                cr:stroke()

                cr:arc(point.x+point.width-point.height, dy+point.y, radius, 0, 2*math.pi)
                cr:fill()

                cr:arc(x-radius/2, y+height/2, radius, 0, 2*math.pi)
                cr:fill()

            elseif line_y_offset == max_line_y_offset and point.x+dx > clear_at then
                -- Corner case 4: Add an extra line to save another layer

                local extra_y = dy+point.y + line_y_offset + line_spacing*1.1

                cr:move_to(dx+point.x, dy+point.y)
                cr:line_to(dx+point.x, extra_y)
                cr:line_to(last_w_x, extra_y)
                cr:line_to(last_w_x, extra_y)
                cr:line_to(last_w_x, y+height/2)
                cr:line_to(x+width/2, y+height/2)
                cr:stroke()

                cr:arc(dx+point.x, dy+point.y, radius, 0, 2*math.pi)
                cr:fill()

                cr:arc(x-radius/2, y+height/2, radius, 0, 2*math.pi)
                cr:fill()

                clear_at = last_w_x + 2*line_spacing
                -- TODO Corner case 5: Add as many corner as required
            else
                -- Normal case ^---___

                -- Corner case 3: There is enough room to avoid an offset
                if dx+point.x < last_x then
                    line_y_offset = line_y_offset - line_spacing
                end

                cr:move_to(dx+point.x, dy+point.y)
                cr:line_to(dx+point.x, dy+point.y + line_y_offset)
                cr:line_to(x+width/2,dy+point.y + line_y_offset)
                cr:line_to(x+width/2,y-radius)


                if line_y_offset <= 0 then
                    line_y_offset = max_line_y_offset
                end

                cr:stroke()

                cr:arc(dx+point.x, dy+point.y, radius, 0, 2*math.pi)
                cr:fill()

                cr:arc(x+width/2, y-radius, radius, 0, 2*math.pi)
                cr:fill()

                last_x = x+width/2 + line_spacing
                clear_at = 99999
            end

            last_w_x = x+width + line_spacing
        else
            for _, child in ipairs(h:get_children()) do
                handle_hierarchy(child, next_count, #h:get_children())
            end
        end

    end

    handle_hierarchy(context.wibox._drawable._widget_hierarchy)
end

local function pointer_widget()
    local ret = wibox.widget.base.make_widget(nil, nil, {
        enable_properties = true,
    })

    rawset(ret, "fit" , pointer_fit )
    rawset(ret, "draw", pointer_draw)
    rawset(ret, "add_widget_to_widget", add_widget_to_widget)
    rawset(ret, "add_point_to_widget", add_point_to_widget)

    ret._private.p2w = {}
    ret._private.w2w = {}

    return ret
end

local function new(s)
    local exist, tg = pcall(get_taglist,s)

    if exist then

        -- Add the top bar
        local w2 = wibox {
            x       = s.geometry.x,
            y       = s.geometry.y,
            visible = true,
            ontop   = true,
            height  = 40,
            bg      = awesome.composite_manager_running and
                        "#000000AA" or beautiful.menu_bg_normal,
            --fg      = beautiful.menu_fg_normal,
        }

        local tags_by_id = {}

        -- Place it
        placement.top(w2,{parent = nil, honor_workarea = true })
        placement.maximize_horizontally(w2, {parent = nil, honor_workarea = true })

        local l = wibox.layout.flex.horizontal()
        l.spacing = 20
        l.by_id = {}

        w2:set_widget( wibox.widget {
            {
                id     = "pointer_widget",
                widget = pointer_widget,
            },
            {
                nil,
                nil,
                l,
                widget     = wibox.layout.align.vertical,
            },
            widget = wibox.layout.stack,
        })
        local pointer = w2.widget:get_children_by_id("pointer_widget")[1]

        local pos = tg.get_positions(s)
        local rects, r_w = {}, s.geometry.width / #pos

        for k, rect in ipairs(pos) do
            local wdg, wdg_point = highlightable_label(rect.tag.name.." Mod4+"..k)

            l:add(wdg)
            l.by_id[tostring(k)] = wdg
            rect.x = rect.x - s.geometry.x
            pointer:add_point_to_widget(rect, wdg_point)
            tags_by_id[tostring(k)] = rect.tag

            table.insert(rects, {
                tag       = rect.tag,
                x         = (k - 1)*r_w + s.geometry.x,
                y         = s.geometry.y,
                height    = 40,
                width     = r_w,
            })
        end

        function w2:highlight(id, value)
            l.by_id[id]:highlight()
        end

        return w2, tags_by_id, rects
    end

end

return setmetatable(module, {__call = function(_, ...) return new(...) end})
