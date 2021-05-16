--
-- handles weapon effects
--
--

function onInit()
    local node = getDatabaseNode()
    local nodeItem = DB.getChild(node, "...")
    -- set name of effect to name of item so when effect
    -- is applied to someone it shows where it came from properly
    local sName = DB.getValue(nodeItem,"name","")
    name.setValue(sName)

    -- watch these variables and update display string if they change
    DB.addHandler(DB.getPath(node, ".effect"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".durdice"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".durmod"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".durunit"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".visibility"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".critonly"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".savetype"),"onUpdate", update)
    DB.addHandler(DB.getPath(node, ".savedcmod"),"onUpdate", update)
    update();
end

function onClose()
    local node = getDatabaseNode()
    DB.removeHandler(DB.getPath(node, ".effect"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".durdice"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".durmod"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".durunit"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".visibility"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".critonly"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".savetype"),"onUpdate", update)
    DB.removeHandler(DB.getPath(node, ".savedcmod"),"onUpdate", update)
end

-- update display string 
function update()
    local node = getDatabaseNode();
    -- display dice/mods for duration --celestian
    local sDuration = "";
    local dDurationDice = DB.getValue(node, "durdice");
    local nDurationMod = DB.getValue(node, "durmod", 0);
    local sDurDice = StringManager.convertDiceToString(dDurationDice);
    if (sDurDice ~= "") then 
        sDuration = sDuration .. sDurDice;
    end
    if (nDurationMod ~= 0 and sDurDice ~= "") then
        local sSign = "+";
        if (nDurationMod < 0) then
            sSign = "";
        end
        sDuration = sDuration .. sSign .. nDurationMod;
    elseif (nDurationMod ~= 0) then
        sDuration = sDuration .. nDurationMod;
    end
    
    local sUnits = DB.getValue(node, "durunit", "");
    if sDuration ~= "" then
        --local nDuration = tonumber(sDuration);
        local bMultiple = (sDurDice ~= "") or (nDurationMod > 1);
        if sUnits == "minute" then
            sDuration = sDuration .. " minute"; -- 5e uses minutes, not turns!
        elseif sUnits == "hour" then
            sDuration = sDuration .. " hour";
        elseif sUnits == "day" then
            sDuration = sDuration .. " day";
        else
            sDuration = sDuration .. " rnd";
        end
            if (bMultiple) then
                sDuration = sDuration .. "s";
            end
    end
    local sCritOnly = "[ON CRIT] ";
    local bCritOnly = (DB.getValue(node, "critonly", 0) ~= 0);
    if (not bCritOnly) then
        sCritOnly = "";
    end
    local sEffect = "[" .. DB.getValue(node, "effect", "") .. "] "
    local sVis = DB.getValue(node, "visibility","");
    if (sVis ~= "") then
        sVis = " visibility [" .. sVis .. "]";
    end
    if (sDuration ~= "") then
        sDuration = "[" .. sDuration .. "] ";
    end

    local sSaveType = WeaponEffects.getSaveTypeString(DB.getValue(node, "savetype", ""))
    local sSaveDC = DB.getValue(node, "savedcmod", 0)
    local saveString = ""
    if(sSaveType ~= "" and sSaveDC > 0) then
        saveString = "[" .. sSaveType .. " DC " .. sSaveDC .. "] "
    end

    local sFinal =  sCritOnly .. saveString .. sEffect .. sDuration .. sVis;
    effect_description.setValue(sFinal);
end