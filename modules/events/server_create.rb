module Ghost
  module DiscordEvents
    module ServerCreate
      extend Discordrb::EventContainer
      
      server_create do |event|
        puts "Ghost was added to server: #{event.server.name} (#{event.server.id})"
        bot_member = $bot.profile.on(event.server)
        event.server.channels.each do |channel|
          if bot_member.permission?(:send_messages, channel)
            channel.send_message "Thanks for adding me Guardian, but I won't function until I am configured!\n
I require only a few moments of your time to complete this important step.\n
Please take a moment to run the !configure *guild id* command in a text channel on your server.\n
*Example:* !configure 123456"
            break
          else
            puts "No permission in channel: #{channel.name}"
          end
        end
        statement = $mysql.prepare("INSERT INTO servers (sid,created_at,updated_at) VALUES (?,NOW(),NOW())")
        result = statement.execute(event.server.id.to_s)

      end
    end
  end
end
