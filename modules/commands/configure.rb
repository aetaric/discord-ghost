module Ghost
  module DiscordCommands
    module Configure
      extend Discordrb::Commands::CommandContainer

      command(:configure, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!') do |event,guild_id|
        if event.author.defined_permission?(:administrator)
          if guild_id.nil?
            event.send_message "Guardian, I need the guild ID. Please provide it as an arguement to the command."
          else
            if guild_id.to_i
              statement = $mysql.prepare("INSERT INTO servers (sid,d2_guild_id,created_at,updated_at) VALUES (?, ?,NOW(),NOW())")
              result = statement.execute(event.channel.server.id.to_s,guild_id)

              event.send_message "Thank you Guardian! My commands are available via *!commands*."
            end
          end
        else
          event.send_message "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)"
        end
      end
    end
  end
end
