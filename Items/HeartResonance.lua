local ItemLib = include("lib.itemLib")
local itemRegistry = ItemLib.registries

-- Store persistent stat bonuses and special effects
local persistentStats = {}
local initialHeartsDropped = false

-- Add new heart combination effects
local HEART_SYNERGIES = {
    HOLY_COMBO = 1,      -- Eternal + Soul hearts: 20% damage multiplier
    DARK_COMBO = 2,      -- Black + Bone hearts: 0.1% chance per frame to generate a black heart
    GOLDEN_GLORY = 3,    -- Golden + Eternal hearts: 2x luck bonus
    DECAY_POWER = 4,     -- Rotten + Black hearts: poison, and slows enemies on hit
    BLOODBURST_POWER = 5 -- 6+ Red Hearts: Every second shot will spawn a burst of smaller tears around it.
}

local function updatePersistentStats(player)
    local playerIndex = player.Index
    if not persistentStats[playerIndex] then
        persistentStats[playerIndex] = {
            damage = 0,
            tears = 0,
            luck = 0,
            poison = false,
            activeEffects = {},
            comboTimer = 0
        }
    end

    -- Get heart counts
    local redHearts = player:GetHearts()
    local soulHearts = player:GetSoulHearts()
    local blackHearts = player:GetBlackHearts()
    local boneHearts = player:GetBoneHearts()
    local rottenHearts = player:GetRottenHearts()
    local eternalHearts = player:GetEternalHearts()
    local goldenHearts = player:GetGoldenHearts()

    local stats = persistentStats[playerIndex]

    -- Enhanced base stat calculations
    stats.damage = (redHearts * 0.25) + (boneHearts * 0.5)
    stats.tears = (soulHearts * 0.25) + (eternalHearts * 0.5)
    stats.luck = (blackHearts * 0.5) + (goldenHearts * 1)
    stats.poison = rottenHearts > 0

    -- Check for heart combinations and apply special effects
    stats.activeEffects = {}

    -- Holy Combo: Eternal + Soul hearts
    if eternalHearts > 0 and soulHearts >= 4 then
        stats.activeEffects[HEART_SYNERGIES.HOLY_COMBO] = true
        stats.damage = stats.damage * 1.2 -- 20% damage multiplier
    end

    -- Dark Combo: Black + Bone hearts
    if blackHearts >= 2 and boneHearts >= 2 then
        stats.activeEffects[HEART_SYNERGIES.DARK_COMBO] = true
        player:AddBlackHearts(1) -- Periodically generate black hearts
    end

    -- Golden Glory: Golden + Eternal hearts
    if goldenHearts >= 1 and eternalHearts >= 1 then
        stats.activeEffects[HEART_SYNERGIES.GOLDEN_GLORY] = true
        stats.luck = stats.luck * 2 -- Double luck bonus
    end

    -- Decay Power: Rotten + Black hearts
    if rottenHearts >= 2 and blackHearts >= 2 then
        stats.activeEffects[HEART_SYNERGIES.DECAY_POWER] = true
        stats.poison = true
        -- Enhanced poison damage will be handled in the tear effect
    end

    -- Bloodburst Power: 6+ Red Hearts
    if redHearts >= 6 then
        stats.activeEffects[HEART_SYNERGIES.BLOODBURST_POWER] = true
        -- Every second shot will spawn a burst of smaller tears around it.
    end
end

local function EvalCache(_, player, cache)
    if (player:HasCollectible(itemRegistry.HeartResonance)) then
        if not initialHeartsDropped then
            -- Drop starter hearts with a special effect
            player:DropHeart(HeartSubType.HEART_BLACK, false)
            player:DropHeart(HeartSubType.HEART_SOUL, false)
            player:DropHeart(HeartSubType.HEART_ETERNAL, false)
            initialHeartsDropped = true
        end

        local playerStats = persistentStats[player.Index]
        if not playerStats then
            updatePersistentStats(player)
            playerStats = persistentStats[player.Index]
        end

        if cache == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + playerStats.damage
        end

        if cache == CacheFlag.CACHE_FIREDELAY then
            player.MaxFireDelay = player.MaxFireDelay - playerStats.tears
        end

        if cache == CacheFlag.CACHE_LUCK then
            player.Luck = player.Luck + playerStats.luck
        end

        if cache == CacheFlag.CACHE_TEARFLAG then
            if playerStats.poison then
                local tearFlags = player.TearFlags | TearFlags.TEAR_POISON
                if playerStats.activeEffects[HEART_SYNERGIES.DECAY_POWER] then
                    tearFlags = tearFlags | TearFlags.TEAR_SLOW -- Add slowness to poison
                end
                player.TearFlags = tearFlags
            end
        end
    end
end

-- Bloodburst Power: Every second shot will spawn a burst of smaller tears around it on hit.
local shotCounter = {}
ItemLib:add(ModCallbacks.MC_POST_TEAR_COLLISION, function(_, tear, collider)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if player and player:HasCollectible(itemRegistry.HeartResonance) then
        shotCounter[player.Index] = (shotCounter[player.Index] or 0) + 1
        if shotCounter[player.Index] % 2 == 0 then
            local stats = persistentStats[player.Index]
            if stats and stats.activeEffects[HEART_SYNERGIES.BLOODBURST_POWER] then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, tear.Position,
                    Vector.Zero, player)
            end
        end
    end
end)

-- Update stats when hearts change
ItemLib:add(ModCallbacks.MC_POST_PLAYER_ADD_HEARTS, function(_, player)
    if player:HasCollectible(itemRegistry.HeartResonance) then
        updatePersistentStats(player)
        player:AddCacheFlags(CacheFlag.CACHE_ALL)
        player:EvaluateItems()
    end
end)

-- Add periodic effects for heart combinations
ItemLib:add(ModCallbacks.MC_POST_UPDATE, function()
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Game():GetPlayer(i)
        if player:HasCollectible(itemRegistry.HeartResonance) then
            local stats = persistentStats[player.Index]
            if stats then
                -- Dark Combo effect: Chance to generate black hearts
                if stats.activeEffects[HEART_SYNERGIES.DARK_COMBO] then
                    if math.random() < 0.001 then -- 0.1% chance per frame
                        player:AddBlackHearts(1)
                    end
                end

                -- Holy Combo effect: Chance for holy light beams
                if stats.activeEffects[HEART_SYNERGIES.HOLY_COMBO] then
                    if math.random() < 0.02 then -- 2% chance per frame
                        local pos = player.Position
                        local beam = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, pos,
                            Vector.Zero, player)
                    end
                end
            end
        end
    end
end)

ItemLib:add(ModCallbacks.MC_EVALUATE_CACHE, EvalCache)

return ItemLib
