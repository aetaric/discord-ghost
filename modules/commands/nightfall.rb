module Ghost
  module DiscordCommands
    module Nightfall
      extend Discordrb::Commands::CommandContainer

      command(:nightfall, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', usage: "!nightfall", max_args: 0, description: "Displays the current nightfall and the modifiers") do |event|
        json = bungie_api_request "/Platform/Destiny2/Milestones/"

        modifiers = json['Response']['2171429505']['availableQuests'][0]['activity']['modifierHashes']
        hash = json['Response']['2171429505']['availableQuests'][0]['activity']['activityHash']

        @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityDefinition/#{hash}/"
        challenges = @lookup['Response']['challenges']

        channel = event.channel
        channel.send_embed do |embed|
          embed.title = @lookup['Response']['displayProperties']['name']
          embed.description = @lookup['Response']['displayProperties']['description']
          embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup['Response']['pgcrImage'])
          embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup['Response']['displayProperties']['icon'])
          embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
          embed.color = Discordrb::ColourRGB.new(0x00ff00).combined

          modifier_list = []
          modifiers.each do |mod|
            mod_info = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityModifierDefinition/#{mod.to_s}/"
            mod_value = "• **#{mod_info['Response']['displayProperties']['name']}:** #{mod_info['Response']['displayProperties']['description']}"
            modifier_list.push mod_value
          end

          challenge_list = []
          challenges.each do |challenge|
            challenge_info = bungie_api_request "/Platform/Destiny2/Manifest/DestinyObjectiveDefinition/#{challenge['objectiveHash']}/"
            challenge_value = "• **#{challenge_info['Response']['displayProperties']['name']}:** #{challenge_info['Response']['displayProperties']['description']}"
            challenge_list.push challenge_value
          end

          embed.add_field(name: "Modifiers", value: modifier_list.join("\n"), inline: true)
          embed.add_field(name: "Challenges", value: challenge_list.join("\n"), inline: true)
        end
      end
    end
  end
end
