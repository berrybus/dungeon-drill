local ship = love.graphics.newImage("ship.png")
local drill = love.graphics.newImage("drill.png")
local clayImage = love.graphics.newImage("clay.png")
local clay = love.graphics.newSpriteBatch(clayImage, 1000)
local dirtImage = love.graphics.newImage("dirt.png")
local dirt = love.graphics.newSpriteBatch(dirtImage, 1000)
local gemImage = love.graphics.newImage("gems.png")
local gem = love.graphics.newSpriteBatch(gemImage, 1000)
local artifactImage = love.graphics.newImage("artifacts.png")
local artifact = love.graphics.newSpriteBatch(artifactImage, 1000)
local enemyImage = love.graphics.newImage("enemy.png")
local enemy = love.graphics.newSpriteBatch(enemyImage, 1000)
local limestoneImage = love.graphics.newImage("limestone.png")
local limestone = love.graphics.newSpriteBatch(limestoneImage, 1000)
local tileSize = 64
local shipX, shipY = 10 * tileSize, 1 * tileSize
local targetX, targetY = shipX, shipY
local initialX, initialY = shipX, shipY
local moveX = 0
local moveY = 0
local flipX = 1
local width = ship:getWidth()
local drillDir = 0
local canMoveTimer = -1
local SCREENWIDTH = 1280
local SCREENHEIGHT = 720
local PLAYERSPEED = 0.3
local GRIDWIDTH = 20
local GRIDHEIGHT = 21
local MINCAMERAX = -width
local MAXCAMERAX = (SCREENWIDTH / tileSize) - GRIDWIDTH - width
local font
local durability = 100
local gameState = "drill"
local grid = {}
local distances = {}

local baseDurability = 100
local gems = 0
local artifacts = 0
local biomaterial = 0
local precision = 0
local lightRadius = 0

local shopChoice = 1

local curLevel = 0

local shopOptions = {
	"Repair Drill - 5 gems or 1 biomaterial",
	"Upgrade durability - 10 gems",
	"Upgrade precision - 10 gems",
	"Upgrade light - 10 gems",
	"Next Level",
}

function ResetStats()
	baseDurability = 100
	durability = baseDurability
	gems = 0
	artifacts = 0
	biomaterial = 0
	precision = 0
	lightRadius = 0
	curLevel = 0
end

function GenerateGrid()
	for i = 1, GRIDHEIGHT do
		grid[i] = {}
		distances[i] = {}
		for j = 1, GRIDWIDTH do
			grid[i][j] = 0
			distances[i][j] = 0
		end
	end

	-- start by painting everything with dirt
	for i = 2, GRIDHEIGHT do
		for j = 1, GRIDWIDTH do
			grid[i][j] = 2
		end
	end

	-- fill top with clay
	for x = 1, GRIDWIDTH do
		for y = 2, math.random(3, 7) do
			grid[y][x] = 1
		end
	end

	-- generate some limestone
	local indices = GetRandomIndices(math.random(1, 2) + curLevel, 1, GRIDWIDTH, 5, GRIDHEIGHT)

	for i = 1, #indices do
		local x, y = indices[i][1], indices[i][2]
		FillBlocks(3, x, y, 1 + curLevel, 3 + curLevel)
	end

	indices = GetRandomIndices(math.random(3, 4), 1, GRIDWIDTH, 2, GRIDHEIGHT)

	for i = 1, #indices do
		local x, y = indices[i][1], indices[i][2]
		FillBlocks(4, x, y, 0, 1)
	end

	indices = GetRandomIndices(math.random(2, 4), 1, GRIDWIDTH, 8, GRIDHEIGHT)

	for i = 1, #indices do
		local x, y = indices[i][1], indices[i][2]
		FillBlocks(5, x, y, 0, math.random(1, 2))
	end

	indices = GetRandomIndices(math.random(1, 5), 1, GRIDWIDTH, 3, GRIDHEIGHT)

	for i = 1, #indices do
		local x, y = indices[i][1], indices[i][2]
		FillBlocks(6, x, y, 0, math.random(0, 1) + curLevel)
	end
end

function ContainsTuple(tbl, x)
	for _, v in pairs(tbl) do
		if v[1] == x[1] and v[2] == x[2] then
			return true
		end
	end
	return false
end

function GetRandomIndices(n, xMin, xMax, yMin, yMax)
	local indices = {}
	for _ = 1, n do
		local x = math.random(xMin, xMax)
		local y = math.random(yMin, yMax)
		table.insert(indices, { x, y })
	end
	return indices
end

function FillBlocks(item, startX, startY, minDist, maxDist)
	local queue = {}
	local visited = {}
	table.insert(queue, { startX, startY, 0 })
	while #queue > 0 do
		local n = table.remove(queue, 1)
		local x, y, dist = n[1], n[2], n[3]
		if not ContainsTuple(visited, { x, y }) then
			grid[y][x] = item
			table.insert(visited, { x, y })
			local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }

			for i = 1, 4 do
				local dx, dy = dirs[i][1], dirs[i][2]
				local newX = x + dx
				local newY = y + dy
				if
					newX >= 1
					and newX <= #grid[1]
					and newY >= 2
					and newY <= #grid
					and not ContainsTuple(visited, { newX, newY })
					and dist < maxDist
					and (dist + 1 < minDist or math.random() <= 0.75)
				then
					table.insert(queue, { newX, newY, dist + 1 })
				end
			end
		end
	end
end

function CalculateDistances()
	local queue = {}
	local visited = {}
	table.insert(queue, { shipX / tileSize, shipY / tileSize, 0 })
	while #queue > 0 do
		local n = table.remove(queue, 1)
		local x, y, dist = n[1], n[2], n[3]
		if not ContainsTuple(visited, { x, y }) then
			table.insert(visited, { x, y })
			distances[y][x] = dist
			local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }

			for i = 1, 4 do
				local dx, dy = dirs[i][1], dirs[i][2]
				local newX = x + dx
				local newY = y + dy
				if
					newX >= 1
					and newX <= #grid[1]
					and newY >= 1
					and newY <= #grid
					and not ContainsTuple(visited, { newX, newY })
				then
					table.insert(queue, { newX, newY, dist + 1 })
				end
			end
		end
	end
end

function Dump(o)
	for i = 1, #o do
		print(table.concat(o[i], ", "))
	end
end

function StartLevel()
	curLevel = curLevel + 1
	shipY = 1 * tileSize
	shipX = math.random(5, GRIDWIDTH - 5) * tileSize
	targetX, targetY = shipX, shipY
	initialX, initialY = shipX, shipY
	canMoveTimer = love.timer.getTime() + 0.5
	drillDir = 0
	GenerateGrid()
	CalculateDistances()
	gameState = "drill"
end

function love.load()
	love.window.setMode(SCREENWIDTH, SCREENHEIGHT)
	-- for some reason you have to do this to randomize it a little bit
	math.randomseed(os.time())
	math.random()
	math.random()
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	ResetStats()
	StartLevel()
end

function DrillUpdate()
	local function getDamage(item)
		if item == 1 or item == 2 then
			return 1
		elseif item == 3 then
			return 2
		elseif item == 4 or item == 5 then
			return 3
		elseif item == 6 then
			return math.random(5, 10)
		else
			return 0
		end
	end
	if canMoveTimer ~= -1 and love.timer.getTime() <= canMoveTimer then
		local timeDiff = 1 - ((canMoveTimer - love.timer.getTime()) / PLAYERSPEED)
		shipX = initialX + (targetX - initialX) * timeDiff
		shipY = initialY + (targetY - initialY) * timeDiff
	elseif canMoveTimer ~= -1 and love.timer.getTime() > canMoveTimer then
		shipX = targetX
		shipY = targetY
		local gX = targetX / tileSize
		local gY = targetY / tileSize
		durability = durability - getDamage(grid[gY][gX])
		if grid[gY][gX] == 4 then
			gems = gems + math.random(2, 4) + precision
		elseif grid[gY][gX] == 5 then
			artifacts = artifacts + math.random(1, 3) + precision
		elseif grid[gY][gX] == 6 then
			artifacts = artifacts + math.random(2, 4)
			gems = gems + math.random(4, 6)
			biomaterial = biomaterial + math.random(2, 3)
		end
		if durability <= 0 then
			gameState = "gameOver"
			canMoveTimer = love.timer.getTime() + 0.5
		end
		grid[gY][gX] = 0
		canMoveTimer = -1
		CalculateDistances()
	end
	GetMovement()
end

function love.update(dt)
	if gameState == "drill" then
		DrillUpdate()
	end
end

function DrillDraw()
	local function drawBlock(block, x, y)
		if distances[y][x] < 3 + lightRadius then
			block:setColor(255, 255, 255, 1)
		elseif distances[y][x] < 4 + lightRadius then
			block:setColor(255, 255, 255, 0.5)
		elseif distances[y][x] < 6 + lightRadius then
			block:setColor(255, 255, 255, 0.1)
		else
			block:setColor(255, 255, 255, 0)
		end
		block:add(x * tileSize, y * tileSize)
	end
	local cameraX = 1280 / 2 - shipX
	cameraX = Clamp(MINCAMERAX, cameraX, MAXCAMERAX)
	local cameraY = 720 / 2 - shipY
	love.graphics.translate(cameraX, cameraY)
	clay:clear()
	dirt:clear()
	limestone:clear()
	gem:clear()
	artifact:clear()
	enemy:clear()
	for x = 1, #grid[1] do
		for y = 1, #grid do
			if grid[y][x] == 1 then
				drawBlock(clay, x, y)
			elseif grid[y][x] == 2 then
				drawBlock(dirt, x, y)
			elseif grid[y][x] == 3 then
				drawBlock(limestone, x, y)
			elseif grid[y][x] == 4 then
				drawBlock(gem, x, y)
			elseif grid[y][x] == 5 then
				drawBlock(artifact, x, y)
			elseif grid[y][x] == 6 then
				drawBlock(enemy, x, y)
			end
		end
	end
	love.graphics.draw(clay)
	love.graphics.draw(dirt)
	love.graphics.draw(limestone)
	love.graphics.draw(gem)
	love.graphics.draw(artifact)
	love.graphics.draw(enemy)
	local offsetX = 0
	if flipX == -1 then
		offsetX = width
	end
	love.graphics.draw(ship, shipX, shipY, 0, flipX, 1, offsetX, 0)

	if drillDir == 1 then
		love.graphics.draw(drill, shipX, shipY, 0, 1, 1, -48, -16)
	elseif drillDir == 2 then
		love.graphics.draw(drill, shipX, shipY, math.pi / 2, 1, 1, -56, 48)
	elseif drillDir == 3 then
		love.graphics.draw(drill, shipX, shipY, 0, -1, 1, 16, -16)
	elseif drillDir == 4 then
		love.graphics.draw(drill, shipX, shipY, -math.pi / 2, 1, 1, 8, -14)
	end

	local screenX, screenY = love.graphics.inverseTransformPoint(10, 10)
	love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), screenX, screenY)
	love.graphics.print(string.format("Durability: %d / %d", durability, baseDurability), screenX, screenY + 30)
	love.graphics.print("Gems: " .. tostring(gems), screenX, screenY + 60)
	love.graphics.print("Artifacts: " .. tostring(artifacts), screenX, screenY + 90)
	love.graphics.print("Biomaterials: " .. tostring(biomaterial), screenX, screenY + 120)
	love.graphics.print("Level: " .. tostring(curLevel), screenX, screenY + 150)
end

function DrawShop()
	local screenX, screenY = 10, 10
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), screenX, screenY)
	love.graphics.print(string.format("Durability: %d / %d", durability, baseDurability), screenX, screenY + 30)
	love.graphics.print("Gems: " .. tostring(gems), screenX, screenY + 60)
	love.graphics.print("Artifacts: " .. tostring(artifacts), screenX, screenY + 90)
	love.graphics.print("Biomaterials: " .. tostring(biomaterial), screenX, screenY + 120)
	love.graphics.print("Level: " .. tostring(curLevel), screenX, screenY + 150)

	love.graphics.print("SHOP - enter to buy", 800, screenY)
	for i = 1, #shopOptions do
		if shopChoice == i then
			love.graphics.setColor(1, 1, 1, 1)
		else
			love.graphics.setColor(1, 1, 1, 0.7)
		end
		love.graphics.print(shopOptions[i], 800, screenY + i * 30)
	end
end

function love.draw()
	if gameState == "drill" then
		DrillDraw()
	elseif gameState == "gameOver" then
		love.graphics.setFont(font)
		love.graphics.print("Game Over", 520, 300)
		love.graphics.print("Press enter to restart", 520, 330)
	elseif gameState == "shop" then
		DrawShop()
	end
end

function CanMove()
	local gridX = shipX / tileSize + moveX
	local gridY = shipY / tileSize + moveY

	return gridX >= 1 and gridX <= #grid[1] and gridY >= 1 and gridY <= #grid
end

function love.keypressed(key, scancode, isrepeat)
	if gameState == "gameOver" and scancode == "return" and not isrepeat then
		ResetStats()
		StartLevel()
	elseif gameState == "shop" then
		if scancode == "up" then
			shopChoice = (shopChoice - 2) % #shopOptions + 1
		elseif scancode == "down" then
			shopChoice = shopChoice % #shopOptions + 1
		elseif scancode == "return" then
			if shopChoice == 1 then
				if gems >= 5 then
					gems = gems - 5
					durability = baseDurability
				elseif biomaterial >= 1 then
					biomaterial = biomaterial - 1
					durability = baseDurability
				end
			elseif shopChoice == 2 then
				if gems >= 10 then
					gems = gems - 10
					baseDurability = baseDurability + 10
					durability = durability + 10
				end
			elseif shopChoice == 3 then
				if gems >= 10 then
					gems = gems - 10
					precision = precision + 1
				end
			elseif shopChoice == 4 then
				if gems >= 10 then
					gems = gems - 10
					lightRadius = lightRadius + 1
				end
			elseif shopChoice == 5 then
				StartLevel()
			end
		end
	end
end

function GetMovement()
	if canMoveTimer ~= -1 then
		return
	end
	local moveR = love.keyboard.isDown("right") and 1 or 0
	local moveL = love.keyboard.isDown("left") and 1 or 0
	local moveU = love.keyboard.isDown("up") and 1 or 0
	local moveD = love.keyboard.isDown("down") and 1 or 0
	moveX = moveR - moveL
	moveY = moveD - moveU

	if moveX ~= 0 and CanMove() then
		initialX = shipX
		initialY = shipY
		targetX = targetX + tileSize * moveX
		canMoveTimer = love.timer.getTime() + PLAYERSPEED
	elseif moveY ~= 0 and CanMove() then
		initialX = shipX
		initialY = shipY
		targetY = targetY + tileSize * moveY
		canMoveTimer = love.timer.getTime() + PLAYERSPEED
	end

	if moveY == 1 and (shipY / tileSize) == #grid then
		gameState = "shop"
		return
	end

	if grid[targetY / tileSize][targetX / tileSize] ~= 0 then
		if moveX == 1 then
			drillDir = 1
		elseif moveX == -1 then
			drillDir = 3
		elseif moveY == 1 then
			drillDir = 2
		elseif moveY == -1 then
			drillDir = 4
		else
			drillDir = 0
		end
	else
		drillDir = 0
	end

	if moveX == 1 then
		flipX = 1
	elseif moveX == -1 then
		flipX = -1
	end
end

function Clamp(min, val, max)
	return math.max(min, math.min(val, max))
end
