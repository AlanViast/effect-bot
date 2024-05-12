LatestGameState = LatestGameState or nil

local colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m",
  yellow = "\27[33m",
}

function printStatus(updateState)
  print("-------------------------[ State ]-------------------------")
  for target, state in pairs(updateState.Players) do
    print(colors.red .. "Player: " .. target .. ", Pos: (" .. state.x .. "," .. state.y .. "), Energy: " .. state.energy .. ", Health: " .. state.health .. colors.reset)
  end
  print("-------------------------[ End ]-------------------------")
end

function inRange(x1, y1, x2, y2, range)
  return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function calculateDirection(x1, y1, x2, y2)
  -- 计算两点之间的差值
  local dx = x2 - x1
  local dy = y2 - y1

  -- 计算向量的方向
  local angle = math.atan(dy, dx)

  -- 将角度转换为度数
  local degrees = math.deg(angle)

  -- 将角度映射到方向字符串
  local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
  local index = math.floor(((degrees + 22.5) % 360) / 45) + 1
  return directionMap[index]
end

function findNearestTarget()
  local player = LatestGameState.Players[ao.id]
  local nearestTargetProcessor
  for target, state in pairs < string > (LatestGameState.Players) do
    if target ~= ao.id then
      if nearestTargetProcessor == nil then
        nearestTargetProcessor = target
      else
        local nearestTarget = LatestGameState.Player[nearestTargetProcessor]
        if (player.x + player.y) - (nearestTarget.x + nearestTarget.y) > (player.x + player.y) > (state.x + state.y) then
          nearestTargetProcessor = target
        end
      end
    end
  end

  return calculateDirection(player.x, player.y, nearestTarget.x, nearestTarget.y)
end

function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false

  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
      targetInRange = true
      break
    end
  end

  if player.energy > 5 and targetInRange then
    print("Player in range. Attacking.")
    ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy) })
  else
    local direction = findNearestTarget()
    print("No player in range, Moving " .. colors.red .. direction .. colors.reset .. '.')
    ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
  end
end

Handlers.add(
    "HandleAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
      ao.send({ Target = Game, Action = "GetGameState" })
      if msg.Event ~= "Player-Ready" then
        print(msg.Event .. ": " .. msg.Data)
      end
    end
)

Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
      local json = require("json")
      LatestGameState = json.decode(msg.Data)
      printStatus(LatestGameState)
      ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    end
)

Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
      if LatestGameState.GameMode ~= "Playing" then
        return
      end
      print("Deciding next action.")
      decideNextAction()
    end
)

Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print("Unable to read energy.")
        ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
      elseif playerEnergy == 0 then
        print("Player has insufficient energy.")
        ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
      else
        print("Returning attack.")
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
      end
      ao.send({ Target = ao.id, Action = "Tick" })
    end
)

Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
      print("[Tick]")
      ao.send({ Target = Game, Action = "GetGameState" })
    end
)

Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function()
      ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Send({ Target = ao.id, Action = "Tick" })