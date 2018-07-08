module Ghost
  module DiscordCommands
    module BotInfo
      extend Discordrb::Commands::CommandContainer
      command(:botinfo, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', description: "Outputs information about the bot and it's running state.") do |event|
        shard_value = ($shard + 1).to_s + "/" + $total_shards.to_s
        seconds = `ps -o etimes= -p '#{Process.pid}'`.strip.to_i
        rev = `git rev-parse HEAD`.strip.split(//).first(9).join("")
        begin
          event.channel.send_embed do |embed|
            embed.title = "Ghost"
            embed.description = "A discord bot for Destiny 2 clans"
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: Ghost::Helpers.quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0x00ff00).combined
            embed.add_field(name: "Author", value: "@aetaric#0001", inline: true)
            embed.add_field(name: "Servers", value: $bot.servers.count, inline: true)
            embed.add_field(name: "Shard", value: shard_value, inline: true)
            embed.add_field(name: "Uptime", value: humanize(seconds), inline: true)
            embed.add_field(name: "Version", value: rev, inline: true)
            embed.add_field(name: "Library", value: "discordrb", inline: true)
            embed.add_field(name: "Support Server", value: "https://discord.gg/8My2HqS", inline: true)
          end
        rescue Discordrb::Errors::NoPermission => e
          event.author.pm "Guardian, I don't have permission to speak in that channel. Please make sure I can send messages and embed links."
        end
      end
    end
  end
end
