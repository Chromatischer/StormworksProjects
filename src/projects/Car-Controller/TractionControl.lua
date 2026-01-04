-- Author: Opencode
-- Traction Control & ABS Module

require("Utils")

TractionControl = {}

---Applies Traction Control, Drift Assist, and ABS modifications to the output
---@param input CarInput
---@param config CarConfig
---@param state CarState
---@param output CarOutput
function TractionControl.update(input, config, state, output)
	-- 1. Drift Assist
	-- Gamma = |alpha - beta_v| (Car Angle - Velocity Angle)
	-- In 2D   space, if velocity is purely X, beta_v is 0.
	-- If car is sliding, beta_v deviates.
	-- state.driftAngle is the angle between heading and velocity vector.

	driftQuotient = math.abs(state.driftAngle)

	-- Store for debug/telemetry
	state.driftQuotient = driftQuotient

	if config.mode == "Sport" or config.mode == "Drive" then
		if driftQuotient > config.driftThreshold then
			-- A: Counter-steer
			-- If we are drifting left (positive drift angle), we need to steer right (negative)
			-- But wait, Ackermann handles geometry.
			-- Counter steer is an offset to the steering wheel input essentially.

			counterSteer = -state.driftAngle * config.counterSteerGain

			-- Let Ackermann handle what the wheels should do
			input.steering = input.steering + counterSteer

			-- B: Push power forward
			-- Reduce rear power, increase front power bias
			-- This is handled by modifying torque split
			state.torqueSplitFront = math.min(1.0, state.torqueSplitFront + config.driftPowerShift)
			state.torqueSplitRear = math.max(0.0, state.torqueSplitRear - config.driftPowerShift)
		end
	end

	-- 2. ABS (Break Assist)
	-- Release break pressure if wheel speed < percentage of car speed
	if input.brake > config.pedalLowThreshold then
		carSpeed = state.forwardSpeed
		threshold = carSpeed * config.absSlipThreshold -- e.g. 0.8 * speed

		-- Simple per-axle check (assuming average axle speed)
		-- Front Axle
		frontWheelSpeed = state.wheelRPS_Front * math.pi * config.wheelDiameter -- m/s

		if frontWheelSpeed < threshold and carSpeed > 1 then -- Only if moving
			output.brakeFront = 0 -- Release
		else
			output.brakeFront = input.brake
		end

		-- Rear Axle
		rearWheelSpeed = state.wheelRPS_Rear * math.pi * config.wheelDiameter

		if rearWheelSpeed < threshold and carSpeed > 1 then
			output.brakeRear = 0
		else
			output.brakeRear = input.brake
		end
	else
		output.brakeFront = 0
		output.brakeRear = 0
	end
end
