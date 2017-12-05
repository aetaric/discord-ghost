module Ghost
  module DiscordCommands
    module Configure
      extend Discordrb::Commands::CommandContainer

      command(:configure, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', required_permissions: [:administrator], min_args: 1, max_args: 1, 
              description: "Configures the bot to use your Destiny 2 guild for guild-related commands on this server.", usage: "!configure 1234567", 
              permission_message: "Guardian, You need permission from the vanguard to do this! (User lacks defined role with \"Administrator\" set)") do |event,guild_id|
        if guild_id.nil?
          event.send_message "Guardian, I need the guild ID. Please provide it as an arguement to the command."
        else
          if guild_id.to_i
            statement = $mysql.prepare("INSERT INTO guilds (sid,d2_guild_id) VALUES (?, ?)")
            result = statement.execute(event.channel.server.id.to_s,guild_id)

            event.send_message "Thank you Guardian! My commands are available via *!commands*."
          end
        end
      end
    end
  end
end
