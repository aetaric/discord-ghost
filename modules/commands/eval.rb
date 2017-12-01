module Ghost
  module DiscordCommands
    module Eval
      extend Discordrb::Commands::CommandContainer

      command(:eval, help_available: false) do |event, *code|
        break unless event.user.id == 188105444365959170
        begin
          eval code.join(' ')
        rescue => e
          "An error occurred 😞 ```#{e}```"
        end
      end
    end
  end
end
