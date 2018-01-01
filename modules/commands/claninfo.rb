module Ghost
  module DiscordCommands
    module ClanInfo
      extend Discordrb::Commands::CommandContainer

      command(:claninfo, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
        @clans = get_clanid event.channel.server.id
        @clans.each do |clan|
          @json = bungie_api_request "/Platform/GroupV2/#{clan}/"

          @progression = @json["Response"]["detail"]["clanInfo"]["d2ClanProgressions"]["584850370"]

          channel = event.channel
          begin
            channel.send_embed do |embed|
              embed.title = @json["Response"]["detail"]["name"]
              embed.description = @json["Response"]["detail"]["about"]
              embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
              embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
              embed.add_field(name: "Members", value: "#{@json['Response']['detail']['memberCount']} / #{@json['Response']['detail']['features']['maximumMembers']}")
              embed.add_field(name: "Level", value: @progression["level"], inline: true)
              embed.add_field(name: "Next Level", value: @progression["progressToNextLevel"].to_s + "/" + @progression["nextLevelAt"].to_s + " (" + (@progression["progressToNextLevel"].to_f / @progression["nextLevelAt"].to_f * 100.0).round(2).  to_s + "%)", inline: true)
              embed.add_field(name: "Weekly Progress", value: @progression["weeklyProgress"].to_s + "/" + @progression["weeklyLimit"].to_s + " (" + (@progression["weeklyProgress"].to_f / @progression["weeklyLimit"].to_f * 100.0).round(2).to_s + "%)", inline: true)
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
