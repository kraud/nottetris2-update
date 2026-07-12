function gameBdebug_load()
    gamestate = "gameBdebug"

    pause = false

    difficulty_speed = 100

    scorescore = 0
    levelscore = 0
    linesscore = 0
    nextpiecerot = 0

    panel_height = 90
    params = debug_params or {
        difficulty_speed   = 100,
        lateral_force      = 2000,
        rotation_torque    = 5000,
        angular_cap        = 12,
        soft_drop_force    = 2000,
        soft_drop_cap_mul  = 5,
        air_brake_coeff    = 2000,
        step               = 100,
    }
    panel_focus = nil
    panel_editing = ""
    panel_rows = {
        { "difficulty_speed",   "difficulty" },
        { "lateral_force",      "lateral" },
        { "rotation_torque",    "rot torque" },
        { "angular_cap",        "rot cap" },
        { "soft_drop_force",    "soft drop" },
        { "soft_drop_cap_mul",  "soft cap" },
        { "air_brake_coeff",    "air brake" },
        { "step",               "step" },
    }
    predebugscale = scale

    --PHYSICS--
    meter = 30
    world = love.physics.newWorld(0, 500, true)

    tetrikind = {}

    wallshapes = {}

    tetrifixtures = {}
    tetribodies = {}
    tetrishapes = {}

    offsetshapes = {}

    wallfixtures = {}

    wallbodies = love.physics.newBody(world, 32, -64, "static") --WALLS
    wallshapes[0] = love.physics.newPolygonShape(0, -64, 0, 672, 32, 672, 32, -64)
    wallshapes[1] = love.physics.newPolygonShape(352, -64, 352, 672, 384, 672, 384, -64)
    wallshapes[2] = love.physics.newPolygonShape(24, 640, 24, 672, 352, 672, 352, 640)
    wallshapes[3] = love.physics.newPolygonShape(-8, -96, 384, -96, 384, -64, -8, -64)

    wallfixtures[0] = love.physics.newFixture(wallbodies, wallshapes[0])
    wallfixtures[0]:setUserData("left")
    wallfixtures[0]:setFriction(0.00001)

    wallfixtures[1] = love.physics.newFixture(wallbodies, wallshapes[1])
    wallfixtures[1]:setUserData("right")
    wallfixtures[1]:setFriction(0.00001)

    wallfixtures[2] = love.physics.newFixture(wallbodies, wallshapes[2])
    wallfixtures[2]:setUserData("ground")

    wallfixtures[3] = love.physics.newFixture(wallbodies, wallshapes[3])
    wallfixtures[3]:setUserData("ceiling")

    world:setCallbacks(collideBdebug)
    -----------

    --FIRST "nextpiece"-
    nextpiece = 1 --math.random(7)

    gameBdebug_addTetri()
    ----------------
end

function gameBdebug_addTetri()
    --NEW BLOCK--
    randomblock = nextpiece
    createtetriBdebug(randomblock, 1, 224, blockstartY)
    tetribodies[1]:setLinearVelocity(0, params.difficulty_speed)

    --RANDOMIZE
    nextpiece = math.random(7)
end

function createtetriBdebug(i, uniqueid, x, y)
    tetriimages[uniqueid] = newPaddedImage("graphics/pieces/" .. i .. ".png", scale)
    tetrikind[uniqueid] = i
    tetrifixtures[uniqueid] = {}
    tetrishapes[uniqueid] = {}

    if i == 1 then --I
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")

        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-48, 0, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(-16, 0, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(16, 0, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(48, 0, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 2 then --J
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-32, -16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(0, -16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(32, -16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(32, 16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 3 then --L
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-32, -16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(0, -16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(32, -16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(-32, 16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 4 then --O
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-16, -16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(-16, 16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(16, 16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(16, -16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 5 then --S
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-32, 16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(0, -16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(32, -16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(0, 16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 6 then --T
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(-32, -16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(0, -16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(32, -16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(0, 16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    elseif i == 7 then --Z
        tetribodies[uniqueid] = love.physics.newBody(world, x, y, "dynamic")
        tetrishapes[uniqueid][1] = love.physics.newRectangleShape(0, 16, 32, 32)
        tetrishapes[uniqueid][2] = love.physics.newRectangleShape(0, -16, 32, 32)
        tetrishapes[uniqueid][3] = love.physics.newRectangleShape(32, 16, 32, 32)
        tetrishapes[uniqueid][4] = love.physics.newRectangleShape(-32, -16, 32, 32)

        tetrifixtures[uniqueid][1] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][1], density)
        tetrifixtures[uniqueid][2] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][2], density)
        tetrifixtures[uniqueid][3] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][3], density)
        tetrifixtures[uniqueid][4] = love.physics.newFixture(tetribodies[uniqueid], tetrishapes[uniqueid][4], density)
    end

    tetribodies[uniqueid]:setLinearDamping(0.5)
    tetribodies[uniqueid]:setBullet(true)

    for i, v in pairs(tetrifixtures[uniqueid]) do
        v:setUserData(uniqueid)
    end
end

function gameBdebug_draw()
    --FULLSCREEN OFFSET
    if fullscreen then
        love.graphics.translate(fullscreenoffsetX, fullscreenoffsetY)

        --scissor
        love.graphics.setScissor(fullscreenoffsetX, fullscreenoffsetY, 160 * scale, 144 * scale)
    end

    --background--
    love.graphics.draw(gamebackground, 0, 0, 0, scale)
    ---------------
    --tetrifixtures--
    for i, v in pairs(tetribodies) do
        if pause == false then
            love.graphics.draw(tetriimages[i], v:getX() * physicsscale, v:getY() * physicsscale, v:getAngle(), 1, 1,
                piececenter[tetrikind[i]][1] * scale, piececenter[tetrikind[i]][2] * scale)
        end
    end

    --Next piece
    if pause == false then
        love.graphics.draw(nextpieceimg[nextpiece], 136 * scale, 120 * scale, nextpiecerot, 1, 1,
            piececenterpreview[nextpiece][1] * scale, piececenterpreview[nextpiece][2] * scale)
    end
    ----------------
    --start--
    if pause == true then
        love.graphics.draw(pausegraphic, 16 * scale, 0, 0, scale)
    end
    ---------

    --SCORES---------------------------------------
    --"score"--
    offsetX = 0

    scorestring = tostring(scorescore)
    for i = 1, scorestring:len() - 1 do
        offsetX = offsetX - 8 * scale
    end
    love.graphics.print(scorescore, 144 * scale + offsetX, 24 * scale, 0, scale)


    --"level"--
    offsetX = 0

    scorestring = tostring(levelscore)
    for i = 1, scorestring:len() - 1 do
        offsetX = offsetX - 8 * scale
    end
    love.graphics.print(levelscore, 136 * scale + offsetX, 56 * scale, 0, scale)

    --"tiles"--
    offsetX = 0

    scorestring = tostring(linesscore)
    for i = 1, scorestring:len() - 1 do
        offsetX = offsetX - 8 * scale
    end
    love.graphics.print(linesscore, 136 * scale + offsetX, 80 * scale, 0, scale)
    -----------------------------------------------


    --FULLSCREEN OFFSET
    if fullscreen then
        love.graphics.translate(-fullscreenoffsetX, -fullscreenoffsetY)

        --scissor
        love.graphics.setScissor()
    end

    gameBdebug_draw_panel()
end

function gameBdebug_update(dt)
    if newblock then
        gameBdebug_addTetri()
        newblock = false
    end

    --NEXTPIECE ROTATION (rotating allday erryday)
    nextpiecerot = nextpiecerot + nextpiecerotspeed * dt
    while nextpiecerot > math.pi * 2 do
        nextpiecerot = nextpiecerot - math.pi * 2
    end

    if gamestate == "gameBdebug" then
        if love.keyboard.isDown("x") then
            if tetribodies[1]:getAngularVelocity() < params.angular_cap then
                tetribodies[1]:applyTorque(params.rotation_torque)
            end
        end
        if love.keyboard.isDown("y") or love.keyboard.isDown("z") or love.keyboard.isDown("w") then
            if tetribodies[1]:getAngularVelocity() > -params.angular_cap then
                tetribodies[1]:applyTorque(-params.rotation_torque)
            end
        end

        if love.keyboard.isDown("left") then
            local x, y = tetribodies[1]:getWorldCenter()
            tetribodies[1]:applyForce(-params.lateral_force, 0, x, y)
        end
        if love.keyboard.isDown("right") then
            local x, y = tetribodies[1]:getWorldCenter()
            tetribodies[1]:applyForce(params.lateral_force, 0, x, y)
        end

        local x, y = tetribodies[1]:getLinearVelocity()
        if love.keyboard.isDown("down") then
            --commented part limits the blackfallspeed
            if y > params.difficulty_speed * params.soft_drop_cap_mul then
                tetribodies[1]:setLinearVelocity(x, params.difficulty_speed * params.soft_drop_cap_mul)
            else
                local cx, cy = tetribodies[1]:getWorldCenter()
                tetribodies[1]:applyForce(0, params.soft_drop_force, cx, cy)
            end
        else
            if y > params.difficulty_speed then
                tetribodies[1]:setLinearVelocity(x, y - params.air_brake_coeff * dt)
            end
        end
    end

    world:update(dt, 8, 3)

    if gamestate == "failingB" then
        clearcheck = true
        for i, v in pairs(tetribodies) do
            if v:getY() < 648 then
                clearcheck = false
            end
        end

        if clearcheck then
            failed_load()
        end
    end
end

function collideBdebug(a, b)
    a, b = a:getUserData(), b:getUserData()
    if a == 1 or b == 1 then
        if a ~= "left" and a ~= "right" and b ~= "left" and b ~= "right" then
            if gamestate == "gameBdebug" then
                endblockBdebug()
            end
        end
    end
end

function endblockBdebug()
    if tetribodies[1]:getY() < losingY then
        --LOSE--
        gamestate = "failingB"
        if musicno < 4 then
            love.audio.stop(music[musicno])
        end
        love.audio.stop(gameover1)
        love.audio.play(gameover1)

        wallfixtures[2]:destroy()
        wallfixtures[2] = nil
    else
        --Transfer block from 1 to end of tetribodies
        tetrikind[highestbody() + 1] = tetrikind[1]

        tetriimages[highestbody() + 1] = tetriimages[1]
        tetribodies[highestbody() + 1] = tetribodies[1]

        tetrifixtures[highestbody()] = {}
        tetrishapes[highestbody()] = {}

        for i, v in pairs(tetrifixtures[1]) do
            tetrishapes[highestbody()][i] = tetrishapes[1][i]
            tetrishapes[1][i] = nil

            tetrifixtures[highestbody()][i] = tetrifixtures[1][i]
            tetrifixtures[highestbody()][i]:setUserData({ highestbody() })
            tetrifixtures[1][i] = nil
        end

        tetribodies[1] = nil
        ---------------------------
        linesscore = linesscore + 1
        scorescore = linesscore * 100

        love.audio.stop(blockfall)
        love.audio.play(blockfall)

        newblock = true
    end
end

function gameBdebug_draw_panel()
    if gamestate ~= "gameBdebug" then return end

    love.graphics.setScissor()
    love.graphics.setColor(255, 255, 255)

    local panel_base_x = fullscreenoffsetX or 0
    local panel_base_y = (fullscreenoffsetY or 0) + 144 * scale

    love.graphics.print("debug params", panel_base_x, panel_base_y, 0, scale)

    for idx = 1, 8 do
        local y = panel_base_y + (10 + (idx - 1) * 10) * scale

        love.graphics.print(panel_rows[idx][2], panel_base_x, y, 0, scale)
        love.graphics.print("<", panel_base_x + 96 * scale, y, 0, scale)

        local value_str
        if panel_focus == idx then
            value_str = panel_editing
        else
            value_str = tostring(params[panel_rows[idx][1]])
        end

        if panel_focus == idx then
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("fill", panel_base_x + 104 * scale, y, 40 * scale, 8 * scale)
            love.graphics.setColor(255, 255, 255)
            love.graphics.print(value_str, panel_base_x + 104 * scale, y, 0, scale)
        else
            love.graphics.print(value_str, panel_base_x + 104 * scale, y, 0, scale)
        end

        love.graphics.print(">", panel_base_x + 152 * scale, y, 0, scale)
    end

    love.graphics.setColor(255, 255, 255)
end

function gameBdebug_handle_mouse(x, y, button)
    if gamestate ~= "gameBdebug" or button ~= 1 then return end

    local local_x = (x - (fullscreenoffsetX or 0)) / scale
    local local_y = (y - (fullscreenoffsetY or 0)) / scale - 144

    if local_y < 0 or local_y >= panel_height then return end

    if local_y < 10 then return end
    local row_idx = math.floor((local_y - 10) / 10) + 1
    if row_idx < 1 or row_idx > 8 then return end

    local key = panel_rows[row_idx][1]

    if local_x < 96 then
        return
    end

    if local_x >= 96 and local_x < 104 then
        -- left arrow
        if panel_focus == row_idx then
            local n = tonumber(panel_editing)
            if n ~= nil then
                params[key] = n
                if key == "step" then params.step = math.max(1, params.step) end
            end
        end
        if key == "step" then
            params.step = math.max(1, params.step - 10)
        else
            params[key] = params[key] - params.step
        end
        return
    end

    if local_x >= 104 and local_x < 152 then
        -- field area
        panel_focus = row_idx
        panel_editing = tostring(params[key])
        return
    end

    if local_x >= 152 then
        -- right arrow
        if panel_focus == row_idx then
            local n = tonumber(panel_editing)
            if n ~= nil then
                params[key] = n
                if key == "step" then params.step = math.max(1, params.step) end
            end
        end
        if key == "step" then
            params.step = params.step == 1 and 10 or params.step + 10
        else
            params[key] = params[key] + params.step
        end
        return
    end
end

function gameBdebug_handle_keypressed(key)
    if gamestate ~= "gameBdebug" or panel_focus == nil then return false end

    if key == "escape" then
        panel_focus = nil
        panel_editing = ""
        return true
    end

    if key == "return" or key == "kpenter" then
        local n = tonumber(panel_editing)
        if n ~= nil then
            params[panel_rows[panel_focus][1]] = n
            if panel_rows[panel_focus][1] == "step" then
                params.step = math.max(1, params.step)
            end
        end
        panel_focus = nil
        panel_editing = ""
        return true
    end
    if key == "-" then
        if panel_editing:sub(1, 1) ~= "-" and panel_editing:find("%.") == nil then
            panel_editing = "-" .. panel_editing
        end
        return true
    end

    if key == "." then
        if panel_editing:find("%.") == nil and panel_editing:sub(1, 1) ~= "-" then
            panel_editing = panel_editing .. "."
        end
        return true
    end

    return false
end

function gameBdebug_handle_textinput(text)
    if gamestate ~= "gameBdebug" or panel_focus == nil then return end

    if panel_editing:len() >= 9 then return end

    if text:match("^[0-9]$") then
        panel_editing = panel_editing .. text
    end
end
