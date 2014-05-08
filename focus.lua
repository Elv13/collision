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
local wiboxes,delta = nil,60
local float_move = {left={-delta,0},right={delta,0},up={0,-delta},down={0,delta}}

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
        local cltbl,geomtbl,float = client.visible(--[[sel.screen]]),{},client.floating.get(c)
        for i,cl in ipairs(cltbl) do
            geomtbl[i] = cl:geometry()
        end

        local target = util.get_rectangle_in_direction(dir, geomtbl, sel:geometry())

        -- Move the client if floating, swaping wont work anyway
        if swap and float then
            sel:geometry({x=sel:geometry().x+float_move[dir][1],y=sel:geometry().y+float_move[dir][2]})
        -- If we found a client to focus, then do it.
        elseif target then
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
            local next_clients = (not (float and swap)) and cltbl[util.get_rectangle_in_direction(v , geomtbl, capi.client.focus:geometry())] or sel
            if next_clients or k==5 then
                local same, center = capi.client.focus == next_clients,k==5
                local geo = center and capi.client.focus:geometry() or next_clients:geometry()
                wiboxes[v].visible = true
                wiboxes[v].x = (swap and float and (not center)) and (geo.x + (k>2 and (geo.width/2) or 0) + (k==2 and geo.width or 0) - 75/2) or (geo.x + geo.width/2 - 75/2)
                wiboxes[v].y = (swap and float and (not center)) and (geo.y + (k<=2 and geo.height/2 or 0) + (k==4 and geo.height or 0) - 75/2) or (geo.y + geo.height/2 - 75/2)
            else
                wiboxes[v].visible = false
            end
        end
    end
end

function module._global_bydirection_real(dir, c, swap)
    local sel = c or capi.client.focus
    local scr = sel and sel.screen or capi.mouse.screen

    -- change focus inside the screen
    module.bydirection(dir, sel,swap)

    -- if focus not changed, we must change screen
    if sel == capi.client.focus and not swap then
        screen.focus_bydirection(dir, scr)
        if scr ~= capi.mouse.screen then
            local cltbl = client.visible(--[[capi.mouse.screen]])
            local geomtbl = {}
            for i,cl in ipairs(cltbl) do
                geomtbl[i] = cl:geometry()
            end
            local target = util.get_rectangle_in_direction(dir, geomtbl, capi.screen[scr].geometry)

            if target then
               if swap ~= true then
                capi.client.focus = cltbl[target]
                capi.client.focus:raise()
               elseif sel then
                  sel:swap(cltbl[target])
               end
            end
        end
    end
end

local keys = {--Normal  Xephyr        G510 alt         G510
    up    = {"Up"    , "&"        , "XF86AudioPause" , "F15" },
    down  = {"Down"  , "KP_Enter" , "XF86WebCam"     , "F14" },
    left  = {"Left"  , "#"        , "Cancel"         , "F13" },
    right = {"Right" , "\""       , "XF86Paste"      , "F17" }
}

function module.global_bydirection(dir, c,swap)
    module._global_bydirection_real(dir, c, swap)
end

function module._global_bydirection_key(mod,key,event)
    local is_swap = not util.table.hasitem(mod,"Shift")
    print("IS",is_swap)

    for k,v in pairs(keys) do
        if util.table.hasitem(v,key) then
            if event == "press" then
                module._global_bydirection_real(k,nil,is_swap)
            end
            return true
        end
    end

    if key == "Shift_L" or key == "Shift_R" then
        return true
    end

    for k,v in ipairs({"left","right","up","down","center"}) do
        wiboxes[v].visible = false
    end
    capi.keygrabber.stop()
    return false
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })