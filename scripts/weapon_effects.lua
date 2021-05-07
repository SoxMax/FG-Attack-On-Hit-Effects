local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
};

local function parseWeaponEffect(effectNode)
    local rEffect = {};
	-- rEffect.nDuration = DB.getValue(effect, "duration", 0);
	-- rEffect.sUnits = DB.getValue(effect, "unit", "");
	-- rEffect.nInit = DB.getValue(effect, "init", 0);
	-- rEffect.sSource = sourceNode.getPath();
	-- rEffect.nGMOnly = DB.getValue(effect, "isgmonly", 0);
	-- rEffect.sLabel = applyLabel;
	-- rEffect.sName = applyLabel;

    local _, recordname = DB.getValue(effectNode.getChild("..."), "shortcut")
    
	rEffect.nDuration = 1
	rEffect.sUnits = "rnd"
	rEffect.nInit = 0
	rEffect.sSource = recordname or effectNode.getChild(".....").getPath() or ""
	rEffect.nGMOnly = 0
	rEffect.sLabel = DB.getValue(effectNode, "effect")
	rEffect.sName = DB.getValue(effectNode, "effect")
    return rEffect
end

local applyDamage
local function applyWeaponEffectOnDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)
    -- Debug.chat(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)

    local targetNode = DB.findNode(rTarget.sCTNode)
    local startWounds = DB.getValue(targetNode, "wounds", 0)
    local startTempHp = DB.getValue(targetNode, "hptemp", 0)

    applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal)

    local endWounds = DB.getValue(targetNode, "wounds", 0)
    local endTempHp = DB.getValue(targetNode, "hptemp", 0)

    if(startWounds < endWounds or startTempHp > endTempHp) then
        Debug.chat("Damage taken!")
        if(rSource.sType == "charsheet") then
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
