require 'platoon/server'

module Platoon
  class EchoServer < Server
    WELCOME_TEXT = 'Welcome!'

    def on_connect(client)
      client.socket.puts WELCOME_TEXT
    end

    def on_request(client, request)
      client.socket.puts request
    end
  end
end
