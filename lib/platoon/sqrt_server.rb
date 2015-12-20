require 'platoon/server'

module Platoon
  class SqrtServer < Server
    WELCOME_TEXT = 'Enter a number to get square root'

    def on_connect(client)
      client.socket.puts WELCOME_TEXT
    end

    def on_request(client, request)
      client.socket.puts Math.sqrt(request.to_i)
    end
  end
end
