module Ghost
  module DiscordCommands
    module Server
      extend Discordrb::Commands::CommandContainer

      command(:server, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', help_available: false) do |event|
        event.send_message event.channel.server.id
      end
    end
  end
end
