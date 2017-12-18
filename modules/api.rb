module Ghost
  module BungieAPI
    def bungie_api_request(path)
      uri = URI.parse($base_url + path)
      request = Net::HTTP::Get.new(uri)
      request["X-Api-Key"] = ENV["BUNGIE_API"]

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      return JSON.load(response.body)
    end

    def bungie_authenticated_api_request(path)
      #uri = URI.parse("https://www.bungie.net/Platform/Destiny2/4/Profile/4611686018467728725/Character/2305843009301455952/Vendors/?components=400,401,402")

      result = $mysql.query("SELECT * FROM oauth where deleted != 1 LIMIT 1;")
      oauth = result.first

      now = Time.now()
      if now >= (oauth["updated_at"] + oauth["expires_in"].to_i)
        oauth = refresh_token(oauth['refresh_token'])
      end

      uri = URI.parse($base_url + path)
      request = Net::HTTP::Get.new(uri)
      request["X-Api-Key"] = ENV["BUNGIE_API"]
      request["Authorization"] = "#{oauth['token_type']} #{oauth['access_token']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end 

      return JSON.load(response.body)
    end
    
    def refresh_token(refresh_token)
      uri = URI.parse("https://www.bungie.net/platform/app/oauth/token/")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/x-www-form-urlencoded"
      request.set_form_data(
        "grant_type" => "refresh_token",
        "client_id" => ENV['BUNGIE_CLIENT_ID'],
        "client_secret" => ENV['BUNGIE_CLIENT_SECRET'],
        "refresh_token" => "#{refresh_token}",
      )
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      new_auth = JSON.load(response.body)
      $mysql.query("update oauth set deleted = 1 where deleted = 0;")

      statement = $mysql.prepare("INSERT INTO oauth (access_token,token_type,expires_in,refresh_token,refresh_expires_in,membership_id,deleted,updated_at) VALUES (?,?,?,?,?,?,0,NOW())")
      statement.execute(new_auth['access_token'],new_auth['token_type'],new_auth['expires_in'],new_auth['refresh_token'],new_auth['refresh_expires_in'],new_auth['membership_id'])

      return new_auth
    end

  end
end 
