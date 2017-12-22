module Ghost
  module DiscordCommands
    module Leviathan
      extend Discordrb::Commands::CommandContainer

      command(:leviathan, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the rotation of the Leviathan Raid.") do |event|
        # https://github.com/vpzed/Destiny2-API-Info/wiki/Leviathan-Raid-Encounter-Rotation-Info
        raid_hash_map = {'2693136605' => {'power' => 300, 'order' => 'Gauntlet, Pleasure Gardens, Royal Pools'}, '2693136604' => {'power' => 300, 'order' => 'Gauntlet, Royal Pools, Pleasure Gardens'}, '2693136602' => {'power' => 300, 'order' => 'Pleasure Gardens, Gauntlet, Royal Pools'}, '2693136603' => {'power' => 300, 'order' => 'Pleasure Gardens, Royal Pools, Gauntlet'}, '2693136600' => {'power' => 300, 'order' => 'Royal Pools, Gauntlet, Pleasure Gardens'}, '2693136601' => {'power' => 300, 'order' => 'Royal Pools, Pleasure Gardens, Gauntlet'}, '1685065161' => {'power' => 330, 'order' => 'Gauntlet, Pleasure Gardens, Royal Pools'}, '757116822' => {'power' => 330, 'order' => 'Gauntlet, Royal Pools, Pleasure Gardens'}, '417231112' => {'power' => 330, 'order' => 'Pleasure Gardens, Gauntlet, Royal Pools'}, '3446541099' => {'power' => 330, 'order' => 'Pleasure Gardens, Royal Pools, Gauntlet'}, '2449714930' => {'power' => 330, 'order' => 'Royal Pools, Gauntlet, Pleasure Gardens'}, '3879860661' => {'power' => 330, 'order' => 'Royal Pools, Pleasure Gardens, Gauntlet'}}

        json = bungie_api_request "/Platform/Destiny2/Milestones/"
        leviathan_raids = json['Response']['3660836525']['availableQuests'][0]['activity']['variants']
        @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityDefinition/#{leviathan_raids[0]['activityHash']}/"

        channel = event.channel
        channel.send_embed do |embed|
          embed.title = @lookup['Response']['displayProperties']['name']
          embed.description = @lookup['Response']['displayProperties']['description']
          embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup['Response']['pgcrImage'])
          embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup['Response']['displayProperties']['icon'])
          embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
          embed.color = Discordrb::ColourRGB.new(0x00ff00).combined

          leviathan_raids.each do |raid|
            hash = raid['activityHash'].to_s
            order = raid_hash_map[hash]['order']

            case raid_hash_map[hash]['power']
            when 300
              raid_type = "Leviathan Raid"
            when 330
              raid_type = "Leviathan Raid (Prestige)"
            else
              raid_type = "I have no idea how this happened, but it's an unknown raid type."
            end
            
            embed.add_field(name: raid_type, value: order, inline: true)
          end

          challenges = json['Response']['3660836525']['availableQuests'][0]['challenges']
          challenges.each do |challenge|
            activity_hash = leviathan_raids[0]['activityHash'].to_s
            if challenge['activityHash'].to_s == activity_hash
              objective_lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyObjectiveDefinition/#{challenge['objectiveHash']}/"
              if /Discover the hidden/.match(objective_lookup['Response']['displayProperties']['description'])
                embed.add_field(name: "Challenge", value: objective_lookup['Response']['displayProperties']['name'], inline: false)
              end
            end
          end
        end
      end
    end
  end
end
