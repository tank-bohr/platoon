#!/usr/bin/env ruby

server_class = if 'sqrt' == ARGV.shift
  require 'platoon/sqrt_server'
  Platoon::SqrtServer
else
  require 'platoon/echo_server'
  Platoon::EchoServer
end

server_class.new(verbose: true).run
