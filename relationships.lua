-- Relationships code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Gift and relationship system
---------------------------------------------------------------------------------------
-- Each NPCs has 2 favorite and 2 disliked items. These items are chosen at spawn
-- time and will be re-chosen when the age changes (from child to adult, for example).
-- The items are chosen from the npc.FAVORITE_ITEMS table, and depends on gender and age.
-- A player, via right-click, or another NPC, can gift an item to a NPC. In the case
-- of the player, the player will give one of the currently wielded item. Gifts can be
-- given only once per some time period, the NPC will reject the given item if still 
-- the period isn't over.
-- If the NPC is neutral on the item (meanining it's neither favorite or disliked), it 
-- is possible it will not accept it, and the relationship the giver has with the NPC
-- will be unchanged.
-- In the other hand, if the item given its a favorite, the relationship points the NPC
-- has with giver will increase by a given amount, depending on favoriteness. Favorite 1
-- will increase the relationship by 2 * npc.ITEM_GIFT_EFFECT, and favorite 2 only by
-- npc.ITEM_GIFT_EFFECT. Similarly, if the item given is a disliked item, the NPC will
-- not take it, and its relationship points with the giver will decrease by 2 or 1 times
-- npc.ITEM_GIFT_EFFECT.

local S = mobs.intllib

npc.relationships = {}

-- Constants
npc.relationships.ITEM_GIFT_EFFECT = 2.5

-- Expected values for these are 720 each respectively
npc.relationships.GIFT_TIMER_INTERVAL = 360
npc.relationships.RELATIONSHIP_DECREASE_TIMER_INTERVAL = 720

npc.relationships.RELATIONSHIP_PHASE = {}
-- Define phases
npc.relationships.RELATIONSHIP_PHASE["phase1"] = {limit = 10}
npc.relationships.RELATIONSHIP_PHASE["phase2"] = {limit = 25}
npc.relationships.RELATIONSHIP_PHASE["phase3"] = {limit = 45}
npc.relationships.RELATIONSHIP_PHASE["phase4"] = {limit = 70}
npc.relationships.RELATIONSHIP_PHASE["phase5"] = {limit = 100}

npc.relationships.GIFT_ITEM_LIKED = "liked"
npc.relationships.GIFT_ITEM_DISLIKED = "disliked"
npc.relationships.GIFT_ITEM_HINT = "hint"
npc.relationships.GIFT_ITEM_RESPONSE = "response"

-- Favorite and disliked items tables
npc.relationships.gift_items = {
    liked = {
        female = {
            ["phase1"] = {},
            ["phase2"] = {},
            ["phase3"] = {},
            ["phase4"] = {},
            ["phase5"] = {},
            ["phase6"] = {}
        },
        male = {
            ["phase1"] = {},
            ["phase2"] = {},
            ["phase3"] = {},
            ["phase4"] = {},
            ["phase5"] = {},
            ["phase6"] = {}
        }
    },
    disliked = {
        female = {},
        male = {}
    }
}

npc.relationships.DEFAULT_RESPONSE_NO_GIFT_RECEIVE =
"Thank you, but I don't need anything for now."

-- Married NPC dialogue definition
npc.relationships.MARRIED_NPC_DIALOGUE = {
    text = "Hi darling!",
    is_married_dialogue = true,
    responses = {
        [1] = {
            text = "Let's talk!",
            action_type = "function",
            response_id = 1,
            action = function(self, player)
                npc.start_dialogue(self, player, false)
            end
        },
        [2] = {
            text = "Honey, can you wait for me here?",
            action_type = "function",
            response_id = 2,
            action = function(self, player)
                self.order = "stand"
                npc.chat(self.npc_name, player:get_player_name(),
                    S("Ok dear, I will wait here for you."))
            end
        },
        [3] = {
            text = "Please, come with me!",
            action_type = "function",
            response_id = 3,
            action = function(self, player)
                self.order = "follow"
                npc.chat(self.npc_name, player:get_player_name(), S("Ok, let's go!"))
            end
        }
    }
}

-- Function to get relationship phase
function npc.relationships.get_relationship_phase_by_points(points)
    if points > npc.relationships.RELATIONSHIP_PHASE["phase5"].limit then
        return "phase6"
    elseif points > npc.relationships.RELATIONSHIP_PHASE["phase4"].limit then
        return "phase5"
    elseif points > npc.relationships.RELATIONSHIP_PHASE["phase3"].limit then
        return "phase4"
    elseif points > npc.relationships.RELATIONSHIP_PHASE["phase2"].limit then
        return "phase3"
    elseif points > npc.relationships.RELATIONSHIP_PHASE["phase1"].limit then
        return "phase2"
    else
        return "phase1"
    end
end

-- Registration functions
-----------------------------------------------------------------------------
-- Items can be registered to be part of the gift system using the
-- below function. The def is the following:
--  {
--  	dialogues = {
--			liked = {
--			-- ^ This is an array of the following table:
--				[1] = {dialogue_type="", gender="", text=""}
--				-- ^ dialogue_type: defines is this is a hint or a response.
--				--		   valid values are: "hint", "response"
--				--   gender: valid values are: "male", female"
--				--   text: the dialogue text
--			},
--			disliked = {
--			-- ^ This is an array with the same type of tables as above
--			}
--		}
--  }

function npc.relationships.register_favorite_item(item_name, phase, gender, def)
    local dialogues = {}
    -- Register dialogues based on the hints and responses
    -- Liked
    for i = 1, #def.hints do
        table.insert(dialogues, {
            text = def.hints[i],
            tags = {phase, item_name, gender,
                npc.dialogue.tags.GIFT_ITEM_HINT, npc.dialogue.tags.GIFT_ITEM_LIKED}
        })
    end
    for i = 1, #def.responses do
        table.insert(dialogues, {
            text = def.responses[i],
            tags = {phase, item_name, gender,
                npc.dialogue.tags.GIFT_ITEM_RESPONSE, npc.dialogue.tags.GIFT_ITEM_LIKED}
        })
    end
    -- Register all dialogues
    for i = 1, #dialogues do
        npc.dialogue.register_dialogue(dialogues[i])
    end

    -- Insert item into table
    table.insert(npc.relationships.gift_items.liked[gender][phase], item_name)
end

function npc.relationships.register_disliked_item(item_name, gender, def)
    local dialogues = {}
    -- Register dialogues based on the hints and responses
    -- Liked
    for i = 1, #def.hints do
        table.insert(dialogues, {
            text = def.hints[i],
            tags = {item_name, gender,
                npc.dialogue.tags.GIFT_ITEM_HINT, npc.dialogue.tags.GIFT_ITEM_UNLIKED}
        })
    end
    for i = 1, #def.responses do
        table.insert(dialogues, {
            text = def.responses[i],
            tags = {item_name, gender,
                npc.dialogue.tags.GIFT_ITEM_RESPONSE, npc.dialogue.tags.GIFT_ITEM_UNLIKED}
        })
    end
    -- Register all dialogues
    for i = 1, #dialogues do
        npc.dialogue.register_dialogue(dialogues[i])
    end

    -- Insert item into table
    table.insert(npc.relationships.gift_items.disliked[gender], item_name)
end


function npc.relationships.get_dialogues_for_gift_item(item_name, dialogue_type, item_type, gender, phase)
    local tags = {
        [1] = item_name,
        [2] = dialogue_type,
        [3] = item_type,
        [4] = gender
    }
    if phase ~= nil then
        tags[5] = phase
    end
    npc.log("DEBUG","Searching with tags: "..dump(tags))

    return npc.dialogue.search_dialogue_by_tags(tags, true)
end

-- Returns the response message for a given item
function npc.relationships.get_response_for_favorite_item(item_name, gender, phase)
    local items = npc.FAVORITE_ITEMS.female
    if gender == npc.MALE then
        items = npc.FAVORITE_ITEMS.male
    end

    for i = 1, #items[phase] do
        if items[phase][i].item == item_name then
            return items[phase][i].response
        end
    end
    return nil
end

-- Returns the response message for a disliked item
function npc.relationships.get_response_for_disliked_item(item_name, gender)
    local items = npc.DISLIKED_ITEMS.female
    if gender == npc.MALE then
        items = npc.DISLIKED_ITEMS.male
    end

    for i = 1, #items do
        minetest.log(dump(items[i]))
        if items[i].item == item_name then
            --minetest.log("Returning: "..dump(items[i].response))
            return items[i].response
        end
    end
    return nil
end

-- Gets the item hint for a favorite item
function npc.relationships.get_hint_for_favorite_item(item_name, gender, phase)
    for i = 1, #npc.FAVORITE_ITEMS[gender][phase] do
        if npc.FAVORITE_ITEMS[gender][phase][i].item == item_name then
            return npc.FAVORITE_ITEMS[gender][phase][i].hint
        end
    end
    return nil
end

-- Gets the item hint for a disliked item
function npc.relationships.get_hint_for_disliked_item(item_name, gender)
    for i = 1, #npc.DISLIKED_ITEMS[gender] do
        if npc.DISLIKED_ITEMS[gender][i].item == item_name then
            return npc.DISLIKED_ITEMS[gender][i].hint
        end
    end
    return nil
end


-- Relationship functions
-----------------------------------------------------------------------------

-- This function selects two random items from the npc.favorite_items table
-- It checks for gender and phase for choosing the items
function npc.relationships.select_random_favorite_items(gender, phase)
    local result = {}
    local items = {}

    -- -- Filter gender
    -- if gender == npc.FEMALE then
    --   items = npc.FAVORITE_ITEMS.female
    -- else
    --   items = npc.FAVORITE_ITEMS.male
    -- end

    -- Select the phase
    -- items = items[phase]
    items = npc.relationships.gift_items.liked[gender][phase]
    if items and next(items) ~= nil then
        result.fav1 = items[math.random(1, #items)]
        result.fav2 = items[math.random(1, #items)]
    end
    return result
end

-- This function selects two random items from the npc.disliked_items table
-- It checks for gender for choosing the items. They stay the same for all
-- phases
function npc.relationships.select_random_disliked_items(gender)
    local result = {}
    local items = {}

    -- -- Filter gender
    -- if gender == npc.FEMALE then
    --   items = npc.DISLIKED_ITEMS.female
    -- else
    --   items = npc.DISLIKED_ITEMS.male
    -- end
    items = npc.relationships.gift_items.disliked[gender]
    if items and next(items) ~= nil then
        result.dis1 = items[math.random(1, #items)]
        result.dis2 = items[math.random(1, #items)]
    end
    return result
end

-- Creates a relationship with a given player or NPC
local function create_relationship(self, clicker_name)
    local count = #self.relationships
    self.relationships[count + 1] = {
        -- Player or NPC name with whom the relationship is with
        name = clicker_name,
        -- Relationship points
        points = 0,
        -- Relationship phase, used for items and for phrases
        phase = "phase1",
        -- How frequent can the NPC receive a gift
        gift_interval = npc.relationships.GIFT_TIMER_INTERVAL,
        -- Current timer count since last gift
        gift_timer_value = 0,
        -- The amount of time without providing gift or talking that will decrease relationship points
        relationship_decrease_interval = npc.relationships.RELATIONSHIP_DECREASE_TIMER_INTERVAL,
        -- Current timer count for relationship decrease
        relationship_decrease_timer_value = 0,
        -- Current timer count since last time player talked to NPC
        talk_timer_value = 0
    }
end

-- Returns a relationship points
local function get_relationship_points(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            return self.relationships[i].points
        end
    end
    return nil
end

-- Updates relationship with given points
local function update_relationship(self, clicker_name, modifier)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            self.relationships[i].points = self.relationships[i].points + modifier
            local current_phase = self.relationships[i].phase
            self.relationships[i].phase =
            npc.relationships.get_relationship_phase_by_points(self.relationships[i].points)
            if current_phase ~= self.relationships[i].phase then
                -- Re-select favorite items per new phase
                self.gift_data.favorite_items =
                npc.relationships.select_random_favorite_items(self.gender, self.relationships[i].phase)
                -- Re-select dialogues per new
                self.dialogues =
                npc.dialogue.select_random_dialogues_for_npc(self,
                    self.relationships[i].phase)
                return true
            end
            return false
        end
    end
    -- Relationship not found, huge error
    return nil
end

-- Checks if a relationship with given player or NPC exists
local function check_relationship_exists(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            return true
        end
    end
    return false
end

-- Returns the relationship phase given the name of the player
function npc.relationships.get_relationship_phase(self, clicker_name)
    for i = 1, #self.relationships do
        if clicker_name == self.relationships[i].name then
            return self.relationships[i].phase
        end
    end
    return nil
end

-- Checks if NPC can receive gifts
local function check_npc_can_receive_gift(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            -- Checks avoid married NPC to receive from others
            if self.is_married_to == nil
                    or (self.is_married ~= nil and self.is_married_to == clicker_name) then
                return self.relationships[i].gift_timer_value >= self.relationships[i].gift_interval
            else
                return false
            end
        end
    end
    -- Not found
    return nil
end

-- Checks if relationship can be updated by talking
local function check_relationship_by_talk_timer_ready(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            return self.relationships[i].talk_timer_value >= self.relationships[i].gift_interval
        end
    end
    -- Not found
    return nil
end

-- Resets the gift timer
local function reset_gift_timer(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            self.relationships[i].gift_timer_value = 0
            self.relationships[i].relationship_decrease_timer_value = 0
            return
        end
    end
end

-- Resets the talk timer
local function reset_talk_timer(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            self.relationships[i].talk_timer_value = 0
            return
        end
    end
end

-- Resets the relationshop decrease timer
local function reset_relationship_decrease_timer(self, clicker_name)
    for i = 1, #self.relationships do
        if self.relationships[i].name == clicker_name then
            self.relationships[i].relationship_decrease_timer_value = 0
            return
        end
    end
end

-- Gifts functions
---------------------------------------------------------------------------------------

-- Displays message and hearts depending on relationship level
local function show_receive_gift_reaction(self, item_name, modifier, clicker_name, phase_change)
    local points = get_relationship_points(self, clicker_name)

    local pos = self.object:getpos()
    -- Positive modifier (favorite items) reactions
    if modifier >= 0 then
        local phase = npc.relationships.get_relationship_phase_by_points(points)
        if phase == "phase3" then
            npc.effect({x = pos.x, y = pos.y + 1, z = pos.z}, 2, "heart.png")
        elseif phase == "phase4" then
            npc.effect({x = pos.x, y = pos.y + 1, z = pos.z}, 4, "heart.png")
        elseif phase == "phase5" then
            npc.effect({x = pos.x, y = pos.y + 1, z = pos.z}, 6, "heart.png")
        elseif phase == "phase6" then
            npc.effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "heart.png")
        end
        if phase_change then
            local number_code = phase:byte(phase:len()) - 1
            phase = "phase"..string.char(number_code)
        end
        -- Send message
        -- TODO: There might be an error with getting the message...
        --minetest.log("Item_name: "..dump(item_name)..", gender: "..dump(self.gender)..", phase: "..dump(phase))
        local dialogues_found = npc.relationships.get_dialogues_for_gift_item(
            item_name,
            npc.dialogue.tags.GIFT_ITEM_RESPONSE,
            npc.dialogue.tags.GIFT_ITEM_LIKED,
            self.gender,
            phase)
        for _, item_dialogue in pairs(dialogues_found) do
            npc.chat(self.npc_name, clicker_name, item_dialogue.text)
        end
        -- Disliked items reactions
    elseif modifier < 0 then
        npc.effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "default_item_smoke.png")
        --minetest.log("Item name: "..item_name..", gender: "..self.gender)
        -- There should be only one dialogue, however, it returns a key-value
        -- result where we will have to do one loop
        local dialogues_found = npc.relationships.get_dialogues_for_gift_item(
            item_name,
            npc.dialogue.tags.GIFT_ITEM_RESPONSE,
            npc.dialogue.tags.GIFT_ITEM_UNLIKED,
            self.gender)
--        minetest.log("Message: "..dump(message_to_send))
        for _, item_dialogue in pairs(dialogues_found) do
            npc.chat(self.npc_name, clicker_name, item_dialogue.text)
        end
    end

end

-- Receive gift function; applies relationship points as explained above
-- Also, creates a relationship object if not present
function npc.relationships.receive_gift(self, clicker)
    -- Return if clicker is not offering an item
    local item = npc.get_entity_wielded_item(clicker)
    if item:get_name() == "" then return false end

    -- Get clicker name
    local clicker_name = npc.get_entity_name(clicker)

    -- Create relationship if it doesn't exists
    if check_relationship_exists(self, clicker_name) == false then
        create_relationship(self, clicker_name)
    end

    -- If NPC received a gift from this person, then reject any more gifts for now
    if check_npc_can_receive_gift(self, clicker_name) == false then
        npc.chat(self.npc_name, clicker_name, "Thanks, but I don't need anything for now")
        return false
    end

    -- If NPC is ready for marriage, do no accept anything else but the ring,
    -- and that with only a certain chance. The self.owner is to whom is married
    -- this NPC... he he.
    if get_relationship_points(self, clicker_name) >=
            npc.relationships.RELATIONSHIP_PHASE["phase5"].limit
            and self.owner ~= clicker_name
            and item:get_name() ~= "advanced_npc:marriage_ring" then
        npc.chat(self.npc_name, clicker_name,
            "Thank you my love, but I think that you have given me")
        npc.chat(self.npc_name, clicker_name,
            "enough gifts for now. Maybe we should go a step further")
        -- Reset gift timer
        reset_gift_timer(self, clicker_name)
        return true
    elseif get_relationship_points(self, clicker_name) >=
            npc.relationships.RELATIONSHIP_PHASE["phase5"].limit
            and item:get_name() == "advanced_npc:marriage_ring" then
        -- If the player/entity is offering a marriage ring, then NPC will accept with a 50%
        -- chance to marry the clicker
        local receive_chance = math.random(1, 10)
        -- Receive ring and get married
        if receive_chance < 6 then
            npc.chat(self.npc_name, clicker_name,
                "Oh, oh you make me so happy! Yes! I will marry you!")
            -- Get ring
            item:take_item()
            clicker:set_wielded_item(item)
            -- TODO: Implement marriage event
            -- Show marriage reaction
            local pos = self.object:getpos()
            effect({x = pos.x, y = pos.y + 1, z = pos.z}, 20, "heart.png", 4)
            -- Give 100 points, so NPC is really happy on marriage
            update_relationship(self, clicker_name, 100)
            -- This sets the married state, for now. Hehe
            self.owner = clicker_name
            -- Reject ring for now
        else
            npc.chat(self.npc_name, clicker_name,
                "Dear, I feel the same as you. But maybe not yet...")
        end
        -- Reset gift timer
        reset_gift_timer(self, clicker_name)
        return true
    end
    -- Marriage gifts: except for disliked items, all product a 0.5 * npc.ITEM_GIFT_EFFECT
    -- Disliked items cause only a -0.5 point effect
    if get_relationship_points(self, clicker_name) >=
            npc.relationships.RELATIONSHIP_PHASE["phase5"].limit then
        local modifier = 0.5 * npc.ITEM_GIFT_EFFECT
        -- Check for disliked items
        if item:get_name() == self.gift_data.disliked_items.dis1
                or item:get_name() == self.gift_data.disliked_items.dis2 then
            modifier = -0.5
            show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, false)
        elseif item:get_name() == self.gift_data.favorite_items.fav1
                or item:get_name() == self.gift_data.favorite_items.fav2 then
            -- Favorite item reaction
            show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, false)
        else
            -- Neutral item reaction
            npc.chat(self.npc_name, clicker_name, "Thank you honey!")
        end
        -- Take item
        item:take_item()
        clicker:set_wielded_item(item)
        -- Update relationship
        update_relationship(self, clicker_name, modifier)
        -- Reset gift timer
        reset_gift_timer(self, clicker_name)
        return true
    end

    -- Modifies relationship depending on given item
    local modifier = 0
    local take = true
    local show_reaction = false

    if item:get_name() == self.gift_data.favorite_items.fav1 then
        modifier = 2 * npc.relationships.ITEM_GIFT_EFFECT
        show_reaction = true
    elseif item:get_name() == self.gift_data.favorite_items.fav2 then
        modifier = npc.relationships.ITEM_GIFT_EFFECT
        show_reaction = true
    elseif item:get_name() == self.gift_data.disliked_items.dis1 then
        modifier = (-2) * npc.relationships.ITEM_GIFT_EFFECT
        show_reaction = true
    elseif item:get_name() == self.gift_data.disliked_items.dis2 then
        modifier = (-1) * npc.relationships.ITEM_GIFT_EFFECT
        show_reaction = true
    else
        -- If item is not a favorite or a dislike, then receive chance
        -- if 70%
        local receive_chance = math.random(1,10)
        if receive_chance < 7 then
            npc.chat(self.npc_name, clicker_name, "Thanks. I will find some use for this.")
        else
            npc.chat(self.npc_name, clicker_name, "Thank you, but no, I have no use for this.")
            take = false
        end
        show_reaction = false
    end

    -- Update relationship status
    local is_phase_changed = update_relationship(self, clicker_name, modifier)

    -- Show NPC reaction to gift
    if show_reaction == true then
        show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, is_phase_changed)
    end

    -- Take item if NPC accepted it
    if take == true then
        item:take_item()
        clicker:set_wielded_item(item)
    end

    npc.log("DEBUG", "NPC: "..dump(self))
    -- Reset gift timer
    reset_gift_timer(self, clicker_name)
    return true
end

-- Relationships are slowly increased by talking, increases by +0.2.
-- Talking to married NPC increases relationship by +1 
-- TODO: This needs a timer as the gift timer. NPC will talk anyways
-- but relationship will not increase.
function npc.relationships.dialogue_relationship_update(self, clicker)
    -- Get clicker name
    local clicker_name = npc.get_entity_name(clicker)

    -- Check if relationship can be updated via talk
    if check_relationship_by_talk_timer_ready(self, clicker_name) == false then
        return
    end

    -- Create relationship if it doesn't exists
    if check_relationship_exists(self, clicker_name) == false then
        create_relationship(self, clicker_name)
    end

    local modifier = 0.2
    if self.is_married_to ~= nil and clicker_name == self.is_married_to then
        modifier = 1
    end
    -- Update relationship
    update_relationship(self, clicker_name, modifier)

    -- Resert timers
    reset_talk_timer(self, clicker_name)
    reset_relationship_decrease_timer(self, clicker_name)
end
