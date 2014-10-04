local capi = {screen=screen,client=client}
local wibox = require("wibox")
local awful = require("awful")
local cairo        = require( "lgi"          ).cairo
local color        = require( "gears.color"  )
local beautiful    = require( "beautiful"    )
local surface      = require( "gears.surface" )
local pango = require("lgi").Pango
local pangocairo = require("lgi").PangoCairo
local module = {}

function module.display()
  print("DISPLAT")
end

function module.hide()
  print("HIDE")
end

function module.reload()
  print("RELOAD")
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;