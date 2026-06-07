-- compat.lua
-- Inject this at the absolute top of main.lua: require("compat")

print("[COMPAT] Injecting LÖVE 0.7.2 -> 11.5 Compatibility Layer")

-- 1. Fix the 0-255 to 0.0-1.0 Color Shift
local oldSetColor = love.graphics.setColor
love.graphics.setColor = function(r, g, b, a)
    if type(r) == "table" then
        oldSetColor(r[1]/255, r[2]/255, r[3]/255, (r[4] or 255)/255)
    else
        oldSetColor(r/255, g/255, b/255, (a or 255)/255)
    end
end

local oldGetColor = love.graphics.getColor
love.graphics.getColor = function()
    local r, g, b, a = oldGetColor()
    return r*255, g*255, b*255, a*255
end

-- 2. Map old drawq to modern draw
love.graphics.drawq = love.graphics.draw

-- 3. Mock window mode lookups
love.graphics.getMode = function()
    return love.window.getMode()
end

-- 4. Key constant translation map
local keyMap = {
    kpenter = "return",
    escape = "escape",
    -- Add any other edge cases the agent discovers
}

local oldIsDown = love.keyboard.isDown
love.keyboard.isDown = function(key)
    return oldIsDown(keyMap[key] or key)
end
