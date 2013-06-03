
local capi =
{
    client = client,
    mouse = mouse,
    screen = screen,
}

local setmetatable = setmetatable
local print = print
local ipairs = ipairs
local util = require("awful.util")
local client = require("awful.client")
local screen = require("awful.screen")
local wibox = require("wibox")
local cairo = require("lgi").cairo
local beautiful    = require( "beautiful"    )
local color = require("gears.color")

local module = {}

local wiboxes = nil

local function gen(item_height)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, item_height,item_height)
  local cr = cairo.Context(img)
  local rad = 10
  cr:set_source_rgba(0,0,0,0)
  cr:paint()
  cr:set_source_rgba(1,1,1,1)
  cr:arc(rad,rad,rad,0,2*math.pi)
  cr:arc(item_height-rad,rad,rad,0,2*math.pi)
  cr:arc(rad,item_height-rad,rad,0,2*math.pi)
  cr:arc(item_height-rad,item_height-rad,rad,0,2*math.pi)
  cr:fill()
  cr:rectangle(0,rad, item_height, item_height-2*rad)
  cr:rectangle(rad,0, item_height-2*rad, item_height)
  cr:fill()
  return img._native
end

local constructor = {
 up = function (width, height)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
    local cr = cairo.Context(img)
    cr:move_to(0,0)
    cr:set_source(color(beautiful.fg_normal))
    cr:paint()
    cr:set_source(color(beautiful.bg_normal))
    cr:set_antialias(1)
    cr:rectangle(0, (width/2), 10, (width/2))
    cr:rectangle(width-10, (width/2), 10, (width/2))
    for i=0,(width/2) do
        cr:rectangle(i, 0, 1, (width/2)-i)
        cr:rectangle(width-i, 0, 1, (width/2)-i)
    end
    cr:fill()
    return img
end,

 down = function (width, height)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
    local cr = cairo.Context(img)
    cr:set_source(color(beautiful.fg_normal))
    cr:paint()
    cr:set_source(color(beautiful.bg_normal))
    cr:set_antialias(1)
    cr:rectangle(0, 0, 10, (width/2))
    cr:rectangle(width-10, 0, 10, (width/2))
    for i=0,(width/2) do
        cr:rectangle((width/2)+i, height-i, 1, i)
        cr:rectangle((width/2)-i, height-i, 1, i)
    end
    cr:fill()
    return img
end,

 right = function (width, height)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
    local cr = cairo.Context(img)
    cr:set_source(color(beautiful.fg_normal))
    cr:paint()
    cr:set_source(color(beautiful.bg_normal))
    cr:set_antialias(1)
    cr:rectangle(0, 0, (width/2), 10)
    cr:rectangle(0, height-10, (width/2), 10)
    for i=0,(width/2) do
        cr:rectangle(width-i, (width/2)+i, i, 1)
        cr:rectangle(width-i, (width/2)-i, i, 1)
    end
    cr:fill()
    return img
end,

 left = function (width, height)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
    local cr = cairo.Context(img)
    cr:set_source(color(beautiful.fg_normal))
    cr:paint()
    cr:set_source(color(beautiful.bg_normal))
    cr:set_antialias(1)
    cr:rectangle((width/2), 0, (width/2), 10)
    cr:rectangle((width/2), height-10, (width/2), 10)
    for i=0,(width/2) do
        cr:rectangle(0, i, (width/2)-i, 1)
        cr:rectangle(0, (width/2)+i, i, 1)
    end
    cr:fill()
    return img
end
}

function module.bydirection(dir, c)
    local sel = c or capi.client.focus
    if sel then
        local cltbl = client.visible(sel.screen)
        local geomtbl = {}
        for i,cl in ipairs(cltbl) do
            geomtbl[i] = cl:geometry()
        end

        local target = util.get_rectangle_in_direction(dir, geomtbl, sel:geometry())

        -- If we found a client to focus, then do it.
        if target then
            capi.client.focus = cltbl[target]
            capi.client.focus:raise()
        end

        local next_clients = {
            left  =  cltbl[util.get_rectangle_in_direction("left" , geomtbl, capi.client.focus:geometry())],
            right =  cltbl[util.get_rectangle_in_direction("right", geomtbl, capi.client.focus:geometry())],
            up    =  cltbl[util.get_rectangle_in_direction("up"   , geomtbl, capi.client.focus:geometry())],
            down  =  cltbl[util.get_rectangle_in_direction("down" , geomtbl, capi.client.focus:geometry())],
        }

        if not wiboxes then
            local bounding = gen(75)
            wiboxes = {}
            for k,v in ipairs({"left","right","up","down"}) do
                wiboxes[v] = wibox({})
                wiboxes[v].height = 75
                wiboxes[v].width  = 75
                wiboxes[v].ontop  = true
                local ib = wibox.widget.imagebox()
                ib:set_image(constructor[v](55,55))
                local m = wibox.layout.margin(arrow)
                m:set_margins(10)
                m:set_widget(ib)
                wiboxes[v]:set_widget(m)
                wiboxes[v].shape_bounding = bounding
            end
        end
        for k,v in ipairs({"left","right","up","down"}) do
            if next_clients[v] then
                local geo = next_clients[v]:geometry()
                wiboxes[v].visible = true
                wiboxes[v].x = geo.x + geo.width/2 - 75/2
                wiboxes[v].y = geo.y + geo.height/2 - 75/2
            else
                wiboxes[v].visible = false
            end
        end
    end
end

function module.global_bydirection(dir, c)
    local sel = c or capi.client.focus
    local scr = capi.mouse.screen
    if sel then
        scr = sel.screen
    end

    -- change focus inside the screen
    module.bydirection(dir, sel)

    -- if focus not changed, we must change screen
    if sel == capi.client.focus then
        screen.focus_bydirection(dir, scr)
        if scr ~= capi.mouse.screen then
            local cltbl = client.visible(capi.mouse.screen)
            local geomtbl = {}
            for i,cl in ipairs(cltbl) do
                geomtbl[i] = cl:geometry()
            end
            local target = util.get_rectangle_in_direction(dir, geomtbl, capi.screen[scr].geometry)

            if target then
                capi.client.focus = cltbl[target]
                capi.client.focus:raise()
            end
        end
    end
end
return setmetatable(module, { __call = function(_, ...) return new(...) end })