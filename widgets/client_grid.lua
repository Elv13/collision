local wibox       = require("wibox")
local screenshot  = require("collision.widgets.screenshot")
local title_image = require("collision.widgets.titled_imagebox")

local module = {}

local function simple_widget(c)
    local ret = title_image(c.name, awesome.composite_manager_running
        and screenshot(c)
        and (c.icon and wibox.widget.imagebox(c.icon) or nil)
        or screenshot(c)
    )
    ret.client = c
    return ret
end

local function reload(self, g)
    -- Get the current widgets for each clients, make sure to add them back in
    -- the same order so "stable" layouts keep the same collision grid all the
    -- time
    --TODO somehow, the topmost element also need to be the first one...

    local clients, c_to_wdgs = {}, {}
    for _, w1 in ipairs(self.children) do
        for _, w2 in ipairs(w1.children) do
            if w2.client and w2.client.valid then
                table.insert(clients, w2.client)
                c_to_wdgs[w2.client] = w2
            end
        end
    end

    -- Clear all content
    self:reset()

    -- Get the optimal size
    local total = #g
    local row   = math.ceil(math.sqrt(total))
    local col   = math.ceil(total/row)

    -- Sort the group to prevent useless re-ordering
    local ordered = {}
    for _, elem in ipairs(g) do
        if not c_to_wdgs[elem.client] then
            table.insert(clients, elem.client)
        end
    end

    assert(#clients == total)

    -- Fill the grid
    local counter = 1
    for r=1, row do
        local rwdg = wibox.layout.flex.horizontal()
        for c=1, col do

            local wdg = c_to_wdgs[clients[counter]]
                or simple_widget(clients[counter])

            rwdg:add(wdg)
            counter = counter + 1

            if counter > total then break end
        end
        self:add(rwdg)
    end
end

local function new(group)
    local ret = wibox.layout.flex.vertical()
    rawset(ret, "reload", reload)

    ret:reload(group)

    return ret
end

return setmetatable(module, {__call = function(_, ...) return new(...) end})
