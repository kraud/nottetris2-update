# Physics Conversion Cheatsheet: Love 0.7.2 → 11.5
## 1. Creating Bodies

Old: `love.physics.newBody(world, x, y, mass)`  
New: `love.physics.newBody(world, x, y, type)`

The `type` argument must be a string: `"dynamic"`, `"static"`, or `"kinematic"`. In the old API, passing `mass = 0` implied a static body — that pattern no longer works.

```lua
-- Old
local body = love.physics.newBody(world, x, y, 0)       -- static
local body = love.physics.newBody(world, x, y, 10)      -- dynamic, mass 10

-- New
local body = love.physics.newBody(world, x, y, "static")
local body = love.physics.newBody(world, x, y, "dynamic")
```

---

## 2. Setting Mass on Dynamic Bodies

In the old API, mass was passed directly to `newBody`. In the new API, mass is derived from the fixture's density. Set it after creating the fixture:

```lua
-- Old
local body = love.physics.newBody(world, x, y, 10)  -- mass = 10

-- New
local body    = love.physics.newBody(world, x, y, "dynamic")
local shape   = love.physics.newRectangleShape(w, h)
local fixture = love.physics.newFixture(body, shape)
fixture:setDensity(1.0)
body:resetMassData()  -- recalculates mass from density + shape area
```

---

## 3. Attaching Shapes (The Fixture Layer)

The most significant structural change. Shapes no longer attach directly to bodies — a `Fixture` object is now required as an intermediary. This also means density, friction, restitution, sensor state, and collision filtering all move from the shape to the fixture.

```lua
-- Old: shape was attached implicitly at creation
local shape = love.physics.newRectangleShape(body, x, y, w, h, angle)

-- New: shape is created standalone, then bound via a fixture
local shape   = love.physics.newRectangleShape(w, h)          -- no body argument
local fixture = love.physics.newFixture(body, shape)
-- Optional: fixture:setDensity(1.0), fixture:setFriction(0.5), etc.
```

Note: `newRectangleShape` in 0.7.2 accepted `(body, x, y, w, h, angle)`. The new signature is `(w, h)` for a centered rectangle or `(x, y, w, h, angle)` for an offset one — the body argument is gone entirely.

---

## 4. Sensors

In the old API, sensor behavior was a property on the shape. It is now a property on the fixture.

```lua
-- Old
shape:setSensor(true)
local isSensor = shape:isSensor()

-- New
fixture:setSensor(true)
local isSensor = fixture:isSensor()
```

---

## 5. User Data

`getUserData` / `setUserData` have moved from the shape to the fixture.

```lua
-- Old
shape:setUserData(myObject)
local data = shape:getUserData()

-- New
fixture:setUserData(myObject)
local data = fixture:getUserData()
```

---

## 6. Collision Filtering

Category, mask, and group index are now set on the fixture, not the shape.

```lua
-- Old
shape:setCategory(1)
shape:setMask(2)
shape:setGroupIndex(-1)

-- New
fixture:setCategory(1)
fixture:setMask(2)
fixture:setGroupIndex(-1)
```

---

## 7. Retrieving Shapes from Contacts

Collision callbacks receive `Fixture` objects, not shapes. If you need the shape (e.g., to check type or tag), retrieve it from the fixture.

**Callback names also changed:**

| Old (0.7.x)       | New (11.x)     |
|-------------------|----------------|
| `addCallback`     | `beginContact` |
| `removeCallback`  | `endContact`   |
| `persistCallback` | `preSolve`     |
| `resultCallback`  | `postSolve`    |

```lua
-- Old
world:setCallbacks(addCallback, removeCallback, persistCallback, resultCallback)

function addCallback(shapeA, shapeB, collision)
    -- shapeA and shapeB are Shape objects
end

-- New
world:setCallbacks(beginContact, endContact, preSolve, postSolve)

function beginContact(fixtureA, fixtureB, contact)
    local shapeA = fixtureA:getShape()
    local shapeB = fixtureB:getShape()
    local dataA  = fixtureA:getUserData()  -- userData is on the fixture now
    local dataB  = fixtureB:getUserData()
end
```

---

## Quick Reference: What Moved to Fixture

| Property / Method       | Old (Shape) | New (Fixture)      |
|-------------------------|-------------|--------------------|
| `setDensity`            | —           | `fixture:setDensity` |
| `setFriction`           | `shape:`    | `fixture:`         |
| `setRestitution`        | `shape:`    | `fixture:`         |
| `setSensor` / `isSensor`| `shape:`    | `fixture:`         |
| `setUserData`           | `shape:`    | `fixture:`         |
| `getUserData`           | `shape:`    | `fixture:`         |
| `setCategory`           | `shape:`    | `fixture:`         |
| `setMask`               | `shape:`    | `fixture:`         |
| `setGroupIndex`         | `shape:`    | `fixture:`         |
| `getBody`               | `shape:`    | `fixture:`         |
