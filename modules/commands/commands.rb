module Ghost
  module DiscordCommands
    module Commands
      extend Discordrb::Commands::CommandContainer

      command(:commands, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', description: "Lists all the commands and a description.") do |event|
        event.send_temporary_message "```
      !botinfo     - Displays bot statistics and info.
      !item        - Searches for the item passed after the command.
      !nightfall   - Pulls the realtime info about the current nightfall.
      !newschannel - Sets the channel this is run in as your news channel. Any posts from Bungie's blog or @BungieHelp on twitter will be linked in this channel.
      !claninfo    - Pulls the realtime info about your clan.
      !engrams     - Pulls the realtime info about the clan engrams.```", 60.to_f
        temp_timers = Timers::Group.new
        temp_timers.after(60) { event.message.delete }
        temp_timers.wait
        event.drain
      end
    end
  end
end
