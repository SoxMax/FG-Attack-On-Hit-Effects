
function getSaveTypeString(saveType)
    if saveType == "fortitude" then
		return "FORT"
	elseif saveType == "reflex" then
		return "REF"
	elseif saveType == "will" then
		return "WILL"
	end
    return ""
end

function getStatString(statName)
    if statName == "bab" then
		return "BAB"
	elseif statName == "strength" then
		return "STR"
	elseif statName == "dexterity" then
		return "DEX"
	elseif statName == "constitution" then
		return "CON"
	elseif statName == "intelligence" then
		return "INT"
	elseif statName == "wisdom" then
		return "WIS"
	elseif statName == "charisma" then
		return "CHA"
	end
    return ""
end

local function checkPlayerVisibility(sVisibility, nIdentified)
    local gmOnly = 0
    if sVisibility == "hide" then
        gmOnly = 1
    elseif sVisibility == "show" then
        gmOnly = 0
    elseif nIdentified then
        if nIdentified == 0 then
            gmOnly = 1
        elseif nIdentified > 0  then
            gmOnly = 0
        end
    end
    return gmOnly
end

---comment
---@param dice table A table representing dice
---@param modifier number A number to add or subtract from the rolled total
---@param isMaxRoll boolean Weather the maximum roll should automatically occur
---@return number result The result of the roll and modifiers
local function rollDice(dice, modifier, isMaxRoll)
    if (dice and type(dice) == "table") then
        return StringManager.evalDice(dice, modifier, isMaxRoll);
    else
        return modifier;
    end
end

local function parseWeaponEffect(effectNode)
    local rEffect = {};
    local _, recordname = DB.getValue(DB.getChild(effectNode, "..."), "shortcut")

	rEffect.nDuration = rollDice(DB.getValue(effectNode, "durdice"), DB.getValue(effectNode, "durmod", 0))
	rEffect.sUnits = DB.getValue(effectNode, "durunit", "")
	rEffect.nInit = 0
	-- rEffect.sSource is set at application time so it can use the source actor's CT node path.
	-- This preserves source-sensitive effects under the current CoreRPG/3.5E/PFRPG effect query model.
	rEffect.sSource = ""
	rEffect.nGMOnly = checkPlayerVisibility(DB.getValue(effectNode, "visibility", ""), 1)
	rEffect.sLabel = DB.getValue(effectNode, "effect")
	rEffect.sName = DB.getValue(effectNode, "effect")
	rEffect.bCritOnly = DB.getValue(effectNode, "critonly", 0)
	rEffect.sSaveType = DB.getValue(effectNode, "savetype", "")
	rEffect.nSaveDcStat = DB.getValue(effectNode, "savedcstat", "")
	rEffect.nSaveDcMod = DB.getValue(effectNode, "savedcmod", 0)
    rEffect.sOthertags = DB.getValue(effectNode, "othertags", "")
    return rEffect
end

local function generateSaveDescription(attackName, saveType, saveDc, effectNodePath)
    local saveString = getSaveTypeString(saveType)
    return "[SAVE VS] " .. attackName .. " [" .. saveString .. " DC " .. saveDc .. "] [WEAPON EFFECT:" .. effectNodePath .. "]"
end

local function shouldApplyEffect(isCritEffect, isCrit)
    -- Debug.chat(isCritEffect, isCrit)
    if isCritEffect == 0 then
        return true
    else
        -- Debug.chat("its a crit effect!")
        if isCrit then
            return true
        end
    end
end

local function calculateSaveDc(rSource, dcStat, dcMod)
    local saveDc = 10 + dcMod
    if dcStat ~= "" then
        local abilityBonus = ActorManager35E.getAbilityBonus(rSource, dcStat)
        -- Debug.chat(abilityBonus)
        saveDc = saveDc + abilityBonus
        if dcStat ~= "bab" then
            local abilityEffectBonus = ActorManagerD20.getAbilityEffectsBonus(rSource, dcStat)
            -- Debug.chat(abilityEffectBonus)
            saveDc = saveDc + abilityEffectBonus
        end
    end
    return saveDc
end

local function getDamageTotal(rRoll)
    local totalDamage = 0
    local hasResults = false

    for _, result in pairs(rRoll.tResults or {}) do
        hasResults = true
        totalDamage = totalDamage + (result.nTotal or 0)
    end

    if hasResults then
        return totalDamage
    end

    return rRoll.nTotal or 0
end

local function getDamageAttackName(rRoll)
    if (rRoll.sLabel or "") ~= "" then
        return StringManager.trim(rRoll.sLabel)
    end

    local attackName = ActionDamageCore.decodeLabelText(rRoll.sDesc or "")
    if attackName ~= "" then
        return attackName
    end

    return StringManager.trim((rRoll.sDesc or ""):match("%[DAMAGE[^]]*%] ([^[]+)") or "")
end

local function addWeaponEffect(rSource, targetNode, weaponEffect)
    if not targetNode or not weaponEffect then
        return
    end

    weaponEffect.sSource = ActorManager.getCTNodeName(rSource)

    EffectManager.addEffect("", nil, targetNode, weaponEffect, true)
end

local function applyWeaponEffectToTarget(rSource, rTarget, targetNode, attackName, isCrit, effectNode)
    local weaponEffect = parseWeaponEffect(effectNode)
    -- Debug.chat(weaponEffect)
    if shouldApplyEffect(weaponEffect.bCritOnly, isCrit) then
        local saveType = weaponEffect.sSaveType
        local saveDc = calculateSaveDc(rSource, weaponEffect.nSaveDcStat, weaponEffect.nSaveDcMod)
        -- Debug.chat(saveType, saveDc)
        if saveType ~= "" and saveDc > 0 then
            local saveDescription = generateSaveDescription(attackName, saveType, saveDc, effectNode.getNodeName())
            ActionSave.performVsRoll(nil, rTarget, saveType, saveDc, weaponEffect.nGMOnly, rSource, false, saveDescription, weaponEffect.sOthertags)
        else
            addWeaponEffect(rSource, targetNode, weaponEffect)
        end
    end
end

local function applyDamageWeaponEffect(rSource, rTarget, rRoll)
    -- Debug.chat(rSource, rTarget, rRoll)
    if not rSource or not rTarget or not rRoll then
        return
    end

    if not ActorManager.isPC(rSource) then
        return
    end

    if getDamageTotal(rRoll) <= 0 then
        return
    end

    local attackName = getDamageAttackName(rRoll)
    if attackName == "" then
        return
    end

    local sourceNode = ActorManager.getCreatureNode(rSource)
    local targetNode = ActorManager.getCTNode(rTarget) or ActorManager.getCreatureNode(rTarget)
    if not sourceNode or not targetNode then
        return
    end

    local isCrit = rRoll.bCritical or (rRoll.sDesc or ""):find("[CRITICAL]", 0, true)
    -- Debug.chat("From weapon", attackName)
    -- Debug.chat("Is Crit", isCrit)
    for _, weaponNode in pairs(DB.getChildren(sourceNode, "weaponlist")) do
        if DB.getValue(weaponNode, "name", ""):lower() == attackName:lower() then
            -- Debug.chat("weapon found!", weaponNode)
            for _, effectNode in pairs(DB.getChildren(weaponNode, "effectlist")) do
                applyWeaponEffectToTarget(rSource, rTarget, targetNode, attackName, isCrit, effectNode)
            end
        end
    end
end

local function applySaveWeaponEffect(rSource, rOrigin, rRoll)
    -- Debug.chat(rSource, rOrigin, rRoll)
    if not rSource or not rRoll then
        return
    end

    local saveResult = rRoll.sResult
    local effectNodePath
    if rRoll.sSaveDesc then
        effectNodePath = rRoll.sSaveDesc:match("%[WEAPON EFFECT:(.+)%]")
    end
    -- Debug.chat(saveResult, effectNodePath)
    if effectNodePath and (saveResult == "failure" or saveResult == "critfailure" or saveResult == "half_failure") then
        local targetNode = ActorManager.getCTNode(rSource) or ActorManager.getCreatureNode(rSource)
        local effectNode = DB.findNode(effectNodePath)
        if not targetNode or not effectNode then
            return
        end
        local weaponEffect = parseWeaponEffect(effectNode)
        -- Debug.chat(targetNode, weaponEffect)
        addWeaponEffect(rOrigin, targetNode, weaponEffect)
    end
end

function onInit()
    local extensions = {}
    for k, v in pairs(Extension.getExtensions()) do extensions[v] = k end
    Extension.extensions = extensions

    GameManager.addEventFunction("onDamagePostResolve", applyDamageWeaponEffect)
    GameManager.addEventFunction("onSavePostResolve", applySaveWeaponEffect)
end
