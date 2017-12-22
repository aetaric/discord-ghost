module Ghost
  module DiscordCommands
    module Commands
      extend Discordrb::Commands::CommandContainer

      command(:commands, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', description: "Lists all the commands and a description.") do |event|
        event.send_temporary_message "```
      !help        - Displays the command list as well as provides usage information if needed.
      !botinfo     - Displays bot statistics and info.
      !configure   - Configures the bot for your clan.
      !item        - Searches for the item passed after the command.
      !nightfall   - Pulls the realtime info about the current nightfall.
      !leviathan   - Displays the rotation of the Leviathan Raid.
      !xur         - Displays the items Xur has for sale. If he's not around. Displays the time he will be back.
      !eververse   - Displays the items Tess has for sale.
      !newschannel - Sets the channel this is run in as your news channel. Any posts from Bungie's blog or @BungieHelp on twitter will be linked in this channel.
      !claninfo    - Pulls realtime info about your clan.
      !engrams     - Pulls your clan's engrams.```", 60.to_f
        temp_timers = Timers::Group.new
        temp_timers.after(60) { event.message.delete }
        temp_timers.wait
        event.drain
      end
    end
  end
end
