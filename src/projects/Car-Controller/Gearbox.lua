Gearbox = {}

---@param carInput CarInput
---@param config CarConfig
---@param carState CarState
---@param carOutput CarOutput
function Gearbox.update(carInput, config, carState, carOutput)
	-- Cooldown handling
	if carState.gearCooldown > 0 then
		carState.gearCooldown = carState.gearCooldown - 1
		return
	end

	-- Reverse Mode
	if config.mode == "Reverse" then
		if carOutput.gear ~= -1 then
			carOutput.gear = -1
			carState.gearCooldown = config.shiftCooldown
		end
		return
	end

	-- Neutral Mode
	if config.mode == "Neutral" then
		if carOutput.gear ~= 0 then
			carOutput.gear = 0
			carState.gearCooldown = config.shiftCooldown
		end
		return
	end

	-- Drive/Sport Mode (Forward gears)
	if config.mode == "Drive" or config.mode == "Sport" then
		-- If in reverse or neutral, shift to 1st gear
		if carOutput.gear < 1 then
			carOutput.gear = 1
			carState.gearCooldown = config.shiftCooldown
			return
		end

		-- Automatic shifting logic
		local currentRPS = carInput.engineRPS
		
		-- Don't shift if cornering hard
		if math.abs(carInput.angularVelocity) > config.shiftCornerThreshold then
			return
		end

		-- Shift Up
		if currentRPS > config.shiftUpRPS and carOutput.gear < config.maxGear then
			carOutput.gear = carOutput.gear + 1
			carState.gearCooldown = config.shiftCooldown
		end

		-- Shift Down
		if currentRPS < config.shiftDownRPS and carOutput.gear > 1 then
			carOutput.gear = carOutput.gear - 1
			carState.gearCooldown = config.shiftCooldown
		end
	end
end

return Gearbox
