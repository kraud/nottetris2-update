# Physics Conversion Cheatsheet for Agents

## 1. Creating Bodies
Old: love.physics.newBody(world, x, y, mass)
New: body = love.physics.newBody(world, x, y, type) 
* Note: Modern type must be a string: "dynamic", "static", or "kinematic" (instead of setting mass to 0 for static).

## 2. Attaching Shapes (The Fixture Layer)
Old: love.physics.newRectangleShape(body, x, y, w, h)
New: 
    local shape = love.physics.newRectangleShape(x, y, w, h)
    local fixture = love.physics.newFixture(body, shape)

## 3. Retrieving Shapes from Contacts
Old: function addCallback(shapeA, shapeB, collision)
New: function beginContact(fixtureA, fixtureB, contact)
    local shapeA = fixtureA:getShape()
    local shapeB = fixtureB:getShape()
