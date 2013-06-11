local capi = { client = client, mouse     = mouse      ,
               screen = screen, keygrabber = keygrabber}
local ipairs,print    = ipairs,print
local wibox,color     = require( "wibox" )    , require( "gears.color" )
local cairo,beautiful = require( "lgi").cairo , require( "beautiful"   )
local awful           = require("awful")
local module,indicators,cur_c = {},nil,nil

local values = {"top"     , "top_right"  , "right" ,  "bottom_right" ,
                "bottom"  , "bottom_left", "left"  ,  "top_left"     }

module.create_arrow = function(width, height,margin,bg_color,fg_color)
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
  local arr            = module.create_arrow( 20, 20, 10, beautiful.bg_alternate,beautiful.fg_normal )
  local arr_focus      = module.create_arrow( 20, 20, 10, beautiful.fg_normal,beautiful.bg_normal    )
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
    w:connect_signal("mouse::leave",function() ib:set_image(arr_rot)       end)
    ib:buttons( awful.util.table.join(
      awful.button({ }, 1, function(geometry)
        ib:set_image(arr_rot)
        awful.mouse.client.resize(cur_c,v,function(c) module.display(c,true) end)
    end)))
    indicators[v] = w
  end
end

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

module.display = function(c,toggle)
  c = c or capi.client.focus
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
    for k,v in ipairs(values) do indicators[v].visible = false end
    cur_c:disconnect_signal("property::geometry", module.display)
    cur_c = nil
    return
  end
  for k,v in ipairs(values) do
    local w,pos   = indicators[v],placement_f[v](c:geometry())
    w.x,w.y,w.visible       = pos.x - 20,pos.y - 20,true
  end
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })
-- kate: space-indent on; indent-width 2; replace-tabs on;
