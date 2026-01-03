require("Utils")

Gearbox = {}

---Updates Gearbox state and calculates Engine Throttle/Clutch overrides
---@param input CarInput
---@param config CarConfig
---@param state CarState
---@param output CarOutput
function Gearbox.update(input, config, state, output)
	local antiLagActive = false
	if config.mode == "Sport" and state.forwardSpeed > 5 then -- > 5 m/s
		if input.throttle < config.throttleLowThreshold then
			if input.engineRPS < config.antiLagRPS then
				antiLagActive = true
			end
		end
	end

	if antiLagActive then
		output.engineThrottle = 1.0
		output.clutchOverride = 0.0
	else
		output.engineThrottle = input.throttle
		output.clutchOverride = nil
	end

	-- 2. Automatic Shifting
	-- Cooldown handling
	--TODO: This might cause issues since it relies on the fact that shift up or down conditions have to be met exactly when this goes to 0, this might be fine but might also not be
	state.gearCooldown = state.gearCooldown or 0
	if state.gearCooldown > 0 then
		state.gearCooldown = state.gearCooldown - 1
		output.shiftUp = false
		output.shiftDown = false
		return
	end

	-- Prevent shifting when off the throttle
	if input.throttle < config.throttleLowThreshold then
		output.shiftDown = false
		output.shiftUp = false
		return
	end

	-- Prevent shifting while cornering hard
	if math.abs(state.angularVelocity) > config.shiftCornerThreshold then
		return
	end

	-- Shift Logic
	local currentRPS = input.engineRPS

	-- Upshift
	-- If RPS > UpshiftThreshold AND not max gear
	-- Also prevent upshift if throttle is low (unless we want to cruise)
	if currentRPS > config.shiftUpRPS then
		output.shiftUp = true
		state.gearCooldown = config.shiftCooldown
		return
	end

	-- Downshift
	-- If RPS < DownshiftThreshold AND not min gear
	if currentRPS < config.shiftDownRPS then
		--TODO: Prevent downshift over-rev
		-- Prevent downshift if it would over-rev (simple check: if we downshift, RPS goes up by ratio step. Safety margin)
		-- Assuming linear-ish gear ratios, check is complex without knowing next gear ratio.

		--TODO: Implement Kickdown mode
		-- Throttle increase > 50% quickly
		output.shiftDown = true
		state.gearCooldown = config.shiftCooldown
		return
	end

	output.shiftUp = false
	output.shiftDown = false
end
