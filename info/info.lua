--
-- User: hfranqui
-- Date: 5/3/18
-- Time: 9:30 PM
-- Description: 
--

npc.info = {
    names = {},
    textures = {},
    gift_items = {}
}

function npc.info.register_name(name, tags)
    if npc.info.names[name] ~= nil then
        npc.log("WARNING", "Attempt to register an existing name: "..dump(name))
        return
    end
    npc.info.names[name] = tags
end

local function search_using_tags(map, tags_to_search, find_only_one, exact_match)
    local result = {}
    -- Do a very inefficient search - need to see how to organize this better
    -- Traverse all tags for each name, one by one
    for name, tags_for_name in pairs(map) do
        local tags_found = 0
        -- For every tags array for a name, compare with tags_to_search
        -- and count how many tags match
        for i = 1, #tags_to_search do
            for j = 1, #tags_for_name do
                if tags_to_search[i] == tags_for_name[j] then
                    tags_found = tags_found + 1
                end
            end
        end
        -- Check if exact match true is true. If it is, tags_for_name and
        -- tags_to_search need to have same number of tags and all match
        if tags_found > 0 then
            if exact_match == true then
                if tags_found == #tags_to_search and tags_found == #tags_for_name then
                    result[#result + 1] = name
                    if find_only_one == true then
                        return result
                    end
                end
            else
                result[#result + 1] = name
                if find_only_one == true then
                    return result
                end
            end
        end
    end
    return result
end

function npc.info.get_names(tags_to_search, find_only_one, exact_match)
    return search_using_tags(npc.info.names, tags_to_search, find_only_one, exact_match)
end

function npc.info.register_texture(filename, tags)
    if npc.info.textures[filename] ~= nil then
        npc.log("WARNING", "Attempt to register an existing texture with filename: "..dump(filename))
        return
    end
    npc.info.textures[filename] = { tags=tags }
end

function npc.info.get_textures(tags_to_search, find_only_one, exact_match)
    return search_using_tags(npc.info.textures, tags_to_search, find_only_one, exact_match)
end
