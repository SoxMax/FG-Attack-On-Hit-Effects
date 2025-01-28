
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
	-- rEffect.sSource = recordname or DB.getChild(effectNode, ".....").getPath() or ""
	rEffect.sSource = DB.getChild(effectNode, ".....").getPath() or ""
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
            local abilityEffectBonus = ActorManager35E.getAbilityEffectsBonus(rSource, dcStat)
            -- Debug.chat(abilityEffectBonus)
            saveDc = saveDc + abilityEffectBonus
        end
    end
    return saveDc
end

local applyDamage
local function applyDamageWeaponEffect(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)
    -- Debug.chat(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)

    local targetNode = DB.findNode(rTarget.sCTNode)
    local startWounds = DB.getValue(targetNode, "wounds", 0)
    local startTempHp = DB.getValue(targetNode, "hptemp", 0)
    local startInjury = DB.getValue(targetNode, "injury", 0)

    applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)

    local endWounds = DB.getValue(targetNode, "wounds", 0)
    local endTempHp = DB.getValue(targetNode, "hptemp", 0)
    local endInjury = DB.getValue(targetNode, "injury", 0)

    if(startWounds < endWounds or startTempHp > endTempHp or startInjury < endInjury) then
        -- Debug.chat("Damage taken!")
        if(rSource and rSource.sType == "charsheet") then
            -- local decodedDamage = ActionDamage.decodeDamageText(nTotal, sDamage)
            local attackName = StringManager.trim(sDamage:match("%[DAMAGE[^]]*%] ([^[]+)"))
            local isCrit = sDamage:find("[CRITICAL]", 0, true)
            local sourceNode = DB.findNode(rSource.sCreatureNode)
            -- Debug.chat("From weapon", attackName)
            -- Debug.chat("Is Crit", isCrit)
            for _, weaponNode in pairs(DB.getChildren(sourceNode, "weaponlist")) do
                if DB.getValue(weaponNode, "name", "") == attackName then
                    -- Debug.chat("weapon found!", weaponNode)
                    for _, effectNode in pairs(DB.getChildren(weaponNode, "effectlist")) do
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
                                EffectManager.addEffect("", nil, targetNode, weaponEffect, true)
                            end
                        end
                    end
                end
            end
        end
    end
end

local applySave
local function applySaveWeaponEffect(rSource, rOrigin, rAction, sUser)
    applySave(rSource, rOrigin, rAction, sUser)
    
    -- Debug.chat(rSource, rOrigin, rAction, sUser)
    
    local saveResult = rAction.sSaveResult
    local effectNodePath
    if rAction.sSaveDesc then
        effectNodePath = rAction.sSaveDesc:match("%[WEAPON EFFECT:(.+)%]")
    end
    -- Debug.chat(saveResult, effectNodePath)
    if effectNodePath and (saveResult == "failure" or saveResult == "autofailure") then
        local targetNode = DB.findNode(rSource.sCTNode)
        local weaponEffect = parseWeaponEffect(DB.findNode(effectNodePath))
        -- Debug.chat(targetNode, weaponEffect)
        EffectManager.addEffect("", nil, targetNode, weaponEffect, true)
    end
end

function onInit()
    local extensions = {}
    for k, v in pairs(Extension.getExtensions()) do extensions[v] = k end
    Extension.extensions = extensions

    applyDamage = ActionDamage.applyDamage
    ActionDamage.applyDamage = applyDamageWeaponEffect

    applySave = ActionSave.applySave
    ActionSave.applySave = applySaveWeaponEffect
end
