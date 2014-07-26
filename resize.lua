local capi = { client = client, mouse=mouse,mousegrabber=mousegrabber }
local ipairs,print    = ipairs,print
local wibox,color     = require( "wibox" )    , require( "gears.color" )
local cairo,beautiful = require( "lgi").cairo , require( "beautiful"   )
local awful           = require("awful")
local module,indicators,cur_c,auto_hide = {},nil,nil

local values = {"top"     , "top_right"  , "right" ,  "bottom_right" ,
                "bottom"  , "bottom_left", "left"  ,  "top_left"     }

local function create_arrow(width, height,margin,bg_color,fg_color)
    local img = cairo.ImageSurface(cairo.Format.ARGB32, width+2*margin, height+2*margin)
    local cr = cairo.Context(img)
    cr:set_source(color(bg_color))
    cr:paint()
    cr:set_source(color(fg_color))
    cr:set_antialias(1)
    cr:rectangle((margin*2+width)/2-(width/8), (width/2)+margin, width/4, height-margin)
    for i=0,(width/2) do
        cr:rectangle(margin+i, (width/2)+margin-i, width-i*2, 1)
    end
    cr:fill()
    return cairo.Pattern.create_for_surface(img)
end

local function gen_shape_bounding(radius)
  local img  = cairo.ImageSurface(cairo.Format.ARGB32, radius,radius)
  local cr   = cairo.Context(img)
  cr:set_source_rgba(0,0,0,0                                  )
  cr:paint          (                                         )
  cr:set_source_rgba(1,1,1,1                                  )
  cr:arc            ( radius/2,radius/2,radius/2,0,2*math.pi  )
  cr:fill           (                                         )
  return img._native
end

local function create_indicators()
  indicators           = {}
  local arr            = create_arrow( 20, 20, 10, beautiful.bg_alternate,beautiful.fg_normal )
  local arr_focus      = create_arrow( 20, 20, 10, beautiful.fg_normal,beautiful.bg_normal    )
  local angle          = 0
  local shape_bounding = gen_shape_bounding(40)
  for k,v in ipairs(values) do
    local w = wibox({width=40,height=40,ontop=true,visible= true})
    local ib = wibox.widget.imagebox()
    local arr_rot,arr_rot_focus = cairo.ImageSurface(cairo.Format.ARGB32, 40, 40),cairo.ImageSurface(cairo.Format.ARGB32, 40, 40)
    for k2,v2 in ipairs({arr_rot,arr_rot_focus}) do
      local cr2= cairo.Context(v2)
      cr2:translate(20,20)
      cr2:rotate(angle)
      cr2:translate(-20,-20)
      cr2:set_source(v2 == arr_rot and arr or arr_focus)
      cr2:paint()
    end
    ib:set_image(arr_rot)
    angle = angle + (2*math.pi)/8
    w:set_widget(ib)
    w.shape_bounding = shape_bounding
    w:set_bg(beautiful.bg_alternate)
    w:connect_signal("mouse::enter",function() ib:set_image(arr_rot_focus) end)
    w:connect_signal("mouse::leave",function()
      ib:set_image(arr_rot)
      if auto_hide then
        module.hide()
        auto_hide = false
      end
    end)
    ib:buttons( awful.util.table.join(
      awful.button({ }, 1, function(geometry)
        ib:set_image(arr_rot)
        awful.mouse.client.resize(cur_c,v,function(c) module.display(c,true) end)
    end)))
    indicators[v] = w
  end
end

-- Resize using the mouse
local placement_f = {
  left         = function(g) return {x = g.x             , y = g.y + g.height/2 } end,
  top_left     = function(g) return {x = g.x             , y = g.y              } end,
  bottom_left  = function(g) return {x = g.x             , y = g.y+g.height     } end,
  right        = function(g) return {x = g.x + g.width   , y = g.y+g.height/2   } end,
  top_right    = function(g) return {x = g.x + g.width   , y = g.y              } end,
  bottom_right = function(g) return {x = g.x + g.width   , y = g.y+g.height     } end,
  top          = function(g) return {x = g.x + g.width/2 , y = g.y              } end,
  bottom       = function(g) return {x = g.x + g.width/2 , y = g.y+g.height     } end,
}

-- Resize floating using the keyboard
local r_orientation = { right = "width", left  = "width", up    = "height", down  = "height" }
local r_direction   = { right = "x"    , left  = "x"    , up    = "y"     , down  = "y"      }
local r_sign        = { right = 1      , left  = -1     , up    = -1      , down  = 1        }

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

function module.hide()
  for k,v in ipairs(values) do indicators[v].visible = false end
    cur_c:disconnect_signal("property::geometry", module.display)
    cur_c = nil
    return
end

function module.display(c,toggle)
  local c = c or capi.client.focus
  if not indicators then
    create_indicators()
  end
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
    local w,pos   = indicators[v],placement_f[v](c:geometry())
    w.x,w.y,w.visible       = pos.x - 20,pos.y - 20,true
  end
end

function module.resize(mod,key,event,direction,is_swap,is_max)
  local c = capi.client.focus
  if not c then return true end
  local lay = awful.layout.get(c.screen)
  if awful.client.floating.get(c) or lay == awful.layout.suit.floating then
    local new_geo = c:geometry()
    new_geo[r_orientation[direction]]  = new_geo[r_orientation[direction]] + r_sign[direction]*100*(is_swap and -1 or 1)
    if is_swap then
      new_geo[r_direction[direction]]  = new_geo[r_direction[direction]]   + r_sign[direction]*100
    end
    c:geometry(new_geo)
  elseif layouts_all[lay] then
    local ret = layouts_all[lay][direction]
    if ret.mwfact then
      awful.tag.incmwfact(ret.mwfact)
    end
    if ret.wfact then
      awful.client.incwfact(ret.wfact,c)
    end
  end
  return true
end

-- Resize from the top left corner
function module.mouse_resize(c,btn)
  module.display(c)
  local geom,curX,curY = c:geometry(),capi.mouse.coords().x,capi.mouse.coords().y
  capi.mousegrabber.run(function(mouse)
    if mouse.buttons[1] == false then
      module.hide()
      return false
    elseif mouse.x ~= curX and mouse.y ~= curY then
        c:geometry({x=geom.x+(mouse.x-curX),y=geom.y+(mouse.y-curY),width=geom.width-(mouse.x-curX),height=geom.height-(mouse.y-curY)})
    end
    return true
  end,"fleur")
end

-- awful.mouse.client._resize = awful.mouse.client.resize
-- awful.mouse.client.resize = function(c,...)
--   module.display(c)
--   auto_hide = true
--   awful.mouse.client._resize(c,...)
--   module.hide()
-- end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;
