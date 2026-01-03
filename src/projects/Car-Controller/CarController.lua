require("Utils")
require("src.projects.Car-Controller.Ackermann")
require("src.projects.Car-Controller.Gearbox")
require("src.projects.Car-Controller.PowerTrain")
require("src.projects.Car-Controller.TractionControl")

---@class CarConfig
---@field throttleLowThreshold number Determine when "no throttle" can be assumed
---@field wheelbase number Distance between axles (m)
---@field trackWidthFront number Front axle width (m)
---@field trackWidthRear number Rear axle width (m)
---@field wheelDiameter number Wheel diameter (m)
---@field maxSteerAngle number Max steering angle (radians)
---@field steerBias number 0-1 (Front-Rear steering bias)
---@field steerAssistSlope number
---@field steerAssistOffset number
---@field steerAssistMin number
---@field driftThreshold number Drift angle threshold (rad)
---@field counterSteerGain number
---@field driftPowerShift number Amount to shift power forward when drifting
---@field absSlipThreshold number 0-1
---@field maxRPS number Engine Redline
---@field antiLagRPS number RPS to hold AntiLag
---@field shiftUpRPS number
---@field shiftDownRPS number
---@field shiftCooldown number ticks
---@field shiftCornerThreshold number Rad/s
---@field slipOffset number Allowed slip speed (m/s)
---@field clutchGain number
---@field mode string "Neutral", "Drive", "Sport", "Reverse"
local config = {
	throttleLowThreshold = 0.05,
	wheelbase = 3.0,
	trackWidthFront = 1.5,
	trackWidthRear = 1.5,
	wheelDiameter = 0.75,
	maxSteerAngle = 0.5, -- ~30 degrees
	steerBias = 0.5,
	steerAssistSlope = -0.02, -- Reduces steering as speed increases
	steerAssistOffset = 1.0,
	steerAssistMin = 0.2,
	driftThreshold = 0.2, -- ~11 degrees
	counterSteerGain = 1.0,
	driftPowerShift = 0.05,
	absSlipThreshold = 0.6,
	maxRPS = 22,
	antiLagRPS = 21,
	shiftUpRPS = 20,
	shiftDownRPS = 15,
	shiftCooldown = 30,
	shiftCornerThreshold = 0.5,
	slipOffset = 2.0,
	clutchGain = 0.5,
	mode = "Drive",
}

---@class CarInput
---@field throttle number 0-1
---@field brake number 0-1
---@field steering number -1 to 1
---@field engineRPS number
---@field forwardSpeed number m/s
---@field angularVelocity number rad/s
---@field velocityVector table {x,y,z}
---@field carAngle number Rad
---@field wheelRPS_Front number
---@field wheelRPS_Rear number
---@field modeSelection integer
local carInput = {
	throttle = 0,
	brake = 0,
	steering = 0,
	engineRPS = 0,
	forwardSpeed = 0,
	angularVelocity = 0,
	velocityVector = { x = 0, y = 0, z = 0 },
	carAngle = 0,
	wheelRPS_Front = 0,
	wheelRPS_Rear = 0,
	modeSelection = 0,
}

---@class CarState
---@field driftAngle number
---@field forwardSpeed number
---@field angularVelocity number
---@field wheelRPS_Front number
---@field wheelRPS_Rear number
---@field gearCooldown number
local carState = {
	driftAngle = 0,
	forwardSpeed = 0,
	angularVelocity = 0,
	wheelRPS_Front = 0,
	wheelRPS_Rear = 0,
	gearCooldown = 0,
}

---@class CarOutput
---@field steerFL number Rad
---@field steerFR number Rad
---@field steerRL number Rad
---@field steerRR number Rad
---@field engineThrottle number 0-1
---@field brakeFront number 0-1
---@field brakeRear number 0-1
---@field clutchFront number 0-1
---@field clutchRear number 0-1
---@field shiftUp boolean
---@field shiftDown boolean
---@field torqueSplitFront number
---@field torqueSplitRear number
---@field clutchOverride number|nil
local carOutput = {
	steerFL = 0,
	steerFR = 0,
	steerRL = 0,
	steerRR = 0,
	engineThrottle = 0,
	brakeFront = 0,
	brakeRear = 0,
	clutchFront = 0,
	clutchRear = 0,
	shiftUp = false,
	shiftDown = false,
	torqueSplitFront = 0.5,
	torqueSplitRear = 0.5,
	clutchOverride = nil,
}

function onTick()
	-- Driver Inputs
	carInput.throttle = input.getNumber(1) -- Range: 0 to 1
	carInput.brake = input.getNumber(2) -- Range: 0 to 1
	carInput.steering = input.getNumber(3) -- Range: -1 (Left) to 1 (Right)
	carInput.modeSelection = input.getNumber(4) -- Range: 0 (Neutral), 1 (Drive), 2 (Sport), 3 (Reverse)

	-- Car Physics Sensors
	carInput.engineRPS = input.getNumber(5) -- Range: 0 to Inf (Engine Rotations Per Second)
	carInput.forwardSpeed = input.getNumber(6) -- Range: -Inf to Inf (m/s) - Local X Velocity
	carInput.angularVelocity = input.getNumber(7) -- Range: -Inf to Inf (rad/s) - Yaw Rate (Vertical Axis)

	-- Velocity Vector (Local Space: X=Forward, Y=Up, Z=Right)
	-- Used for Drift Calculation
	carInput.velocityVector.x = input.getNumber(8) -- Local Velocity X (m/s)
	carInput.velocityVector.y = input.getNumber(9) -- Local Velocity Y (m/s)
	carInput.velocityVector.z = input.getNumber(10) -- Local Velocity Z (m/s)

	-- Wheel Speed Sensors (RPS) - Per Axle
	carInput.wheelRPS_Front = input.getNumber(11) -- Front Axle RPS
	carInput.wheelRPS_Rear = input.getNumber(12) -- Rear Axle RPS

	-- 2. Update State
	carState.forwardSpeed = carInput.forwardSpeed
	carState.angularVelocity = carInput.angularVelocity
	carState.wheelRPS_Front = carInput.wheelRPS_Front
	carState.wheelRPS_Rear = carInput.wheelRPS_Rear

	-- Mode Selection
	-- 0: Neutral, 1: Drive, 2: Sport, 3: Reverse
	if carInput.modeSelection == 0 then
		config.mode = "Neutral"
	elseif carInput.modeSelection == 1 then
		config.mode = "Drive"
	elseif carInput.modeSelection == 2 then
		config.mode = "Sport"
	elseif carInput.modeSelection == 3 then
		config.mode = "Reverse"
	end

	-- Calculate Drift Angle
	-- Angle between velocity vector and car heading
	-- Assuming car heading is 0 in local space if velocity is local
	-- If velocityVector is global, we need carAngle.
	-- Assuming carInput.velocityVector is LOCAL to car (X forward, Z right)
	-- beta_v = atan(z, x)
	-- drift = 0 - beta_v (since car forward is 0)
	if math.abs(carInput.velocityVector.x) > 1 then
		carState.driftAngle = math.atan(carInput.velocityVector.z, carInput.velocityVector.x)
	else
		carState.driftAngle = 0
	end

	-- A. Steering
	local fl, fr, rl, rr = Ackermann.calculateSteering(carInput, config, carState)
	carOutput.steerFL = fl
	carOutput.steerFR = fr
	carOutput.steerRL = rl
	carOutput.steerRR = rr

	TractionControl.update(carInput, config, carState, carOutput)

	Gearbox.update(carInput, config, carState, carOutput)

	PowerTrain.update(carInput, config, carState, carOutput)

	-- output.setNumber(...)
end

function onDraw()
	screen.setColor(0, 255, 0)
	screen.drawText(2, 2, "Mode: " .. config.mode)
	screen.drawText(2, 10, "Speed: " .. string.format("%.1f", carState.forwardSpeed))
	screen.drawText(2, 18, "Drift: " .. string.format("%.2f", carState.driftAngle))
end
