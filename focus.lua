local capi = { client = client , mouse      = mouse     ,
               screen = screen , keygrabber = keygrabber,}

local ipairs       = ipairs
local grect        = require( "gears.geometry" ).rectangle
local placement    = require( "awful.placement")
local areamap      = require( "collision.areamap" )
local focus_arrow  = require( "collision.widgets.focus_arrow" )
local gtable = require("gears.table")


local module = {}
local wiboxes = nil

local target_client = nil
local current_map = nil

---------------- Visual -----------------------
local function init()
    wiboxes = {}

    for _,dir in ipairs({"up","right","down","left","center"}) do
        wiboxes[dir] = focus_arrow(dir)
    end
end

local function emulate_client(screen)
  return {is_screen = true, screen=screen, geometry=function() return capi.screen[screen].workarea end}
end

local function display_wiboxes(cltbl)
    if not wiboxes then
        init()
    end

    local fc = target_client-- or emulate_client(capi.mouse.screen)

    if not fc then return end

    for k,v in ipairs({"left","right","up","down","center"}) do

        local next_clients = cltbl[grect.get_in_direction(v , cltbl, fc)]

        if next_clients or k==5 then
            local parent = k==5 and fc or next_clients
            wiboxes[v].visible = true
            placement.centered(wiboxes[v], {parent = parent})
        else
            wiboxes[v].visible = false
        end

    end
end


local function bydirection(dir, c, swap, max)
    if not c then
        c = emulate_client(capi.mouse.screen)
    end

    -- Get all clients rectangle
    local cltbl = current_map and current_map.rects or nil

    if not cltbl then
        current_map = areamap()
        cltbl = current_map.rects
    end

    --TODO add wrapping elements

    local target = grect.get_in_direction(dir, cltbl, c)

    -- If we found a client to focus, then do it.
    if target then
        local cl = cltbl[target]
        if cl and cl.is_screen then
            target_client = nil
            capi.mouse.screen = capi.screen[cl.screen]
        else
            local prev = target_client

            target_client = cltbl[((not cl and #cltbl == 1) and 1 or target)]

            --FIXME when prev isn't set, it doesn't work
            if prev and swap and target_client.on_swap then
                target_client.on_swap(prev)
            elseif target_client.on_select then
                target_client.on_select()
            end
        end
    end
    display_wiboxes(cltbl)

end

function module.global_bydirection(dir, c,swap,max)
    bydirection(dir, c or target_client or capi.client.focus, swap,max)
end

function module._global_bydirection_key(mod,key,event,direction,is_swap,is_max)
    bydirection(direction,target_client or capi.client.focus,is_swap,is_max)

    return true
end

function module.display(mod,key,event,direction,is_swap,is_max)
-- --     local c = capi.client.focus
-- --     local cltbl = max and floating_clients() or client.tiled()
-- -- 
-- --     -- Sometime, there is no focussed clients
-- --     c = c or cltbl[1]
-- -- 
-- --     -- If there is still no accessible clients, there is nothing to display
-- --     if not c then return end
-- -- 
-- --     display_wiboxes(cltbl)
end

function module._quit()
    if not wiboxes then return end

    for _,v in ipairs({"left","right","up","down","center"}) do
        wiboxes[v].visible = false
    end

    if target_client then
        if target_client.on_exit then
            target_client.on_exit()
        end

        target_client = nil
        current_map:hide()
        current_map = nil
    end

end

return module
-- kate: space-indent on; indent-width 4; replace-tabs on;
