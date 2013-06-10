local capi = { client = client, mouse     = mouse      ,
               screen = screen, keygrabber = keygrabber}
local ipairs,print = ipairs,print
local wibox,color     = require( "wibox" )    , require( "gears.color" )
local cairo,beautiful = require( "lgi").cairo , require( "beautiful"   )
local module,indicators,cur_c = {},nil,nil

local values = {"top"     , "topright"  , "right" ,  "bottomright" ,
                "bottom"  , "bottomleft", "left"  ,  "topleft"     }

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
  cr:fill()
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
    w:connect_signal("mouse::leave",function() ib:set_image(arr_rot)       end)
    indicators[v] = w
  end
end

local placement_f = {
  left        = function(g) return {x = g.x             , y = g.y + g.height/2 } end,
  topleft     = function(g) return {x = g.x             , y = g.y              } end,
  bottomleft  = function(g) return {x = g.x             , y = g.y+g.height     } end,
  right       = function(g) return {x = g.x + g.width   , y = g.y+g.height/2   } end,
  topright    = function(g) return {x = g.x + g.width   , y = g.y              } end,
  bottomright = function(g) return {x = g.x + g.width   , y = g.y+g.height     } end,
  top         = function(g) return {x = g.x + g.width/2 , y = g.y              } end,
  bottom      = function(g) return {x = g.x + g.width/2 , y = g.y+g.height     } end,
}

local move_f = {
  left        = function(c)  end,
  topleft     = function(c)  end,
  bottomleft  = function(c)  end,
  right       = function(c)  end,
  topright    = function(c)  end,
  bottomright = function(c)  end,
  top         = function(c)  end,
  bottom      = function(c)  end,
}

module.display = function(c)
  c = c or capi.client.focus
  if not indicators then
    create_indicators()
  end
  for k,v in ipairs(values) do
    local w = indicators[v]
    local pos = placement_f[v](c:geometry())
    w.x = pos.x - 20
    w.y = pos.y - 20
  end
  if c ~= cur_c then
    if cur_c then
      cur_c:disconnect_signal("property::geometry", module.display)
    end
    c:connect_signal("property::geometry", module.display)
    cur_c = c
  end
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })
-- kate: space-indent on; indent-width 2; replace-tabs on;
