-- Inspired by STI, but even more simple?

local Map = {}

local mapFolder = ""

function Map:setMapFolder(foldername)
	mapFolder = foldername
	if mapFolder:sub(#mapFolder,#mapFolder) ~= "/" then
		mapFolder = mapFolder .. "/"
	end
end

function Map:new(mapName)
	local map = love.filesystem.load(mapFolder..mapName)
	setfenv(map, {}); map = setmetatable(map(), {__index = Map})
  	map:loadMap()
  	return map
end

function Map:loadMap()
	self.tiles = {}
	self.spriteBatches = {}
	local gids = {}
	for i, tileset in ipairs(self.tilesets) do
		tileset.imagename = tileset.image
		tileset.image = love.graphics.newImage(mapFolder..tileset.image)
		self.spriteBatches[tileset.imagename] = love.graphics.newSpriteBatch(tileset.image, self.width*self.height*#self.layers, "static")
		tileset.spritebatch = self.spriteBatches[tileset.imagename]
		tileset.tilesInX= tileset.imagewidth/tileset.tilewidth
		tileset.tilesInY = tileset.imageheight/tileset.tileheight
		tileset.tilesById = {}
		for i,v in ipairs(tileset.tiles) do
			tileset.tilesById[v.id] = v
		end
		gids[#gids+1] = { firstgid = tileset.firstgid, tileset = tileset, max = (tileset.imagewidth/tileset.tilewidth) * (tileset.imageheight/tileset.tileheight)}
	end
	self.gidsToTilesets = {}

	for i,v in ipairs(gids) do
		local max = v.max
		if gids[i+1] then
			max = gids[i+1].firstgid - 1
		end
		for i=0, max do
			self.gidsToTilesets[i] = v.tileset
		end
	end

	self.inverseLayers = {}
	for i,layer in ipairs(self.layers) do
		self.inverseLayers[layer.name] = layer
		self:loadTiles(layer)
	end
end

function Map:loadTiles(layer)
	local k = 0
	layer.spriteBatches = {}
	layer.tilemap = {}
	for i, gid in ipairs(layer.data) do
		local tileset = self.gidsToTilesets[gid]
		local offsetgid = gid - (tileset.firstgid)
		local image = tileset.image
		local y = tileset.tileheight * math.floor(offsetgid/tileset.tilesInX)

		local tile = {
			x = (k%self.width) * self.tilewidth,
			y = math.floor(k/self.width)*self.tileheight,
			quad = love.graphics.newQuad(tileset.tilewidth * (offsetgid%tileset.tilesInX), y, tileset.tilewidth, tileset.tileheight, tileset.imagewidth, tileset.imageheight),
			properties = tileset.tilesById[gid-1] and tileset.tilesById[gid-1].properties or {},
			tileset = tileset
		}

		layer.tilemap[(tile.x/self.tilewidth)..","..(tile.y/self.tileheight)] = tile

		if gid > 0 then
			tileset.spritebatch:add(tile.quad, tile.x, tile.y)
			layer.spriteBatches[tileset.spritebatch] = tileset.spritebatch
		end
		k = k + 1
	end
end

function Map:setDrawRange(x,y,w,h)
	-- TODO do something here?
end

function Map:addLayer(name)
	local layer = {
		name = name,
		type = "custom",
		objects = {}
	}
	self.layers[#self.layers+1] = layer
	self.inverseLayers[layer.name] = layer
	return layer
end

function Map:getLayer(name)
	return self.inverseLayers[name]
end

function Map:get(layerName, x, y)
	local layer = self.inverseLayers[layerName]
	return layer.tilemap[(x-1)..","..(y-1)]
end

function Map:update()
	for i,v in ipairs(self.layers) do
		if v.type == "custom" then
			for i=#v.objects,1,-1 do
				local obj = v.objects[i]
				if obj then
					obj:update(dt)
					if obj.dead then
						table.remove(v.objects, i)
					end
				end
			end
		end
	end
end

function Map:draw()
	love.graphics.setColor(255,255,255,255)
	for i,v in ipairs(self.layers) do
		if v.type == "tilelayer" then
			for i,v in pairs(v.spriteBatches) do
				love.graphics.draw(v)
			end
		elseif v.type == "custom" then
			for i,v in ipairs(v.objects) do
				v:draw(dt)
			end
		end
	end
end

return Map