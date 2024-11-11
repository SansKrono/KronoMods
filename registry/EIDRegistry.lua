local EIDRegistry = {}

---register items to EID
---@param itemRegistry ItemRegistry
function EIDRegistry.register(itemRegistry)
  if EID then
    EID:addCollectible(itemRegistry.Elysium, "Multiplies your luck for the room, stacks with multiple uses")
    EID:addCollectible(itemRegistry.Hermes, "Doubles your speed")
    EID:addCollectible(itemRegistry.Exodus, "Clears 5 rooms, then disappears")
    EID:addCollectible(itemRegistry.HeartResonance, "What is within shall make you stronger")
  end
end

return EIDRegistry
