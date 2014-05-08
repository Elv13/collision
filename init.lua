local capi = { client = client, mouse     = mouse      ,
               screen = screen, keygrabber = keygrabber}
local module = {
    _focus  = require( "customIndicator.focus" ),
    _resize = require( "customIndicator.resize")
}

local current_mode = "focus"

local backkbacks = {
    focus = module._focus._global_bydirection_key,
    swap  = module._focus._global_bydirection_key
}

-- Event loop
local function start_loop()
    capi.keygrabber.run(function(mod, key, event)
        return backkbacks[current_mode](mod,key,event)
    end)
end

function module.focus(direction,c)
    module._focus.global_bydirection(direction,c,true)
end

function module.move(direction,c)
    module._focus.global_bydirection(direction,c,false)
end

return module