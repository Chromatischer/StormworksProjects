-- TransmissionCalc Gearbox Controller
-- Decodes a compressed configuration string from TransmissionCalc/main.py into gearbox states.
-- Follows patterns from Car-Controller.

---@class ControllerConfig
---@field codeMap string The character map for decoding
---@field exportString string The configuration string from property
local config = {
	codeMap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/",
	exportString = "",
}

---@class ControllerInput
---@field selectedGear number 1-based gear index
local inputs = {
	selectedGear = 0,
}

---@class ControllerOutput
---@field gearboxes table<number, boolean>
local outputs = {
	gearboxes = { false, false, false, false, false, false },
}

---Helper function to find index of character in map
---@param char string Single character
---@return number index 0-based index or -1 if not found
local function decodeChar(char)
	-- Linear search using string.find with plain=true
	local s, e = string.find(config.codeMap, char, 1, true)
	if s then
		return s - 1 -- Convert 1-based Lua index to 0-based integer
	end
	return -1
end

function onTick()
	config.exportString = property.getText("Export String")

	inputs.selectedGear = input.getNumber(1)

	for i = 1, 6 do
		outputs.gearboxes[i] = false
	end

	-- Round gear to nearest integer to handle float inputs safely
	local gearIndex = math.floor(inputs.selectedGear + 0.5)

	-- Check bounds
	if gearIndex >= 1 and gearIndex <= string.len(config.exportString) then
		-- Get character for this gear
		local char = string.sub(config.exportString, gearIndex, gearIndex)

		-- Decode to 6-bit integer
		local val = decodeChar(char)

		if val >= 0 then
			-- Extract bits for each gearbox
			-- Bit 0 (LSB) -> Gearbox 1
			-- Bit 1       -> Gearbox 2
			-- ...
			local currentVal = val
			for i = 1, 6 do
				-- Check LSB
				if (currentVal % 2) >= 1 then
					outputs.gearboxes[i] = true
				end
				-- Shift right
				currentVal = math.floor(currentVal / 2)
			end
		end
	end

	for i = 1, 6 do
		output.setBool(i, outputs.gearboxes[i])
	end
end
