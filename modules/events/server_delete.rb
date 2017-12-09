module Ghost
  module DiscordEvents
    module ServerDelete
      extend Discordrb::EventContainer

      server_delete do |event|
        statement = $mysql.prepare("DELETE FROM servers WHERE sid=? LIMIT 1")
        statement.execute(event.server.id)
        statement = $mysql.prepare("DELETE FROM guilds WHERE sid=?")
        statement.execute(event.server.id)
        puts "Ghost was deleted from server #{event.server.name}"
      end
    end
  end
end
