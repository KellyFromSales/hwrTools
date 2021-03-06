namespace hohTools
{
    Upgrades::UpgradeShop@ m_shop;
    array<array<Upgrades::RecordUpgradeStep@>> m_tiers;


    [Hook]
    void GameModeConstructor(Campaign@ campaign)
    {
        AddFunction("k_skills", UnlockSkills);
        AddFunction("k_blacksmith", UnlockBlacksmithUpgrades);
        AddFunction("k_magic", UnlockMagicUpgrades);
        AddFunction("k_potion", UnlockPotionUpgrades);
        AddFunction("k_town_buildings", UnlockTownBuildings);
        AddFunction("k_flags", Flags);
        AddFunction("k_blueprints", GiveBlueprints);
        AddFunction("k_attunements", AttuneBlueprints);
        AddFunction("k_remove_blueprints", ResetBlueprints);
        AddFunction("k_remove_attunements", ResetAttunements);
        AddFunction("k_drinks", UnlockTavernDrinks);
        AddFunction("k_chapel", UnlockChapel);
        AddFunction("k_town", UnlockTownUpgrades);
        AddFunction("k_char", UnlockAllCharacterUpgrades);
        AddFunction("k_reset_char", ResetUpgrades);
        AddFunction("k_reset_town", ResetTown);
        AddFunction("k_accomplishments", UnlockAccomplishments); //rubii
        AddFunction("k_bestiary", UnlockBestiary); //rubii
        AddFunction("k_itemiary", UnlockItemiary); //rubii
        AddFunction("refresh", Refresh); // reloads so upgrades show, unlock all does it automatically
        AddFunction("refresh_modifiers", RefreshModifiers); // reloads modifiers
        AddFunction("k_all", UnlockAll);
        AddFunction("clear_drinks", clearDrinkscfunc);
        AddFunction("set_char_name", {cvar_type::String }, setCharNamefunc);
        AddFunction("sound", { cvar_type::String}, playSoundcfunc);
        AddFunction("go_to_act", {cvar_type::Int }, GoToAct);
        AddFunction("go_to_floor", {cvar_type::Int }, GoToFloor);
        AddFunction("give_blueprints", {cvar_type::Int }, GiveRandomBlueprintsCfunc);
        AddFunction("give_blood_rite", { cvar_type::String, cvar_type::Int }, GiveBloodAltarCfunc);
        AddFunction("fountain_deposit", {cvar_type::Int }, FountainDepositCfunc);
        AddFunction("old_gladiator",{ cvar_type::String, cvar_type::Int }, SetOldGladiatorCfunc);
        AddFunction("change_class", {cvar_type::String }, netChangeClasscfunc);
        AddFunction("spawn_unit", { cvar_type::String, cvar_type::Int }, spawnUnitcfunc);
        AddFunction("spawn_prefab", {cvar_type::String }, spawnPrefabcfunc);
        AddFunction("next_act", NextActCfunc);
        AddFunction("set_char_level", { cvar_type::Int }, SetLevel);
        AddFunction("attune_item", {cvar_type::String }, attuneItemcfunc);
        AddFunction("set_town_stat", { cvar_type::String, cvar_type::Int }, SetTownStatCFunc);
    }

    void SetTownStatCFunc(cvar_t@ arg0, cvar_t@ arg1)
    {
        auto gm = cast<Campaign>(g_gameMode);
            if (gm !is null)
            {
                auto statRecord = gm.m_townLocal.m_statistics.GetStat(arg0.GetString());
                if (statRecord !is null)
                    statRecord.m_valueInt = arg1.GetInt();

                auto statSession = gm.m_townLocal.m_statistics.GetStat(arg0.GetString());
                if (statSession !is null)
                    statSession.m_valueInt = arg1.GetInt();
            }
    }

    bool BuyItem(Upgrades::Upgrade@ upgrade, Upgrades::UpgradeStep@ step)
    {
        auto record = GetLocalPlayerRecord();
        auto player = GetLocalPlayer();
        OwnedUpgrade@ ownedUpgrade = record.GetOwnedUpgrade(upgrade.m_id);

        @ownedUpgrade = OwnedUpgrade();
        ownedUpgrade.m_id = upgrade.m_id;
        ownedUpgrade.m_idHash = upgrade.m_idHash;
        ownedUpgrade.m_level = step.m_level;
        @ownedUpgrade.m_step = step;
        record.upgrades.insertLast(ownedUpgrade);

        step.ApplyNow(record);

        (Network::Message("PlayerGiveUpgrade") << upgrade.m_id << step.m_level).SendToAll();

        return true;
    }

    void playSoundcfunc(cvar_t@ arg0)
    {
        SoundInstance@ pSound;
        auto record = GetLocalPlayerRecord();
        if (pSound !is null)
                    pSound.Stop();
        @pSound = (Resources::GetSoundEvent(arg0.GetString())).PlayTracked(record.actor.m_unit.GetPosition());
    }

    void UpgradeFunc(string shopName){
        // Debugging purposes
        //print("------ SHOP: " + shopName);
        @m_shop = cast<Upgrades::UpgradeShop>(Upgrades::GetShop(shopName));

        auto record = GetLocalPlayerRecord();
        auto player = GetLocalPlayer();

        for (uint i = 0; i < m_shop.m_upgrades.length(); i++)
        {
            auto upgrade = cast<Upgrades::UpgradeShop>(m_shop).m_upgrades[i];
            auto steps = m_shop.m_upgrades[i].m_steps.length();

            for(uint o = 0; o < steps; o++)
            {
                auto upgradeNextStep = upgrade.GetNextStep(record);
                if(upgradeNextStep is null)
                {
                    break;
                }
                    // Debugging purposes
                    // print("BUYING: " + upgrade.m_id + " step: " + o);

                if(shopName != "townhall")
                    {
                        BuyItem(upgrade, upgradeNextStep);
                    }
                    else
                    {
                        upgradeNextStep.BuyNow(record);
                    }

            }
        }
    }

    void Refresh()
    {
        ChangeLevel(GetCurrentLevelFilename());
    }

    void RefreshModifiers()
    {
    GetLocalPlayerRecord().RefreshModifiers();
    }

    void UnlockSkills()
    {
        UpgradeFunc("trainer");
    }

    void UnlockBlacksmithUpgrades()
    {
        UpgradeFunc("blacksmith");
    }

    void UnlockMagicUpgrades()
    {
        UpgradeFunc("magicshop");
    }

    void UnlockPotionUpgrades()
    {
        UpgradeFunc("apothecary");
    }

    void UnlockTownBuildings()
    {
        UpgradeFunc("townhall");
    }

    void UnlockTavernDrinks()
    {
        auto player = GetLocalPlayer();

        for (uint i = 0; i < g_tavernDrinks.length(); i++)
        {
            auto drink = g_tavernDrinks[i];
            GiveTavernBarrelImpl(drink, player, false);
        }
    }

    void UnlockChapel()
    {
        auto record = GetLocalPlayerRecord();

        @m_shop = cast<Upgrades::UpgradeShop>(Upgrades::GetShop("chapel"));

        for(uint i = 0; i < m_shop.m_upgrades.length(); i++)
        {
            record.chapelUpgradesPurchased.insertLast(m_shop.m_upgrades[i].m_id);
        }
    }

    void UnlockAll()
    {
        Flags();
        UnlockPotionUpgrades();
        UnlockMagicUpgrades();
        UnlockBlacksmithUpgrades();
        UnlockSkills();
        GiveBlueprints();
        AttuneBlueprints();
        UnlockTownBuildings();
        UnlockTavernDrinks();
        UnlockChapel();
        Refresh();
    }

    void UnlockAllCharacterUpgrades()
    {
        UnlockPotionUpgrades();
        UnlockMagicUpgrades();
        UnlockBlacksmithUpgrades();
        UnlockSkills();
        AttuneBlueprints();
        UnlockChapel();
        Refresh();
    }

    void UnlockTownUpgrades()
    {
        Flags();
        GiveBlueprints();
        UnlockTownBuildings();
        UnlockTavernDrinks();
        Refresh();
    }

    void Flags()
    {
        g_flags.Set("special_ore", FlagState::Town);
        g_flags.Set("unlock_apothecary", FlagState::Town);
        g_flags.Set("unlock_thief", FlagState::Town);
        g_flags.Set("unlock_combo", FlagState::Town);
        g_flags.Set("unlock_magicshop", FlagState::Town);
        g_flags.Set("unlock_anvil", FlagState::Town);
        g_flags.Set("unlock_gladiator", FlagState::Town);
        g_flags.Set("unlock_bestiary", FlagState::Town);
    }

    void ResetBlueprints()
    {
        auto gmCampaign = cast<Campaign>(g_gameMode);
        auto player = GetLocalPlayer();

        gmCampaign.m_townLocal.m_forgeBlueprints.removeRange(0, gmCampaign.m_townLocal.m_forgeBlueprints.length());
        player.m_record.itemForgeAttuned.removeRange(0, player.m_record.itemForgeAttuned.length());
    }

    void ResetAttunements()
    {
        auto player = GetLocalPlayer();
        player.m_record.itemForgeAttuned.removeRange(0, player.m_record.itemForgeAttuned.length());
    }


    void clearDrinkscfunc()
    {
        auto player = GetLocalPlayerRecord();
        player.tavernDrinks.removeRange(0, player.tavernDrinks.length());
    }


    void GiveBlueprints()
    {
        TownRecord@ town = null;
        auto gmMenu = cast<MainMenu>(g_gameMode);
        auto gmCampaign = cast<Campaign>(g_gameMode);
        auto player = GetLocalPlayer();

        player.m_record.itemForgeAttuned.removeRange(0, player.m_record.itemForgeAttuned.length());
        gmCampaign.m_townLocal.m_forgeBlueprints.removeRange(0, gmCampaign.m_townLocal.m_forgeBlueprints.length());

        if (gmMenu !is null)
            @town = gmMenu.m_town;
        else if (gmCampaign !is null)
            @town = gmCampaign.m_town;

        for (uint i = 0; i < g_items.m_allItemsList.length(); i++)
        {
            auto item = g_items.m_allItemsList[i];

            if (item.quality != ActorItemQuality::Epic && item.quality != ActorItemQuality::Legendary && item.hasBlueprints)
            {
                GiveForgeBlueprintImpl(item, player, false);
            }
        }
    }

    ActorItem@ RandomBlueprintPicker()
    {
        auto gm = cast<Campaign>(g_gameMode);
        array<ActorItem@> possibleBlueprintItems;

        for (uint i = 0; i < g_items.m_allItemsList.length(); i++)
        {
            auto item = g_items.m_allItemsList[i];

            if (!item.hasBlueprints)
                continue;

            if (gm.m_townLocal.m_forgeBlueprints.find(item.idHash) != -1)
                continue;

            possibleBlueprintItems.insertLast(item);
        }

        if (possibleBlueprintItems.length() > 0)
        return possibleBlueprintItems[randi(possibleBlueprintItems.length())];

        return null;
    }

    void GoToFloor(cvar_t@ arg0)
    {
        auto gm = cast<Campaign>(g_gameMode);
        DungeonPropertiesLevel@ currentLevel;
        gm.m_levelCount = (arg0.GetInt()-1);
        @currentLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
        ChangeLevel(currentLevel.m_filename);
    }

    void GoToAct(cvar_t@ arg0)
    {
        int t = (arg0.GetInt()-1);
        auto gm = cast<Campaign>(g_gameMode);
        DungeonPropertiesLevel@ nextLevel;
        switch (t)
        {
            case 0:
                gm.m_levelCount = 0;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 1:
                gm.m_levelCount = 4;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 2:
                gm.m_levelCount = 8;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 3:
                gm.m_levelCount = 12;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 4:
                gm.m_levelCount = 16;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 5:
                gm.m_levelCount = 19;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
            case 6:
                gm.m_levelCount = 21;
                @nextLevel = gm.m_dungeon.GetLevel(gm.m_levelCount);
                ChangeLevel(nextLevel.m_filename);
            break;
        }
    }


    void GiveRandomBlueprintsCfunc(cvar_t@ arg0)
    {
        auto player = GetLocalPlayer();

        auto gm = cast<Campaign>(g_gameMode);
        array<ActorItem@> possibleBlueprintItems;

        for (uint i = 0; i < g_items.m_allItemsList.length(); i++)
        {
            auto item = g_items.m_allItemsList[i];

            if (!item.hasBlueprints)
                continue;

            if (gm.m_townLocal.m_forgeBlueprints.find(item.idHash) != -1)
                continue;

            possibleBlueprintItems.insertLast(item);
        }

        int b = arg0.GetInt();
        int len = possibleBlueprintItems.length();
        if (arg0.GetInt() > len)
            b = possibleBlueprintItems.length();

        for (int i = 0; i < b; i++)
            {
                GiveForgeBlueprintImpl(RandomBlueprintPicker(), player, false);
            }
    }

    void AttuneBlueprints()
    {
        TownRecord@ town = null;
        auto gmMenu = cast<MainMenu>(g_gameMode);
        auto gmCampaign = cast<Campaign>(g_gameMode);
        auto player = GetLocalPlayer();

        if (gmMenu !is null)
            @town = gmMenu.m_town;
        else if (gmCampaign !is null)
            @town = gmCampaign.m_town;

        for (uint i = 0; i < town.m_forgeBlueprints.length(); i++)
        {
            auto item = g_items.GetItem(town.m_forgeBlueprints[i]);
            if (item.quality != ActorItemQuality::Epic && item.quality != ActorItemQuality::Legendary && item.hasBlueprints)
            {
                if (item.canAttune)
                {
                    player.AttuneItem(item);
                }
            }
        }
    }

    void attuneItemcfunc(cvar_t@ arg0)
    {
        auto player = GetLocalPlayer();
        if (player is null)
            return;
            auto item = g_items.TakeItem(arg0.GetString());
                if (item is null)
                {
                    print("No item '" + arg0.GetString() + "' found");
                    return;
                }

        player.AttuneItem(item);
    }

    void ResetUpgrades()
    {
        auto record = GetLocalPlayerRecord();
        auto gm = cast<Campaign>(g_gameMode);
        auto town = gm.m_townLocal;
        auto player = GetLocalPlayer();

        player.m_record.itemForgeAttuned.removeRange(0, player.m_record.itemForgeAttuned.length());
        record.upgrades.removeRange(0, record.upgrades.length());
        ChangeLevel(GetCurrentLevelFilename());
    }

    void ResetTown()
    {
        auto gm = cast<Campaign>(g_gameMode);
        auto town = gm.m_townLocal;

        town.m_buildings.removeRange(0, town.m_buildings.length());
        ChangeLevel(GetCurrentLevelFilename());
    }

    void GiveBloodAltarCfunc(cvar_t@ arg0, cvar_t@ arg1)
    {

        auto ply = GetLocalPlayer();
        auto reward = BloodAltar::GetReward(arg0.GetString());
            if (reward is null)
                {
                    print("you did it wrong");
                    return;
                }

        for (int i = 0; i < arg1.GetInt(); i++)
            {
                ply.m_record.bloodAltarRewards.insertLast(reward.idHash);
            }
        RefreshModifiers();

    }

    void FountainDepositCfunc(cvar_t@ arg0)
    {
        auto gm = cast<Town>(g_gameMode);
        if (gm is null)
            return;

        if (!Currency::CanAfford(arg0.GetInt()))
        {
            PrintError("Can't afford to deposit " + arg0.GetInt() + " gold into fountain!");
            return;
        }

        Stats::Add("fountain-deposited", arg0.GetInt(), GetLocalPlayerRecord());

        Currency::Spend(arg0.GetInt());
        gm.m_town.m_fountainGold += arg0.GetInt();

        if (Network::IsServer())
            gm.m_townLocal.m_fountainGold += arg0.GetInt();

        (Network::Message("DepositFountain") << arg0.GetInt()).SendToAll();
    }


    void SetOldGladiatorCfunc(cvar_t@ arg0, cvar_t@ arg1)
    {
        auto record = GetLocalPlayerRecord();

        if (arg0.GetString() == "attack-power") record.retiredAttackPower = record.retiredAttackPower + arg1.GetInt();
        else if (arg0.GetString() == "skill-power") record.retiredSkillPower = record.retiredSkillPower + arg1.GetInt();
        else if (arg0.GetString() == "armor") record.retiredArmor = record.retiredArmor + arg1.GetInt();
        else if (arg0.GetString() == "resistance") record.retiredResistance = record.retiredResistance + arg1.GetInt();
        else print("you typed it wrong");

        record.RefreshModifiers();
    }

    void netChangeClasscfunc(cvar_t@ arg0)
    {
        auto record = GetLocalPlayerRecord();
        auto player = cast<Player>(record.actor);
        record.charClass = arg0.GetString();
        player.Initialize(record);
        (Network::Message("PlayerChangeClass") << arg0.GetString()).SendToAll();
    }

    void setCharNamefunc(cvar_t@ arg0)
    {
        auto record = GetLocalPlayerRecord();
        record.name = arg0.GetString();
        SValueBuilder builder;
        builder.PushDictionary();
        builder.PushString("name", record.name);
    }

    void spawnUnitcfunc(cvar_t@ arg0, cvar_t@ arg1)
    {
        auto player = GetLocalPlayer();
        auto pos = player.m_unit.GetPosition();
        pos.x += 10;
        pos.y += 10;
        UnitProducer@ fallback = null;
        @fallback = Resources::GetUnitProducer(arg0.GetString());
        if(fallback !is null)
            {
                for (int i = 0; i < arg1.GetInt(); i++)
                {
                 QueuedTasks::Queue(1, SpawnUnitBaseTask(fallback, xy(pos), "", 0, 0, UnitPtr(), 1.0f, 0));
                }
            return;
            }
        print("null");
    }

    void spawnPrefabcfunc(cvar_t@ arg0)
    {
        auto player = GetLocalPlayer();
        auto pos = player.m_unit.GetPosition();
        Prefab@ fallback = null;
        @fallback = Resources::GetPrefab(arg0.GetString());
        if(fallback !is null)
        {
            QueuedTasks::Queue(1, SpawnPrefabBaseTask(fallback, xy(pos), true));
            return;
        }
        print("null");

    }

    void NextActCfunc()
    {
        if (!Network::IsServer())
            return;

        auto script = WorldScript::LevelExitNextAct();
        script.ServerExecute();
    }

    void SetLevel(cvar_t@ arg0)
    {
        auto record = GetLocalPlayerRecord();
        record.level = arg0.GetInt();
    }


    void UnlockAccomplishments() // You must use this while in a combat zone (e.g. Forsaken Tower), otherwise not all stats will be updated correctly
    {
        TownRecord@ town = null;

        auto gm = cast<Campaign>(g_gameMode);
        if (gm is null)
        {
            return;
        }
        @town = gm.m_townLocal;

        // Stats
        for (uint i = 0; i < town.m_statistics.m_stats.length(); i++)
        {
            auto stat = town.m_statistics.m_stats[i];

            uint numAccomplishments = stat.m_accomplishments.length();
            if (numAccomplishments > 0)
            {
                //print("name=" + stat.m_name + ", numAccomplishments=" + numAccomplishments + ", currVal=" + stat.m_valueInt + ", newVal=" + stat.m_accomplishments[numAccomplishments - 1].m_value);
                Stats::Max(stat.m_name, stat.m_accomplishments[numAccomplishments - 1].m_value, GetLocalPlayerRecord());
            }
        }

        // Bosses
        for (uint i = 0; i < town.m_bossesKilled.length(); i++)
        {
            town.m_bossesKilled[i] = 0b111111111;
        }
    }
    
    void UnlockBestiary()
    {
        TownRecord@ town = null;

        auto gm = cast<Campaign>(g_gameMode);
        if (gm is null)
        {
            return;
        }
        @town = gm.m_townLocal;
        auto bestiary = town.m_bestiary;

        for (uint i = 0; i < allUnits.length(); i++)
        {
            auto prod = Resources::GetUnitProducer(allUnits[i]);
            if ((prod !is null) && (prod.GetBehaviorParams() !is null))
            {
                for (uint j = 0; j < bestiary.length(); j++)
                {
                    if (bestiary[j].m_producer is prod)
                    {
                        return;
                    }
                }
                bestiary.insertLast(BestiaryEntry(prod, 1, 0));
            }
        }
    }

    // scripts/Town/TownRecord.as
    void UnlockItemiary()
    {
        TownRecord@ town = null;

        auto gm = cast<Campaign>(g_gameMode);
        if (gm is null)
        {
            return;
        }
        @town = gm.m_townLocal;
        auto itemiary = town.m_itemiary;

        for (uint i = 0; i < g_items.m_allItemsList.length(); i++)
        {
            auto item = g_items.m_allItemsList[i];
            for (uint j = 0; j < itemiary.length(); j++)
            {
                if (itemiary[j].m_item is item)
                {
                    return;
                }
            }
            itemiary.insertLast(ItemiaryEntry(item, 1));
        }
    }

}