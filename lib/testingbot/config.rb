module TestingBot
  @@config = nil
  
  def self.get_config
    @@config = TestingBot::Config.new if @@config.nil?
    @@config
  end
  
  class Config
    
    attr_reader :options
    
    def initialize(options = {})
      @options = {}
      @options = @options.merge(load_config_file)
      @options = @options.merge(load_config_environment)
      @options = @options.merge(options)
    end
    
    def [](key)
      @options[key]
    end

    def []=(key, value)
      @options[key] = value
    end
    
    def client_key
      @options[:client_key]
    end
    
    def client_secret
      @options[:client_secret]
    end
    
    private
    
    def load_config_file
      options = {}
      
      is_windows = (RUBY_PLATFORM =~ /w.*32/)
      
      if is_windows
        config_file = "#{ENV['HOMEDRIVE']}\\.testingbot"
      else
        config_file = File.expand_path("~/.testingbot")
      end
      
      if File.exists?(config_file)
        str = File.open(config_file) { |f| f.readline }.chomp
        options[:client_key], options[:client_secret] = str.split(':')
      end
      
      options
    end
    
    def load_config_environment
      options = {}
      options[:client_key] = ENV['TESTINGBOT_CLIENTKEY']
      options[:client_secret] = ENV['TESTINGBOT_CLIENTSECRET']
      
      options.delete_if { |key, value| value.nil?}
      
      options
    end
  end
end