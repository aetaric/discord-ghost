module Ghost
  module DiscordCommands
    module Nightfall
      extend Discordrb::Commands::CommandContainer

      command(:nightfall, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
        json = bungie_api_request "/Platform/Destiny2/Milestones/"

        modifiers = json["Response"]["2171429505"]['availableQuests'][0]['activity']['modifierHashes']
        hash = json["Response"]["2171429505"]['availableQuests'][0]['activity']['activityHash']

        @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityDefinition/#{hash}/"

        channel = event.channel
        channel.send_embed do |embed|
          embed.title = @lookup["Response"]["displayProperties"]["name"]
          embed.description = @lookup["Response"]["displayProperties"]["description"]
          embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["pgcrImage"])
          embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["displayProperties"]["icon"])
          embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
          embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
          modifiers.each do |mod|
            mod_info = bungie_api_request "/Platform/Destiny2/Manifest/DestinyActivityModifierDefinition/#{mod.to_s}/"
            embed.add_field(name: mod_info["Response"]["displayProperties"]["name"], value: mod_info["Response"]["displayProperties"]["description"], inline: true)
          end
        end
      end
    end
  end
end
