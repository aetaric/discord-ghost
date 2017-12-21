module Ghost
  module DiscordCommands
    module Xur
      extend Discordrb::Commands::CommandContainer

      command(:xur, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the items Xur has for sale. If he's not around. Displays the time he will be back.") do |event|
        result = $mysql.query('SELECT membership_id FROM oauth where deleted != 1 LIMIT 1')
        oauth = result.first

        membership_data = bungie_api_request "/Platform/User/GetMembershipsById/#{oauth['membership_id']}/-1/"
        resolved_data = membership_data['Response']['destinyMemberships'][0]
        profile = bungie_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/?components=200"
        character = profile['Response']['characters']['data'].keys[0]
        vendor_request = bungie_authenticated_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/Character/#{character}/Vendors/?components=400,401,402"

        xur_data = vendor_request['Response']['vendors']['data']['2190858386']
        xur_sales = vendor_request['Response']['sales']['data']['2190858386']['saleItems']
        xur_definition = bungie_api_request("/Platform/Destiny2/Manifest/DestinyVendorDefinition/2190858386/")['Response']['displayProperties']

        now = DateTime.now.to_time
        refresh_time = DateTime.parse(xur_data['nextRefreshDate'].gsub(/Z/, '-08:00')).to_time

        remaining_time = refresh_time - now

        if (remaining_time / 3600) <= 72.0
          channel = event.channel
          channel.send_embed do |embed|
            embed.title = xur_definition['name']
            embed.description = xur_definition['description']
            embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['icon'])
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['largeIcon'])
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0xceae33).combined
            embed.add_field(name: "Xur is away", value: "Xur will return in #{humanize(remaining_time.to_i)}", inline: true)
          end
        else
          weapon  = bungie_api_request("/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{xur_sales['69']['itemHash']}/")['Response']['displayProperties']
          hunter  = bungie_api_request("/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{xur_sales['79']['itemHash']}/")['Response']['displayProperties']
          titan   = bungie_api_request("/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{xur_sales['89']['itemHash']}/")['Response']['displayProperties']
          warlock = bungie_api_request("/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{xur_sales['102']['itemHash']}/")['Response']['displayProperties']

          channel = event.channel
          channel.send_embed do |embed|
            embed.title = xur_definition['name']
            embed.description = xur_definition['description']
            embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['icon'])
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + xur_definition['largeIcon'])
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0xceae33).combined
           
            embed.add_field(name: "Time Remaining", value: "Xur leaves in #{humanize((remaining_time - 259200).to_i)}.")
            embed.add_field(name: weapon['name'], value: weapon['description'], inline: true)
            embed.add_field(name: hunter['name'], value: hunter['description'], inline: true)
            embed.add_field(name: titan['name'], value: titan['description'], inline: true)
            embed.add_field(name: warlock['name'], value: warlock['description'], inline: true)
          end
        end
      end
    end
  end
end
