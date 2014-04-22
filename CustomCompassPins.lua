-- CustomCompassPins by Shinni
local version = 1.11
local onlyUpdate = false

if COMPASS_PINS then
	if COMPASS_PINS.version and COMPASS_PINS.version >= version then
		return
	end
	onlyUpdate = true
else
	COMPASS_PINS = {}
end

local PARENT = COMPASS.container
local FOV = math.pi * 0.6

--
-- Base class, can be accessed via COMPASS_PINS
--

local CompassPinManager = ZO_ControlPool:Subclass()

function COMPASS_PINS:New( ... )
	if onlyUpdate then
		self:UpdateVersion()
	else
		self:Initialize( ... )
	end
	
	self.control:SetHidden(false)
	self.control:SetHandler("OnUpdate", function() self:Update() end )
	self.version = version
	self.defaultFOV = FOV
	return result
end

function COMPASS_PINS:UpdateVersion()
	local pins = self.pinManager.pins
	self.pinManager = CompassPinManager:New()
	for pinType, _ in pairs(pins) do
		self.pinManager:CreatePinType( pinType )
	end
end

function COMPASS_PINS:Initialize( ... )
	self.control = WINDOW_MANAGER:CreateControlFromVirtual("CP_Control", GuiRoot, "ZO_MapPin")
	self.pinCallbacks = {}
	self.pinLayouts = {}
	self.pinManager = CompassPinManager:New()
end

-- pinType should be a string eg "skyshard"
-- pinCallbacks should be a function, it receives the pinManager as argument
-- layout should be table, currently only the key texture is used (which should return a string) 
function COMPASS_PINS:AddCustomPin( pinType, pinCallback, layout )
	self.pinCallbacks[ pinType ] = pinCallback
	self.pinLayouts[ pinType ] = layout
	self.pinManager:CreatePinType( pinType )
end

-- refreshes/calls the pinCallback of the given pinType
-- refreshes all custom pins if no pinType is given
function COMPASS_PINS:RefreshPins( pinType )
	self.pinManager:RemovePins( pinType )
	if pinType then
		if not self.pinCallbacks[ pinType ] then
			return
		end
		self.pinCallbacks[ pinType ]( self.pinManager )
	else
		for tag, callback in pairs( self.pinCallbacks ) do
			callback( self.pinManager )
		end
	end
	
end

-- updates the pins (recalculates the position of the pins)
function COMPASS_PINS:Update()
	-- maybe add some delay, because pin update could be to expensive to be calculated every frame
	local heading = GetPlayerCameraHeading()
	if not heading then
		return
	end
	if heading > math.pi then --normalize heading to [-pi,pi]
		heading = heading - 2 * math.pi
	end
	
	local x, y = GetMapPlayerPosition("player")
	self.pinManager:Update( x, y, heading )
end

--
-- pin manager class, updates position etc
--

function CompassPinManager:New( ... )
	
	local result = ZO_ControlPool.New(self, "ZO_MapPin", PARENT, "Pin")
	result:Initialize( ... )
	
	return result
end

function CompassPinManager:Initialize( ... )
	self.pins = {}
	self.pinLayouts = {}
	self.defaultAngle = 1
end

function CompassPinManager:CreatePinType( pinType )
	self.pins[ pinType ] = {}
end

-- creates a pin of the given pinType at the given location
-- (radius is not implemented yet)
function CompassPinManager:CreatePin( pinType, pinTag, xLoc, yLoc )
	local pin, pinKey = self:AcquireObject()
	table.insert( self.pins[ pinType ], pinKey )
	
	self:ResetPin( pin )
	pin:SetHandler("OnMouseDown", nil)
	pin:SetHandler("OnMouseUp", nil)
	pin:SetHandler("OnMouseEnter", nil)
	pin:SetHandler("OnMouseExit", nil)
	
	pin.xLoc = xLoc
	pin.yLoc = yLoc
	pin.pinType = pinType
	pin.pinTag = pinTag
	local layout = COMPASS_PINS.pinLayouts[ pinType ]
	local texture = pin:GetNamedChild( "Background" )
	texture:SetTexture( layout.texture )
end

function CompassPinManager:RemovePins( pinType )
	if not pinType then
		self:ReleaseAllObjects()
		for pinType, _ in pairs( self.pins ) do
			self.pins[ pinType ] = {}
		end
	else
		if not self.pins[ pinType ] then
			return
		end
		for _, pinKey in pairs( self.pins[ pinType ] ) do
			self:ReleaseObject( pinKey )
		end
		self.pins[ pinType ] = {}
	end
end

function CompassPinManager:ResetPin( pin )
	for _, layout in pairs(COMPASS_PINS.pinLayouts) do
		if layout.additionalLayout then
			layout.additionalLayout[2]( pin )
		end
	end
end

function CompassPinManager:Update( x, y, heading )
	local value
	local pin
	local angle
	local normalizedAngle
	local xDif, yDif
	local layout
	local normalizedDistance
	for _, pinKeys in pairs( self.pins ) do
		for _, pinKey in pairs( pinKeys ) do
			pin = self:GetExistingObject( pinKey )
			if pin then
				--self:ResetPin( pin )
				pin:SetHidden( true )
				layout = COMPASS_PINS.pinLayouts[ pin.pinType ]
				xDif = x - pin.xLoc
				yDif = y - pin.yLoc
				normalizedDistance = (xDif * xDif + yDif * yDif) / (layout.maxDistance * layout.maxDistance)
				if normalizedDistance < 1 then
					angle = -math.atan2( xDif, yDif )
					angle = (angle + heading)
					if angle > math.pi then
						angle = angle - 2 * math.pi
					elseif angle < -math.pi then
						angle = angle + 2 * math.pi
					end
				
					normalizedAngle = 2 * angle / (layout.FOV or COMPASS_PINS.defaultFOV)
					
					if zo_abs(normalizedAngle) > (layout.maxAngle or self.defaultAngle) then
						pin:SetHidden( true )
					else
					
					--d(normalizedAngle)
					
					pin:ClearAnchors()
					pin:SetAnchor( CENTER, PARENT, CENTER, 0.5 * PARENT:GetWidth() * normalizedAngle, 0)
					pin:SetHidden( false )
					
					if layout.sizeCallback then
						layout.sizeCallback( pin, angle, normalizedAngle, normalizedDistance )
					else
						if zo_abs(normalizedAngle) > 0.25 then
							pin:SetDimensions( 36 - 16 * zo_abs(normalizedAngle), 36 - 16 * zo_abs(normalizedAngle) )
						else
							pin:SetDimensions( 32 , 32  )
						end
					end
					
					pin:SetAlpha(1 - normalizedDistance)
					
					if layout.additionalLayout then
						layout.additionalLayout[1]( pin, angle, normalizedAngle, normalizedDistance)
					end
					
					-- end for inside maxAngle
					end --stupid lua has no continue/next in loops >_>
				end
			end
		end
	end
end

COMPASS_PINS:New()
--can't create OnUpdate handler on via CreateControl, so i'll have to create somethin else via virtual


--[[
example:

COMPASS_PINS:CreatePinType( "skyshard", function (pinManager)
		for _, skyshard in pairs( mySkyshards ) do
			pinManager:CreatePin( "skyshard", skyshard.x, skyshard.y )
		end
	end,
	{ texture = "esoui/art/compass/quest_assistedareapin.dds" } )
	
]]--