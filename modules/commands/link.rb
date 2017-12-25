module Ghost
  module DiscordCommands
    module Link
      extend Discordrb::Commands::CommandContainer

      command(:link, bucket: :general, rate_limit_message: 'Calm down for %time% more seconds!', description: "Completes the link of your Discord and Bungie accounts.") do |event, link_code|
        st = $mysql.prepare("select * from users where discord_link=?")
        query = st.execute(link_code)

        user = event.message.author

        if !query.first.nil?
          update_statement = $mysql.prepare("UPDATE users set discord_id=?, discord_discriminator=? where discord_link=?")
          result = statement.execute(user.id,user.discriminator,link_code)

          user.pm "Guardian, Your accounts are now linked. User stats commands will now work for you."
        end
      end
    end
  end
end
