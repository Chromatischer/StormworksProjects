-- Author: Opencode
-- Steering Logic Module

require("Utils")

Ackermann = {}

---Calculates the target steering angles for all 4 wheels
---@param input CarInput The current input state
---@param config CarConfig The car configuration
---@param state CarState The current car state
---@return number fl Front Left Angle (Radians)
---@return number fr Front Right Angle (Radians)
---@return number rl Rear Left Angle (Radians)
---@return number rr Rear Right Angle (Radians)
function Ackermann.calculateSteering(input, config, state)
	-- 1. Calculate Assisted Steering Input (Speed sensitive)
	-- Formula: alpha_out = alpha_in * (a * |v| + b)
	-- where a is slope, b is offset (usually 1 at speed 0)

	speed = math.abs(state.forwardSpeed)
	assistFactor = math.clamp(config.steerAssistSlope * speed + config.steerAssistOffset, config.steerAssistMin, 1.0)

	-- Apply assist to raw input (-1 to 1)
	requestedAngle = input.steering * config.maxSteerAngle * assistFactor

	-- 2. Ackermann Geometry
	-- R = l / tan(eta)
	-- If steering is 0, return 0
	if math.abs(requestedAngle) < 0.001 then
		return 0, 0, 0, 0
	end

	L = config.wheelbase
	w_f = config.trackWidthFront
	w_r = config.trackWidthRear
	lambda = config.steerBias -- 0.5 balanced, 1.0 rear biased, 0.0 front biased

	if config.mode == "Reverse" then
		-- Only basic steering (Front wheels only), no rear steering
		-- We can treat this as lambda = 0 (Steering center at rear axle)
		-- And force rear angles to 0
		lambda = 0
	end

	-- Calculate Turn Radius
	-- requestedAngle is eta
	tanEta = math.tan(requestedAngle)
	R = L / tanEta

	-- Distances from Center of Rotation to axles
	distFront = (1 - lambda) * L
	distRear = lambda * L

	-- Calculate individual wheel angles
	-- Front Left (alpha)
	-- alpha = arctan( (1-lambda)*l / (R - a/2) )
	-- Here a is track width (w_f)
	fl = math.atan(distFront / (R - w_f / 2))

	-- Front Right (beta)
	-- beta = arctan( (1-lambda)*l / (R + a/2) )
	fr = math.atan(distFront / (R + w_f / 2))

	-- Rear Left (gamma)
	-- gamma = -arctan( lambda*l / (R - b/2) )
	rl = -math.atan(distRear / (R - w_r / 2))

	-- Rear Right (delta)
	-- delta = -arctan( lambda*l / (R + b/2) )
	rr = -math.atan(distRear / (R + w_r / 2))

	return fl, fr, rl, rr
end
