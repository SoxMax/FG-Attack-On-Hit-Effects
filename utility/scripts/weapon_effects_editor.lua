
function onInit()
    if Extension.extensions["Full OverlayPackage"] or Extension.extensions["Full OverlayPackage with alternative icons"] then
        header_othertags.setVisible(true)
        othertags.setVisible(true)
    end

    local node = getDatabaseNode();
    --DB.getValue(node,"save_type","modifier");
    -- if npc and no effect yet then we set the 
    -- visibility default to hidden
    if (node.getPath():match("^npc%.id%-%d+")) then
        local sVisibility = DB.getValue(node,"visibility");
        local sEffectString = DB.getValue(node,"effect");
        if (sVisibility == "" and sEffectString == "") then
            DB.setValue(node,"visibility","string","hide");
        end
    end
end
