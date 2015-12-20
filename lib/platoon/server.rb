require 'socket'
require 'logger'

module Platoon
  class Client < Struct.new(:socket, :addrinfo)
  end

  class Server

    DEFAULT_HOST = '127.0.0.1'.freeze
    DEFAULT_PORT = 9000
    DEFAULT_BIND = 128
    SIGNALS_TO_HANDLE = %w[INT TERM USR1 USR2].freeze
    EXIT_COMMANDS = %w[q quit exit].freeze

    include Socket::Constants

    attr_reader :options, :socket, :clients
    attr_writer :logger

    def initialize(options = {})
      @options = options
      @socket = Socket.new AF_INET, SOCK_STREAM
      @clients = []
      @self_read, @self_write = IO.pipe
    end

    def run
      host = options.fetch(:host, DEFAULT_HOST)
      port = options.fetch(:port, DEFAULT_PORT)
      bind = options.fetch(:bind, DEFAULT_BIND)
      logger.info "Listen #{host}:#{port}"
      sockaddr = Socket.pack_sockaddr_in port, host
      socket.bind sockaddr
      socket.listen bind
      SIGNALS_TO_HANDLE.each { |sig| set_signal_handler(sig) }
      self.running = true
      run_loop
    end

    def run_loop
      while running
        clients.reject!{ |c| c.socket.closed? }
        ra = [self_read, socket] + clients.map(&:socket)
        ready = IO.select(ra)
        ready.first.each do |io|
          handle_ready(io)
        end
      end
    end

    def logger
      @logger ||= if options.key?(:logger)
        options[:logger]
      else
        level = options[:verbose] ? Logger::DEBUG : Logger::INFO
        logger = Logger.new(STDOUT).tap { |l| l.level = level }
      end
    end

    def on_connect(_client)
    end

    def on_request(_client, _request)
    end

    def on_sigint
      exit
    end

    def on_sigterm
      self.running = false
    end

    def on_sigusr1
    end

    def on_sigusr2
    end

    private

    attr_reader :self_read, :self_write
    attr_accessor :running

    def set_signal_handler(sig)
      trap(sig) { self_write.puts(sig) }
    rescue ArgumentError
      logger.warn "Signal #{sig} not supported"
    end

    def handle_ready(io)
      case io
      when self_read
        sig = io.gets.chomp
        handle_signal sig
      when socket
        create_session
      else
        client = clients.detect{ |c| c.socket == io }
        if client.nil?
          logger.error "Unknown fd is ready: #{io}"
        else
          handle_request(client)
        end
      end
    end

    def create_session
      client_socket, client_addrinfo = socket.accept_nonblock
      logger.info "Accept connection from #{client_addrinfo.ip_address}"
      client = Client.new(client_socket, client_addrinfo)
      on_connect(client)
      clients << client
    end

    def handle_signal(sig)
      logger.debug "Signal SIG#{sig.upcase} received"
      public_send "on_sig#{sig.downcase}"
    end

    def handle_request(client)
      request = client.socket.gets
      return if request.nil?
      request.chomp!
      return if request.empty?
      logger.debug "Request [#{request}] received"
      if EXIT_COMMANDS.include? request
        client.socket.close
      else
        on_request(client, request)
      end
    rescue Errno::ECONNRESET => e
      logger.info "Connection closed by peer"
    end
  end
end
