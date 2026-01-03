require("Utils")

PowerTrain = {}

---Calculates Clutch engagement and Torque distribution
---@param input CarInput
---@param config CarConfig
---@param state CarState
---@param output CarOutput
function PowerTrain.update(input, config, state, output)
	-- Mode handling
	if config.mode == "Neutral" then
		output.clutchFront = 0
		output.clutchRear = 0
		return
	end

	-- Base Torque Split (modified by TractionControl)
	local splitF = output.torqueSplitFront or 0.5
	local splitR = output.torqueSplitRear or 0.5

	-- Calculate Target Wheel RPS (Acceleration Control)
	-- omega = (v + alpha) / (pi * d)
	-- alpha is slip coefficient offset (allowed slip speed)

	local v = math.abs(state.forwardSpeed)
	local alpha = config.slipOffset -- e.g. 2 m/s allowed slip
	local d = config.wheelDiameter

	local targetRPS = (v + alpha) / (math.pi * d)

	-- We want to modulate clutch to keep WheelRPS <= TargetRPS
	-- Simple P-Controller or ratio check
	-- If WheelRPS > TargetRPS, reduce clutch.

	-- Front Axle
	local frontRPS = state.wheelRPS_Front
	local clutchF = 1.0
	if frontRPS > targetRPS and targetRPS > 0.1 then
		clutchF = math.max(0, 1.0 - (frontRPS - targetRPS) * config.clutchGain)
	end

	-- Rear Axle
	local rearRPS = state.wheelRPS_Rear
	local clutchR = 1.0
	if rearRPS > targetRPS and targetRPS > 0.1 then
		clutchR = math.max(0, 1.0 - (rearRPS - targetRPS) * config.clutchGain)
	end

	-- Apply Anti-Lag Override
	if output.clutchOverride ~= nil then
		clutchF = output.clutchOverride
		clutchR = output.clutchOverride
	end

	-- Final Assignment with Torque Split
	output.clutchFront = clutchF * splitF * 2 -- Normalize so 0.5 split = 1.0 clutch if full
	output.clutchRear = clutchR * splitR * 2

	-- Clamp
	output.clutchFront = math.clamp(output.clutchFront, 0, 1)
	output.clutchRear = math.clamp(output.clutchRear, 0, 1)
end
