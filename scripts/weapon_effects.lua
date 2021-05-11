local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
};

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

	rEffect.nDuration = rollDice(DB.getValue(effectNode, "durdice"), DB.getValue(effectNode, "durmod", 1))
	rEffect.sUnits = DB.getValue(effectNode, "durunit", "")
	rEffect.nInit = 0
	rEffect.sSource = recordname or effectNode.getChild(".....").getPath() or ""
	rEffect.nGMOnly = checkPlayerVisibility(DB.getValue(effectNode, "visibility", ""), 1)
	rEffect.sLabel = DB.getValue(effectNode, "effect")
	rEffect.sName = DB.getValue(effectNode, "effect")
    return rEffect
end

local applyDamage
local function applyWeaponEffectOnDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)
    -- Debug.chat(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)

    local targetNode = DB.findNode(rTarget.sCTNode)
    local startWounds = DB.getValue(targetNode, "wounds", 0)
    local startTempHp = DB.getValue(targetNode, "hptemp", 0)

    applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, ...)

    local endWounds = DB.getValue(targetNode, "wounds", 0)
    local endTempHp = DB.getValue(targetNode, "hptemp", 0)

    if(startWounds < endWounds or startTempHp > endTempHp) then
        Debug.chat("Damage taken!")
        if(rSource and rSource.sType == "charsheet") then
            local attackName = StringManager.trim(sDamage:match("%b[] (.+) %b[]"):gsub("%b[]", ""))
            local sourceNode = DB.findNode(rSource.sCreatureNode)
            Debug.chat("From weapon", attackName)
            for _, weaponNode in pairs(DB.getChildren(sourceNode, "weaponlist")) do
                if DB.getValue(weaponNode, "name", "") == attackName then
                    Debug.chat("weapon found!", weaponNode)
                    for _, effectNode in pairs(DB.getChildren(weaponNode, "effectlist")) do
                        local newEffect = parseWeaponEffect(effectNode)
                        Debug.chat(newEffect)
                        EffectManager.addEffect("", nil, targetNode, newEffect, true)
                    end
                end
            end
        end
    end
end

function onInit()
    applyDamage = ActionDamage.applyDamage
    ActionDamage.applyDamage = applyWeaponEffectOnDamage
end
