module Ghost
  module DiscordCommands
    module NewsChannel
      extend Discordrb::Commands::CommandContainer

      command(:newschannel, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event|
        if event.author.defined_permission?(:administrator)
          statement = $mysql.prepare("UPDATE servers SET news_channel=? where sid=?")
          result = statement.execute(event.channel.id.to_s, event.channel.server.id.to_s)

          event.send_message "Guardian, Once news comes from Bungie, I will post it here."
        else
          event.send_message "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)"
        end
      end
    end
  end
end
