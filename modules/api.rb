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
  end
end 
