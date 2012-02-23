require "testingbot/version"

# if selenium RC, add testingbot credentials to request
if defined?(Selenium) && defined?(Selenium::Client) && defined?(Selenium::Client::Protocol)
  module Selenium
    module Client
      module Protocol
        attr_writer :client_key, :client_secret
        
          def client_key
            if @client_key.nil?
              @client_key, @client_secret = get_testingbot_credentials
            end
            @client_key
          end
          
          def client_secret
            if @client_secret.nil?
              @client_key, @client_secret = get_testingbot_credentials
            end
            @client_secret
          end
          
          def get_testingbot_credentials
            if File.exists?(File.expand_path("~/.testingbot"))
              str = File.open(File.expand_path("~/.testingbot")) { |f| f.readline }.chomp
              str.split(':')
            else
              raise "Please run the testingbot install tool first"
            end
          end
          
          # add custom parameters for testingbot.com
          def http_request_for_testingbot(verb, args)
            data = http_request_for_original(verb, args)
            data << "&client_key=#{client_key}&client_secret=#{client_secret}"
          end

          begin
           alias http_request_for_original http_request_for
           alias http_request_for http_request_for_testingbot
         rescue
         end
      end
    end
  end
end

if defined?(Selenium) && defined?(Selenium::Client) && defined?(Selenium::Client::Base)
  module Selenium
    module Client
      module Base
        DEFAULT_OPTIONS = {
          :screenshot => true
        }
        
        alias :close_current_browser_session_old :close_current_browser_session
        alias :start_new_browser_session_old :start_new_browser_session
        alias :initialize_old :initialize
        
        attr_accessor :options
        attr_accessor :session_id_backup
        attr_accessor :extra
        attr_accessor :platform
        attr_accessor :version
        
        def initialize(*args)
          if args[0].kind_of?(Hash)
            options = args[0]
            @platform = options[:platform] || "WINDOWS"
            @version  = options[:version]  if options[:version]
          end
          
          @options = DEFAULT_OPTIONS
          initialize_old(*args)
          @host = "hub.testingbot.com" if @host.nil?
          @port = 4444 if @port.nil?
        end
        
        def close_current_browser_session
          @session_id_backup = @session_id
          close_current_browser_session_old
        end
        
        def start_new_browser_session(options={})
          options = @options.merge options
          options[:platform] = @platform
          options[:version] = @version unless @version.nil?
          start_new_browser_session_old(options)
        end
        
        def extra=(str)
          @extra = str
        end
        
        def options=(opts = {})
          @options = @options.merge opts
        end
      end
    end
  end
end

# rspec 1
begin
  require 'spec'
  require "selenium/rspec/spec_helper"
    Spec::Runner.configure do |config|
      config.prepend_after(:each) do
        if File.exists?(File.expand_path("~/.testingbot"))
          str = File.open(File.expand_path("~/.testingbot")) { |f| f.readline }.chomp
          client_key, client_secret = str.split(':')
          
          session_id = nil
          
          if !@selenium_driver.nil?
            session_id = @selenium_driver.session_id_backup
          elsif defined?(Capybara)
            session_id = Capybara.drivers[:testingbot].call.browser.instance_variable_get("@bridge").instance_variable_get("@session_id")
          end
          
          if session_id.nil?
            return
          end
          
          params = {
            "session_id" => session_id,
            "client_key" => client_key,
            "client_secret" => client_secret,
            "status_message" => @execution_error,
            "success" => !actual_failure?,
            "name" => description.to_s,
            "kind" => 2,
            "extra" => @selenium_driver.extra
          }
        
          url = URI.parse('http://testingbot.com/hq')
          http = Net::HTTP.new(url.host, url.port)
          response = http.post(url.path, params.map { |k, v| "#{k.to_s}=#{v}" }.join("&"))
        else
            puts "Can't post test results to TestingBot since I could not a .testingbot file in your home-directory."
        end
      end
    end
rescue LoadError
end

# rspec 2
begin
  require 'rspec'
  
  ::RSpec.configuration.after :each do
    if File.exists?(File.expand_path("~/.testingbot"))
      str = File.open(File.expand_path("~/.testingbot")) { |f| f.readline }.chomp
      client_key, client_secret = str.split(':')
    
      test_name = ""
      if example.metadata && example.metadata[:example_group]
        if example.metadata[:example_group][:description_args]
          test_name = example.metadata[:example_group][:description_args].join(" ")
        end
      end
      
      session_id = nil
      
      if !@selenium_driver.nil?
        session_id = @selenium_driver.session_id_backup
      elsif defined?(Capybara)
        session_id = Capybara.drivers[:testingbot].call.browser.instance_variable_get("@bridge").instance_variable_get("@session_id")
      end
      
      if session_id.nil?
        return
      end
      
      params = {
        "session_id" => session_id,
        "client_key" => client_key,
        "client_secret" => client_secret,
        "status_message" => @execution_error,
        "success" => example.exception.nil?,
        "name" => test_name,
        "kind" => 2
      }
      
      if @selenium_driver && @selenium_driver.extra
        params["extra"] = @selenium_driver.extra
      end
    
      url = URI.parse('http://testingbot.com/hq')
      http = Net::HTTP.new(url.host, url.port)
      response = http.post(url.path, params.map { |k, v| "#{k.to_s}=#{v}" }.join("&"))
    else
      puts "Can't post test results to TestingBot since I could not a .testingbot file in your home-directory."
    end
  end
rescue LoadError
end

if defined?(Test::Unit::TestCase)
  module TestingBot
    class TestingBot::TestCase < Test::Unit::TestCase
      alias :run_teardown_old :run_teardown
      alias :handle_exception_old :handle_exception
      
      attr_accessor :exception
      
      def run_teardown
        client_key, client_secret = get_testingbot_credentials
        params = {
          "session_id" => browser.session_id,
          "client_key" => client_key,
          "client_secret" => client_secret,
          "status_message" => @exception,
          "success" => passed?,
          "name" => self.to_s,
          "kind" => 2,
          "extra" => browser.extra
        }
        
        url = URI.parse('http://testingbot.com/hq')
        http = Net::HTTP.new(url.host, url.port)
        response = http.post(url.path, params.map { |k, v| "#{k.to_s}=#{v}" }.join("&"))
        run_teardown_old
      end
      
      def handle_exception(e)
        @exception = e.to_s
        handle_exception_old(e)
      end
      
      def get_testingbot_credentials
        if File.exists?(File.expand_path("~/.testingbot"))
          str = File.open(File.expand_path("~/.testingbot")) { |f| f.readline }.chomp
          str.split(':')
        else
          raise "Please run the testingbot install tool first"
        end
      end
    end
  end
end