local awful       = require("awful")
local wibox       = require("wibox")
local shape       = require("gears.shape")
local placement   = require("awful.placement")
local title_image = require("collision.widgets.titled_imagebox")
local screenshot  = require("collision.widgets.screenshot")
local client_grid = require("collision.widgets.client_grid")
local tag_header  = require("collision.widgets.tag_header")

local capi = {client = client, screen = screen}

local module = {}

-- Swaps cannot be performed on groups until Awesome supports better Z-indexes
-- for both wibox and client
local delayed_swap = nil

local function on_exit_common(c)
    if delayed_swap then
        c:swap(delayed_swap.client and delayed_swap.client or delayed_swap)
    end

    delayed_swap = nil
end

local function has_selected(tags, screen)
    if #tags == 0 then return false end

    for _, t in ipairs(screen.selected_tags) do
        if awful.util.table.hasitem(tags, t) then return true end
    end

    return false
end

local function get_minimized_clients(clients)
    local ret = {}

    for _, c in ipairs(clients) do
        if c.minimized and has_selected(c:tags(), c.screen) then
            table.insert(ret, c)
        end
    end

    return ret
end

local function get_tiled_clients(clients)
    local ret = {}

    for _, c in ipairs(clients) do
        if c.floating or c.maximized_horizontal or c.maximized_vertical then
            table.insert(ret, c)
        end
    end

    return ret
end

local function get_floating_clients(clients)
    local ret = {}

    for _, c in ipairs(clients) do
        if not c.floating
            and not c.fullscreen
            and not c.maximized_vertical
            and not c.maximized_horizontal then
            table.insert(ret, c)
        end
    end

    return ret
end

--- Free a small area if there is minimized clients on the screen
local function crop_rect(elements, rect)

    local y2 = rect.y + rect.height

    local height = rect.y < elements.min_y and (
        y2 - elements.min_y
    ) or rect.height

    local y = math.max(elements.min_y, rect.y)

    height = (rect.y+height > elements.max_y) and (elements.max_y-y) or height

    return { --TODO just mutate the original
        x         = rect.x,
        y         = y,
        width     = rect.width,
        height    = height,
        client    = rect.client,
        tag       = rect.tag,
        on_exit   = rect.on_exit,
        on_select = rect.on_select,
        on_swap   = rect.on_swap,
        group     = rect.group,
        geometry  = function(self) return self end,
    }
end

local function get_areas_static(elements)
    if elements.dynamic then return end

    for k, c in ipairs(elements.tiled) do
        local geo = c:geometry()
        geo.client = c
        function geo:geometry() return self end
        table.insert(elements.rects, crop_rect(elements, geo))
    end
end

local function simple_widget(c, orientation)
    local ret = title_image(c.name, c.icon
        and wibox.widget.imagebox(c.icon) or screenshot(c), nil, orientation
    )
    ret.client = c
    return ret
end

local function add_areas_groups(elements, wb)
    local geo = wb:geometry()
    wb._drawable:_do_redraw()

    local add_x, add_y = geo.x, geo.y

    local function handle_hierarchy(h, force_rect)
        local widget = h:get_widget()

        -- All sub-areas of a stack are to be displayed in a "fair" grid.
        if widget.client then
            local matrix = h:get_matrix_to_device()
            local x, y = matrix:transform_point(0, 0)
            local width, height = h:get_size()

            -- As there is an overlay on top of the client, there is no point
            -- to focus it already (beside the tasklist update).
            local function on_exit()
                capi.client.focus = widget.client
                widget.client:raise()
                on_exit_common(widget.client)
            end

            local rect = nil

            -- Swap cannot be done on a stack as the widget may be below the
            -- client
            local function on_swap(other_c)
                rect.client:swap(other_c.client)
                other_c.client, rect.client  = rect.client, other_c.client
                --TODO update the screenshot
            end

            rect = crop_rect(elements, {
                x        = x + add_x,
                y        = y + add_y,
                width    = width,
                height   = height,
                client   = widget.client,
                group    = force_rect,
                on_exit  = on_exit,
                geometry = function(self) return self end,
            })
            table.insert(elements.rects, rect)
        end

        for _, child in ipairs(h:get_children()) do
            handle_hierarchy(child, force_rect)
        end
    end

    assert(wb._drawable._widget_hierarchy)
    handle_hierarchy(wb._drawable._widget_hierarchy)
end

--- Create a "fair" layout (a flex grid) and place the elements of the groups
local function get_areas_groups(elements, groups)
    for _, g in ipairs(groups) do
        local w = g.widget.nav_wibox
        if w then
            w.widget:reload(g)
            w.visible = true
            table.insert(elements.wiboxes, w)
        else

            local wdg = client_grid(g)

            w = wibox {
                visible = true,
                ontop = true,
                widget = wdg,
            }
            table.insert(elements.wiboxes, w)
            g.widget.nav_wibox = w
        end

        placement.maximize(w, {parent=crop_rect(elements,g.rect)})
        add_areas_groups(elements, w)
    end
end

local function get_areas_dynamic(elements)
    if not elements.dynamic then return end

    --Move to the work area
    local workarea = elements.handler.param.workarea

    local add_x, add_y = 0, 0

    local groups = {}

    local function handle_hierarchy(h, force_rect)
        local widget = h:get_widget()

        -- All sub-areas of a stack are to be displayed in a "fair" grid.
        if (not force_rect) and widget.is_stack then
            local matrix = h:get_matrix_to_device()
            local x, y = matrix:transform_point(0, 0)
            x, y =  x + workarea.x, y + workarea.y
            local width, height = h:get_size()

            force_rect = {
                widget = widget,
                rect = {
                    geometry = function(self) return self end,
                    x        = x + add_x,
                    y        = y + add_y,
                    width    = width,
                    height   = (y + add_y + height<= elements.max_y) and height
                       or height - (y + add_y + height - elements.max_y),
                }
            }

            table.insert(groups, force_rect)

        elseif widget._client then
            local matrix = h:get_matrix_to_device()
            local x, y = matrix:transform_point(0, 0)
            x, y =  x + workarea.x, y + workarea.y
            local width, height = h:get_size()

            -- It is safe to focus the client when selecting it unless the
            -- layout ask otherwise[TODO]
            local function on_select()
                capi.client.focus = widget._client
            end

            local rect = nil

            -- Swap is safe as long as it doesn't enter a stack
            local function on_swap(other_c)
                rect.client:swap(other_c.client)
                other_c.client, rect.client  = rect.client, other_c.client
            end

            -- Assume the client have just been focused, now, raise
            local function on_exit()
                widget._client:raise()
                on_exit_common(widget._client)
            end

            rect = crop_rect(elements, {
                x         = x + add_x,
                y         = y + add_y,
                width     = width,
                height    = height,
                client    = widget._client,
                group     = force_rect,
                on_select = on_select,
                on_exit   = on_exit,
                on_swap   = on_swap,
                geometry  = function(self) return self end,
            })
            table.insert(force_rect or elements.rects, rect)
        end

        for _, child in ipairs(h:get_children()) do
            handle_hierarchy(child, force_rect)
        end
    end

    handle_hierarchy(elements.handler.hierarchy)

    get_areas_groups(elements, groups)
end

local function get_areas_minimzed(elements)
    if #elements.minimized == 0 then return end

    local w = wibox {
        x       = elements.workarea.x,
        y       = elements.max_y,
        height  = 40,
        width   = elements.workarea.width,
        visible = true,
        ontop   = true,
    }
    table.insert(elements.wiboxes, w)

    local wdg = wibox.layout.flex.horizontal()

    local width = elements.workarea.width/#elements.minimized
    for k, c in ipairs(elements.minimized) do

        -- Only unminimize when we are sure nothing else will be selected
        local function on_exit()
            capi.client.focus = c
            c:raise()
            on_exit_common(c)
        end

        -- Show some visual clues
        local function on_select()
            --TODO
        end

        -- Obviously, swapping something minimized will mess everything up
        local function on_swap(other_c)
            delayed_swap = other_c
--             c:swap(other_c.client)
            --TODO update the screenshot
        end

        table.insert(elements.rects, {
            x         = elements.workarea.x + (k-1)*width,
            width     = width,
            height    = 40,
            y         = elements.max_y,
            client    = c,
            on_exit   = on_exit,
            on_select = on_select,
            on_swap   = on_swap,
            geometry  = function(self) return self end,
        })
        wdg:add(simple_widget(c, "horizontal"))
    end

    w.widget = wdg
end

local function get_area_tag(elements)
    local w, _, rects = tag_header(capi.screen[1])
    if not w then return end

    table.insert(elements.wiboxes, w)

    for k, t in ipairs(rects) do
        local function on_exit()
            t.tag:view_only()
            w.visible = false
            print("\n\n\nHIDE",w.visible)
            on_exit_common(c)
        end

        table.insert(elements.rects, {
            x         = t.x,
            width     = t.width,
            height    = t.height,
            y         = t.y,
            tag       = t.tag,
--             client    = nil,
            on_exit   = on_exit,
--             on_select = on_select,
--             on_swap   = on_swap,
            geometry  = function(self) return self end,
        })
    end
end

local function debug_rects(s, elements)
    local wdg = wibox.widget.base.make_widget()

    function wdg:draw(context, cr, width, height)

        for _, v in ipairs(elements.rects) do
            cr:set_source_rgba(1,0,0,1)
            cr:rectangle(v.x, v.y, v.width, v.height)
            cr:stroke_preserve()
            cr:set_source_rgba(1,0,0,0.1)
            cr:fill()
        end

    end

    function wdg:fit(context, width, height)
        return width, height
    end

    local w = wibox {
        x       = elements.workarea.x,
        y       = elements.workarea.y,
        width   = elements.workarea.width,
        height  = elements.workarea.height,
        visible = true,
        widget  = wdg,
    }
    table.insert(elements.wiboxes, w)
end

local function hide(self)
    for _, w in ipairs(self.wiboxes) do
        w.visible = false
    end
end

--- Build a list of all areas that can be focued
--
-- * All tiled client
-- * All stacked clients
-- * All minimized clients
--
local function get_areas()
    local self = {
        hide    = hide,
        wiboxes = {},
        rects   = {}
    }

    for s in capi.screen do
        local clients = capi.client.get(s, false)

        local l = awful.layout.get(s)

        -- My Awesome fork support tabbing and dynamic layouts, this provide
        -- much more meta-data about the current tiled clients
        local has_dynamic_layout = l.is_dynamic

        -- Get the static elements (clients)
        local elements = {
            minimized = get_minimized_clients(clients),
            --floating= get_floating_clients(clients),
            tiled     = has_dynamic_layout and {} or get_tiled_clients(clients),
            workarea  = s.workarea,
            handler   = l,
            rects     = self.rects,
            dynamic   = has_dynamic_layout,
            wiboxes   = self.wiboxes,
        }

        elements.has_minimized = #elements.minimized > 0
        elements.max_y         = elements.workarea.y + elements.workarea.height
            - (elements.has_minimized and 40 or 0)
        elements.min_y         = elements.workarea.y + 40

        -- Get the rectangles
        get_areas_minimzed(elements)
        get_areas_static  (elements)
        get_areas_dynamic (elements)
        get_area_tag      (elements)
        --TODO add a rect for empty screens

--         debug_rects(s, elements)
    end

    return self
end

return setmetatable(module, { __call = function(_, ...) return get_areas(...) end })
