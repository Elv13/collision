local wibox = require("wibox")
local surface = require("gears.surface")
local shape = require("gears.shape")

local module = {}

local function fit(self, context, width,height)
    local size = math.min(width, height)

    return size, size
end

local function draw(self, content, cr, width, height)
    local c = self._private.client[1]
    local s = surface(c.content)

    local geo = c:geometry()

    local scale = math.min(width/geo.width, height/geo.height)

    local w, h = geo.width*scale, geo.height*scale

    local dx, dy = (width-w)/2, (height-h)/2

    cr:translate(dx, dy)

    shape.rounded_rect(cr, w, h)
    cr:clip()

    cr:scale(scale, scale)

    cr:set_source_surface(s)
    cr:paint()
end

local function new(c)
    local ret = wibox.widget.base.make_widget(nil, nil, {
        enable_properties = true,
    })

    rawset(ret, "fit" , fit )
    rawset(ret, "draw", draw)

    ret._private.client = setmetatable({c},{__mode="v"})

    return ret
end

return setmetatable(module, {__call=function(_,...) return new(...) end})
