module Ghost
  module DiscordCommands
    module Engrams
      extend Discordrb::Commands::CommandContainer

      command(:engrams, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the clan engrams for your configured clan.") do |event|
        @clans = get_clanid event.channel.server.id
        @clans.each do |clan|

          json = bungie_api_request "/Platform/Destiny2/Clan/#{clan}/WeeklyRewardState/"
    
          @crucible = false
          @trials = false
          @nightfall = false
          @raid = false
    
          json["Response"]["rewards"][0]["entries"].each do |entry|
            if entry["rewardEntryHash"] == 3789021730
              if entry["earned"] == true
                @nightfall = true
              end
            elsif entry["rewardEntryHash"] == 2112637710
              if entry["earned"] == true
                @trials = true
              end
            elsif entry["rewardEntryHash"] == 2043403989
              if entry["earned"] == true
                @raid = true
              end
            elsif entry["rewardEntryHash"] == 964120289
              if entry["earned"] == true
                @crucible = true
              end
            end
          end
    
          hash = json['Response']['milestoneHash']
          @lookup = bungie_api_request "/Platform/Destiny2/Manifest/DestinyMilestoneDefinition/#{hash.to_s}/"
          @clan = bungie_api_request "/Platform/GroupV2/#{clan}/"
    
          channel = event.channel
          begin
            channel.send_embed do |embed|
              embed.title = "#{@lookup["Response"]["displayProperties"]["name"]} - #{@clan['Response']['detail']['name']}"
              embed.description = @lookup["Response"]["displayProperties"]["description"]
              embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + @lookup["Response"]["displayProperties"]["icon"])
              embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
              embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
              # 3789021730 - Nightfall
              if @nightfall
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["3789021730"]["displayProperties"]["name"], value: "Available", inline: true)
              else
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["3789021730"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
              end
              # 2112637710 - Trials
              if @trials
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2112637710"]["displayProperties"]["name"], value: "Available", inline: true)
              else
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2112637710"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
              end
              # 2043403989 - Raid
              if @raid
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2043403989"]["displayProperties"]["name"], value: "Available", inline: true)
              else
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["2043403989"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
              end
              # 964120289 - Crucible
              if @crucible
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["964120289"]["displayProperties"]["name"], value: "Available", inline: true)
              else
                embed.add_field(name: @lookup["Response"]["rewards"]["1064137897"]["rewardEntries"]["964120289"]["displayProperties"]["name"], value: "Not Obtained", inline: true)
              end
            end
          rescue Discordrb::Errors::NoPermission => e
            event.author.pm "Guardian, I don't have permission to speak in that channel. Please make sure I can send messages and embed links."
          end
        end
        event.drain
      end
    end
  end
end
