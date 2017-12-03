module Ghost
  module DiscordCommands
    module NewsChannel
      extend Discordrb::Commands::CommandContainer

      command(:newschannel, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', required_permissions: [:administrator], usage: "!newschannel", max_args: 0,
        description: "Configures the channel you run this command in as the \"News Channel\" for this server. Any tweets from @bungiehelp or blog posts on the destiny 2 blog will be embeded in this channel.", 
        permission_message: "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)") do |event|
          statement = $mysql.prepare("UPDATE servers SET news_channel=? where sid=?")
          result = statement.execute(event.channel.id.to_s, event.channel.server.id.to_s)

          event.send_message "Guardian, Once news comes from Bungie, I will post it here."
          event.send_message "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)"
      end
    end
  end
end
