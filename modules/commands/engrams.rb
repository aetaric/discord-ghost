module Ghost
  module DiscordCommands
    module Commands
      extend Discordrb::Commands::CommandContainer

      command(:engrams, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the clan engrams for your configured clan.") do |event|
        @clan = get_clanid event.channel.server.id
    
        json = bungie_api_request "/Platform/Destiny2/Clan/#{@clan}/WeeklyRewardState/"
    
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
    
        channel = event.channel
        channel.send_embed do |embed|
          embed.title = @lookup["Response"]["displayProperties"]["name"]
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
      end
    end
  end
end
