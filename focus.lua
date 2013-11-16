local capi = { client = client , mouse      = mouse     ,
               screen = screen , keygrabber = keygrabber,}

local setmetatable = setmetatable
local ipairs       = ipairs
local util         = require( "awful.util"   )
local client       = require( "awful.client" )
local screen       = require( "awful.screen" )
local wibox        = require( "wibox"        )
local cairo        = require( "lgi"          ).cairo
local beautiful    = require( "beautiful"    )
local color        = require( "gears.color"  )

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

local function constructor(width)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width, width)
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
    return cairo.Pattern.create_for_surface(img)
end

local function init()
    local bounding,arrow = gen(75),constructor(55)
    wiboxes = {}
    for k,v in ipairs({"up","right","down","left","center"}) do
        wiboxes[v] = wibox({})
        wiboxes[v].height = 75
        wiboxes[v].width  = 75
        wiboxes[v].ontop  = true
        if v ~= "center" then
            local ib,m = wibox.widget.imagebox(),wibox.layout.margin()
            local img = cairo.ImageSurface(cairo.Format.ARGB32, 55, 55)
            local cr = cairo.Context(img)
            cr:translate(55/2,55/2)
            cr:rotate((k-1)*(2*math.pi)/4)
            cr:translate(-(55/2),-(55/2))
            cr:set_source(arrow)
            cr:paint()
            ib:set_image(img)
            m:set_margins(10)
            m:set_widget(ib)
            wiboxes[v]:set_widget(m)
            wiboxes[v].shape_bounding = bounding
        end
    end
    wiboxes["center"]:set_bg(beautiful.bg_urgent)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, 75,75)
    local cr = cairo.Context(img)
    cr:set_source_rgba(0,0,0,0)
    cr:paint()
    cr:set_source_rgba(1,1,1,1)
    cr:arc( 75/2,75/2,75/2,0,2*math.pi  )
    cr:fill()
    wiboxes["center"].shape_bounding = img._native
end

function module.bydirection(dir, c, swap)
    local sel = c or capi.client.focus
    if sel then
        local cltbl,geomtbl = client.visible(sel.screen),{}
        for i,cl in ipairs(cltbl) do
            geomtbl[i] = cl:geometry()
        end

        local target = util.get_rectangle_in_direction(dir, geomtbl, sel:geometry())

        -- If we found a client to focus, then do it.
        if target then
            if swap ~= true then
               capi.client.focus = cltbl[target]
               capi.client.focus:raise()
            else
               c:swap(cltbl[target])
            end
        end

        if not wiboxes then
            init()
        end
        for k,v in ipairs({"left","right","up","down","center"}) do
            local next_clients = cltbl[util.get_rectangle_in_direction(v , geomtbl, capi.client.focus:geometry())]
            if next_clients or v == "center" then
                local geo = v == "center" and capi.client.focus:geometry() or next_clients:geometry()
                wiboxes[v].visible = true
                wiboxes[v].x = geo.x + geo.width/2 - 75/2
                wiboxes[v].y = geo.y + geo.height/2 - 75/2
            else
                wiboxes[v].visible = false
            end
        end
    end
end

local function global_bydirection_real(dir, c, swap)
    local sel = c or capi.client.focus
    local scr = capi.mouse.screen
    if sel then
        scr = sel.screen
    end

    -- change focus inside the screen
    module.bydirection(dir, sel,swap)

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
               if swap ~= true then
                capi.client.focus = cltbl[target]
                capi.client.focus:raise()
               else
                  c:swap(cltbl[target])
               end
            end
        end
    end
end

function module.global_bydirection(dir, c,swap)
    global_bydirection_real(dir, c, swap)
    capi.keygrabber.run(function(mod, key, event)
        local is_swap = mod[1] == "Shift" or mod[2] == "Shift"
        if key == "Up" or key == "&" or key == "XF86AudioPause" or key == "F15" then
            if event == "press" then
                global_bydirection_real("up",nil,is_swap)
            end
            return true
        elseif key == "Down" or key == "KP_Enter" or key == "XF86WebCam" or key == "F14"  then
            if event == "press" then
                global_bydirection_real("down",nil,is_swap)
            end
            return true
        elseif key == "Left" or key == "#"  or key == "Cancel" or key == "F13" then
            if event == "press" then
                global_bydirection_real("left",nil,is_swap)
            end
            return true
        elseif key == "Right" or key == "\""or key == "XF86Paste" or key == "F17" then
            if event == "press" then
                global_bydirection_real("right",nil,is_swap)
            end
            return true
        elseif key == "Shift_L" or key == "Shift_R" then
           return true
        end

        for k,v in ipairs({"left","right","up","down","center"}) do
            wiboxes[v].visible = false
        end
        capi.keygrabber.stop()
        return false
    end)
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })