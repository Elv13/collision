local capi = { client = client , mouse = mouse, screen = screen }

local util         = require( "awful.util"     )
local client       = require( "awful.client"   )
local col_utils    = require( "collision.util" )
local grect        = require( "gears.geometry" ).rectangle
local placement    = require( "awful.placement")
local focus_arrow  = require( "collision.widgets.focus_arrow" )

local module = {}
local wiboxes,delta = nil,100
local edge = nil

local function init()
    wiboxes = {}

    for _,dir in ipairs({"up","right","down","left","center"}) do
        wiboxes[dir] = focus_arrow(dir)
    end
end

local function emulate_client(screen)
    return {is_screen = true, screen=screen, geometry=function() return capi.screen[screen].workarea end}
end

local function display_wiboxes(cltbl,geomtbl,swap,c)
    if not wiboxes then
        init()
    end

    local fc = capi.client.focus or emulate_client(capi.mouse.screen)

    for k,v in ipairs({"left","right","up","down","center"}) do
        local next_clients = swap and c
            or cltbl[grect.get_in_direction(v , geomtbl, fc:geometry())]

        if next_clients or k==5 then
            local parent = k==5 and fc or next_clients
            wiboxes[v].visible = true
            placement.centered(wiboxes[v], {parent = parent})
        else
            wiboxes[v].visible = false
        end

    end
end

---------------- Position -----------------------
local function float_move(dir,c)
    return ({
        left  = {x=c:geometry().x-delta},
        right = {x=c:geometry().x+delta},
        up    = {y=c:geometry().y-delta},
        down  = {y=c:geometry().y+delta},
    })[dir]
end

local function float_move_max(dir,c)
    local wa = capi.screen[c.screen].workarea
    return ({
        left  = {
            x= wa.x
        },
        right = {
            x=wa.width+wa.x-c:geometry().width
        },
        up    = {
            y=wa.y
        },
        down  = {
            y=wa.y+wa.height-c:geometry().height
        }
    })[dir]
end

local function floating_clients()
    local ret = {}
    for v in util.table.iterate(client.visible(),function(c) return c.floating end) do
        ret[#ret+1] = v
    end
    return ret
end

local function bydirection(dir, c, swap,max)
    if not c then
        c = emulate_client(capi.mouse.screen)
    end

  -- Move the client if floating, swaping wont work anyway
    if swap then
        c:geometry((max and float_move_max or float_move)(dir,c))
        display_wiboxes(nil,nil,swap,c)
    else

    if not edge then
        local scrs =col_utils.get_ordered_screens()
        local last_geo =capi.screen[scrs[#scrs]].geometry
        edge = last_geo.x + last_geo.width
    end

    -- Get all clients rectangle
    local cltbl,geomtbl,scrs,roundr,roundl = floating_clients(),{},{},{},{}
    for i,cl in ipairs(cltbl) do
        local geo = cl:geometry()
        geomtbl[i] = geo
        scrs[capi.screen[cl.screen or 1]] = true

        if geo.x == 0 then
            roundr[#roundr+1] = cl
        elseif geo.x + geo.width >= edge -2 then
            roundl[#roundl+1] = cl
        end

    end

    --Add first client at the end to be able to rotate selection
    for _,c in ipairs(roundr) do
        local geo = c:geometry()
        geomtbl[#geomtbl+1] = {x=edge,width=geo.width,y=geo.y,height=geo.height}
        cltbl[#geomtbl] = c
    end

    for _,c in ipairs(roundl) do
        local geo = c:geometry()
        geomtbl[#geomtbl+1] = {x=-geo.width,width=geo.width,y=geo.y,height=geo.height}
        cltbl[#geomtbl] = c
    end

    -- Add rectangles for empty screens too
    for i = 1, capi.screen.count() do
        if not scrs[capi.screen[i]] then
            geomtbl[#geomtbl+1] = capi.screen[i].workarea
            cltbl[#geomtbl] = emulate_client(i)
        end
    end

    local target = grect.get_in_direction(dir, geomtbl, c:geometry())
    if swap ~= true then
        -- If we found a client to focus, then do it.
        if target then
            local cl = cltbl[target]
            if cl and cl.is_screen then
                capi.client.focus = nil --TODO Fix upstream fix
                capi.mouse.screen = capi.screen[cl.screen]
            else
                local old_src = capi.client.focus and capi.client.focus.screen
                capi.client.focus = cltbl[((not cl and #cltbl == 1) and 1 or target)]
                capi.client.focus:raise()
                if old_src and capi.client.focus.screen ~= capi.screen[old_src] then
                    capi.mouse.coords(capi.client.focus:geometry())
                end
            end
        end
    else
      if target then
        -- We found a client to swap
        local other = cltbl[((not cltbl[target] and #cltbl == 1) and 1 or target)]
        if capi.screen[other.screen] == capi.screen[c.screen] or col_utils.settings.swap_across_screen then
          --BUG swap doesn't work if the screen is not the same
          c:swap(other)
        else
          local t  = capi.screen[other.screen].selected_tag --TODO get index
          c.screen = capi.screen[ other.screen]
          c:tags({t})
        end

        -- Geometries have changed by swapping, so refresh.
        cltbl,geomtbl = floating_clients(),{}
        for i,cl in ipairs(cltbl) do
          geomtbl[i] = cl:geometry()
        end
      else

        -- No client to swap, try to find a screen.
        local screen_geom = {}
        for i = 1, capi.screen.count() do
          screen_geom[i] = capi.screen[i].workarea
        end
        target = grect.get_in_direction(dir, screen_geom, c:geometry())
        if target and target ~= c.screen then
          local t = target.selected_tag
          c.screen = target
          c:tags({t})
          c:raise()
        end

      end

    end
    display_wiboxes(cltbl,geomtbl,swap,c)
  end
end

function module.global_bydirection(dir, c,swap,max)
    bydirection(dir, c or capi.client.focus, swap,max)
end

function module._global_bydirection_key(mod,key,event,direction,is_swap,is_max)
    bydirection(direction,capi.client.focus,is_swap,is_max)

    return true
end

function module.display(mod,key,event,direction,is_swap,is_max)
    local c = capi.client.focus
    local cltbl,geomtbl = floating_clients(),{}
    for i,cl in ipairs(cltbl) do
        geomtbl[i] = cl:geometry()
    end

    -- Sometime, there is no focussed clients
    if not c then
        c = geomtbl[1] or cltbl[1]
    end

    -- If there is still no accessible clients, there is nothing to display
    if not c then return end

    display_wiboxes(cltbl,geomtbl,is_swap,c)
end

function module._quit()
    if not wiboxes then return end

    for _,v in ipairs({"left","right","up","down","center"}) do
        wiboxes[v].visible = false
    end
end

return module
-- kate: space-indent on; indent-width 4; replace-tabs on;
