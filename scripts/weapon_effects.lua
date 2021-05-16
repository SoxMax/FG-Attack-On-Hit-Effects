
function checkPlayerVisibility(sVisibility, nIdentified)
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
    local _, recordname = DB.getValue(effectNode.getChild("..."), "shortcut")

	rEffect.nDuration = rollDice(DB.getValue(effectNode, "durdice"), DB.getValue(effectNode, "durmod", 0))
	rEffect.sUnits = DB.getValue(effectNode, "durunit", "")
	rEffect.nInit = 0
	rEffect.sSource = recordname or effectNode.getChild(".....").getPath() or ""
	rEffect.nGMOnly = checkPlayerVisibility(DB.getValue(effectNode, "visibility", ""), 1)
	rEffect.sLabel = DB.getValue(effectNode, "effect")
	rEffect.sName = DB.getValue(effectNode, "effect")
	rEffect.bCritOnly = DB.getValue(effectNode, "critonly", 0)
	rEffect.sSaveType = DB.getValue(effectNode, "savetype")
	rEffect.nSaveDc = DB.getValue(effectNode, "savedcmod", 0)
    return rEffect
end

local function generateSaveDescription(attackName, saveType, saveDc, effectNodePath)
    local saveString = ""
    if saveType == "fortitude" then
		saveString = "FORT"
	elseif saveType == "reflex" then
		saveString = "REF"
	elseif saveType == "will" then
		saveString = "WILL"
	end
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

local applyDamage
local function applyDamageWeaponEffect(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)
    -- Debug.chat(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)

    local targetNode = DB.findNode(rTarget.sCTNode)
    local startWounds = DB.getValue(targetNode, "wounds", 0)
    local startTempHp = DB.getValue(targetNode, "hptemp", 0)

    applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)

    local endWounds = DB.getValue(targetNode, "wounds", 0)
    local endTempHp = DB.getValue(targetNode, "hptemp", 0)

    if(startWounds < endWounds or startTempHp > endTempHp) then
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
                            local saveDc = weaponEffect.nSaveDc
                            -- Debug.chat(saveType, saveDc)
                            if saveType and saveDc > 0 then
                                local saveDescription = generateSaveDescription(attackName, saveType, saveDc, effectNode.getNodeName())
                                ActionSave.performVsRoll(nil, rTarget, saveType, saveDc, weaponEffect.nGMOnly, rSource, false, saveDescription, "")
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
    local effectNodePath = rAction.sSaveDesc:match("%[WEAPON EFFECT:(.+)%]")
    -- Debug.chat(saveResult, effectNodePath)
    if effectNodePath and (saveResult == "failure" or saveResult == "autofailure") then
        local targetNode = DB.findNode(rSource.sCTNode)
        local weaponEffect = parseWeaponEffect(DB.findNode(effectNodePath))
        -- Debug.chat(targetNode, weaponEffect)
        EffectManager.addEffect("", nil, targetNode, weaponEffect, true)
    end
end

function onInit()
    applyDamage = ActionDamage.applyDamage
    ActionDamage.applyDamage = applyDamageWeaponEffect

    applySave = ActionSave.applySave
    ActionSave.applySave = applySaveWeaponEffect
end
