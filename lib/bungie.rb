module Lib::BungieAPI
  API_KEY = YAML.load(ERB.new(File.read("../../config/bungie.yml")).result)[$app_env]["api_key"]
  API_ENDPOINT = YAML.load(ERB.new(File.read("../../config/bungie.yml")).result)[$app_env]["endpoint"]
  Logger.debug("\n %s \n %s", API_KEY, API_ENDPOINT)
  class Client
    def self.getNightfall(params)
      json = bungie_api_request("/Platform/Destiny2/Milestones/")

      modifiers = json["Response"]["2171429505"]['availableQuests'][0]['activity']['modifierHashes']
      hash = json["Response"]["2171429505"]['availableQuests'][0]['activity']['activityHash']
      
      activity = $sqlite.execute("select * from DestinyActivityDefinition where id = " + hash.to_s)[0]
      if activity.nil?
        activity = $sqlite.execute("select * from DestinyActivityDefinition where id + 4294967296 = " + hash.to_s)[0]
      end
    end

    private
      def self.bungie_api_request(path)
        uri = URI.parse($base_url + path)
        request = Net::HTTP::Get.new(uri)
        request["X-Api-Key"] = API_KEY
        
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
