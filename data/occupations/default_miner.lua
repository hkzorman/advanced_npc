-- WIP miner by NewbProgrammer101 or roboto
local miner_def = {
  dialogues = {},
  textures = {"miner.png"},
  initial_inventory = {
    {name="default:pick_steel", chance=1},
    {name="default:shovel_bronze", chance=1}
    },
  schedule_entries = {
    [7] = {
      [1] = {
        task = npc.actions.cmd.WALK_TO_POS,
        args = {
          end_pos = npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE,
          walkable = {}
        }
      },
      [2] = {
        check = true,
        range = 3,
        random_execution_times = true,
        min_count = 20,
        max_count = 99,
        nodes = {"default:dirt", "default:dirt_with_grass", "default:sand", "default:desert_sand", "default:silver_sand", "default:gravel", "default:clay", "default:snow", "default:snowblock", "default:},
        actions = {
            ["default:dirt"] = {
              [1] = {
                action = npc.actions.cmd.WALK_STEP
                },
              [2] = {
                action = npc.actions.cmd.DIG
                }
              }
            }
          },
          [3] = {
            check = true,
            range = 3,
            random_execution_times = true,
            min_count = 20,
            max_count = 99,
            nodes = {"default:stone", "default:stonebrick", "default:stone_block", "default:mossycobble", "default:desert_stone", "default:desert_cobble", "default:desert_stonebrick", "default:desert_stone_block"},
            actions = {
              ["default:stone"] = {
                [1] = {
                  action = npc.actions.cmd.WALK_STEP
                },
                [2] = {
                  action = npc.actions.cmd.DIG
                }
              }
            }
          },
        none_actions = {
          [1] = {
            action = npc.actions.cmd.WALK_STEP,
            args = {
              dir = "random"
              }
            }
          }
        }
      }
    }
}

-- Occupation registration
npc.occupations.register_occupation("default_miner", miner_def)
