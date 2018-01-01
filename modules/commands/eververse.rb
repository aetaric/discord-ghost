module Ghost
  module DiscordCommands
    module Eververse
      extend Discordrb::Commands::CommandContainer

      command(:eververse, bucket: :D2, rate_limit_message: 'Calm down for %time% more seconds!', description: "Displays the items Tess has for sale.") do |event|
        result = $mysql.query('SELECT membership_id FROM oauth where deleted != 1 LIMIT 1')
        oauth = result.first

        membership_data = bungie_api_request "/Platform/User/GetMembershipsById/#{oauth['membership_id']}/-1/"
        resolved_data = membership_data['Response']['destinyMemberships'][0]
        profile = bungie_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/?components=200"
        character = profile['Response']['characters']['data'].keys[0]
        vendor_request = bungie_authenticated_api_request "/Platform/Destiny2/#{resolved_data['membershipType']}/Profile/#{resolved_data['membershipId']}/Character/#{character}/Vendors/?components=400,401,402"

        # Tess vendor ID - 3361454721
        tess_data = vendor_request['Response']['vendors']['data']['3361454721']
        tess_sales = vendor_request['Response']['sales']['data']['3361454721']['saleItems']
        tess_definition = bungie_api_request("/Platform/Destiny2/Manifest/DestinyVendorDefinition/3361454721/")['Response']['displayProperties']

        now = DateTime.now.to_time
        refresh_time = DateTime.parse(tess_data['nextRefreshDate'].gsub(/Z/, '-08:00')).to_time

        remaining_time = refresh_time - now
        valid_sales = [2,10]

        channel = event.channel
        begin
          channel.send_embed do |embed|
            embed.title = tess_definition['name']
            embed.description = tess_definition['description']
            embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: $base_url + tess_definition['icon'])
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: $base_url + tess_definition['largeIcon'])
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: quotes, icon_url: "https://ghost.sysad.ninja/Ghost.png")
            embed.color = Discordrb::ColourRGB.new(0xceae33).combined
            embed.add_field(name: "Time before Reset", value: "Items for sale reset in #{humanize(remaining_time.to_i)}", inline: false)
            tess_sales.keys.each do |index|
              item = tess_sales[index]
              if valid_sales.include? item['saleStatus']
                if item['costs'][0]['itemHash'] != 3147280338
                  cost =  "#{item['costs'][0]['quantity']} Bright Dust"
                  item_response = bungie_api_request "/Platform/Destiny2/Manifest/DestinyInventoryItemDefinition/#{item['itemHash']}/"
                  embed.add_field(name: item_response["Response"]["displayProperties"]["name"], value: cost, inline: true)
                end
              end
            end
          end
        rescue Discordrb::Errors::NoPermission => e
          event.author.pm "Guardian, I don't have permission to speak in that channel. Please make sure I can send messages and embed links."
        end
      end
    end
  end
end
