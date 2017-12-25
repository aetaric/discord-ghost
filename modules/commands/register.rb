module Ghost
  module DiscordCommands
    module Register
      extend Discordrb::Commands::CommandContainer

      command(:register, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', description: "Starts the process of linking your Bungie account to your Discord account.") do |event|
        event.message.react "\u2705"
        event.author.pm "Guardian, If you want to link your discord to your Bungie account so I can pull info about your ingame stats; Please click this link: https://discordghost.space/auth/bungie\nOnce this is done, follow the instructions on the page to link your discord with the !link command."
      end
    end
  end
end
