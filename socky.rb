require 'socket'
require 'rubygems'

module Socky
  class Base
    cattr_accessor :port, :host, :debug, :rescue_classes, :rescue_retries
    attr_accessor :data, :rescue_count
    
    class << self
      def rescue_classes
        @@rescue_classes || [Errors::Standard]
      end
      
      def rescue_retries
        @@rescue_retries || 3
      end
      
      def setup
        yield self
      end
      
      def send
        request = self.new
        yield request if block_given?
        request.make!
      end
    end
    
    def initialize
      self.data         = []
      self.rescue_count = 0
    end
    
    def <<(data)
      self.data << data
    end
    
    def make!
      raise Errors::MissingPort, "Please specify a port" unless self.port
      raise Errors::MissingAddress, "Please specify a host address" unless self.host
      
      return false unless self.data.present?
      
      begin
        socket = TCPSocket.new(self.host, self.port.to_i)
        
        self.data.each_with_index do |piece, index|
          socket.write(piece + "\n")
          response = read_response!(socket)
          log("written #{piece}")
        end
        
        true
      rescue *self.rescue_classes => error
        increment_retries
        
        unless maximum_retries_reached?
          retry
        else
          raise error.class, error
        end
      end
    ensure
      socket.close if socket
    end
    
    private
    def read_response!(socket)
      response = ""
      
      loop do
        response += socket.recv(1024)
        break if response[response.size - 1, response.size].eql?("\n")
      end
      
      response.slice!(response.size - 1, response.size)
      
      return response
    end
    
    def maximum_retries_reached?
      self.rescue_count >= self.rescue_retries
    end
    
    def increment_retries
      self.rescue_count += 1
    end
    
    def log(message)
      puts "* #{message}" if self.debug
    end
  end
  
  module Errors
    class Standard < StandardError
    end
    
    class MissingAddress < Standard
    end
    
    class MissingPort < Standard
    end
    
    class Timeout < Errno::ETIMEDOUT
    end
    
    class Socket < SocketError
    end
  end
end
