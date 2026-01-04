require("Utils")

PowerTrain = {}

---Calculates Clutch engagement and Torque distribution
---@param input CarInput
---@param config CarConfig
---@param state CarState
---@param output CarOutput
function PowerTrain.update(input, config, state, output)
	output.engineThrottle = input.throttle

	-- Mode handling
	if config.mode == "Neutral" then
		output.clutchFront = 0
		output.clutchRear = 0
		return
	end

	-- If breaking power delivery has to be prevented!
	if input.brake > config.pedalLowThreshold then
		state.clutchOverride = 0
	end

	-- Base Torque Split (modified by TractionControl)
	splitF = state.torqueSplitFront or 0.5
	splitR = state.torqueSplitRear or 0.5

	-- Calculate Target Wheel RPS (Acceleration Control)
	-- omega = (v + alpha) / (pi * d)
	-- alpha is slip coefficient offset (allowed slip speed)

	v = math.abs(state.forwardSpeed)
	alpha = config.slipOffset -- e.g. 2 m/s allowed slip
	d = config.wheelDiameter

	targetRPS = (v + alpha) / (math.pi * d)

	-- We want to modulate clutch to keep WheelRPS <= TargetRPS
	-- Simple P-Controller or ratio check
	-- If WheelRPS > TargetRPS, reduce clutch.

	-- Front Axle
	frontRPS = state.wheelRPS_Front
	clutchF = 1.0
	if frontRPS > targetRPS and targetRPS > 0.1 then
		clutchF = math.max(0, 1.0 - (frontRPS - targetRPS) * config.clutchGain)
	end

	-- Rear Axle
	rearRPS = state.wheelRPS_Rear
	clutchR = 1.0
	if rearRPS > targetRPS and targetRPS > 0.1 then
		clutchR = math.max(0, 1.0 - (rearRPS - targetRPS) * config.clutchGain)
	end
	--TODO: Prevent shifting when Power Delivery is limited!

	-- If we are in Sport mode and there is no pedal request for throttle request Anti-Lag
	if config.mode == "Sport" and carInput.throttle < config.pedalLowThreshold then
		carState.antiLagRequest = true
	end

	-- If there is an Anti-Lag request and we are not overtime do the hard throttle up down loop
	if carState.antiLagRequest and carState.antiLagCurrentDuration < config.antiLagMaxDuration then
		if carInput.engineRPS < config.antiLagRPS then
			carInput.throttle = 1
		else
			carInput.throttle = 0
		end
		state.clutchOverride = 0
		carState.antiLagCurrentDuration = carState.antiLagCurrentDuration + 1
	elseif not carState.antiLagRequest then -- Reset when request disappears
		carState.antiLagCurrentDuration = 0
	end

	-- Apply Anti-Lag Override
	if state.clutchOverride ~= nil then
		clutchF = state.clutchOverride
		clutchR = state.clutchOverride
		state.clutchOverride = nil
		--TODO: Check if that actually fixed the problem
	end

	-- Final Assignment with Torque Split
	output.clutchFront = clutchF * splitF * 2 -- Normalize so 0.5 split = 1.0 clutch if full
	output.clutchRear = clutchR * splitR * 2

	-- Clamp
	output.clutchFront = math.clamp(output.clutchFront, 0, 1)
	output.clutchRear = math.clamp(output.clutchRear, 0, 1)

	-- Hopefully limit speed when in reverse
	if config.mode == "Reverse" then
		output.clutchFront = math.clamp(output.clutchFront, 0, 0.5)
		output.clutchRear = math.clamp(output.clutchRear, 0, 0.5)
	end
end
