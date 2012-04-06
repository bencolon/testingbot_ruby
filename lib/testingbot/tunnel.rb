module TestingBot
  class Tunnel
    TIMEOUT_SECONDS = 70

    attr_reader :options, :config, :process, :available, :connected, :errors

    def initialize(opts = {})
      @available = false
      @errors = []
      @config = TestingBot::Config.new(opts)
      @options = default_options
      @options = @options.merge(opts)

      raise ArgumentError, "Please make sure you have put the .testingbot file in the your user directory, or set the environment variables TESTINGBOT_CLIENTKEY AND TESTINGBOT_CLIENTSECRET" if @config[:client_key].nil? || @config[:client_secret].nil?
    end

    def start
      p "Starting the TestingBot Tunnel" if @options[:verbose] == true
      @process = IO.popen("exec java -jar #{get_jar_path} #{config[:client_key]} #{config[:client_secret]} #{extra_options} 2>&1")
      at_exit do
        # make sure we kill the tunnel
        Process.kill("INT", @process.pid)
      end

      Thread.new do 
        while (line = @process.gets)
          if line =~ /^You may start your tests/
            @available = true
          end

          if line =~ /Exception/ || line =~ /error/
            @errors << line
          end

          p line if @options[:verbose] == true
        end
      end

      poll_ready

      p "You are now ready to start your test" if @options[:verbose] == true
    end

    def is_connected?
      @available
    end

    def errors
      @errors || []
    end

    def stop
      raise "Can't stop tunnel, it has not been started yet" if @process.nil?

      p "Stopping TestingBot Tunnel" if @options[:verbose] == true
      Process.kill("INT", @process.pid)
    end

    private

    def extra_options
      extra = @options[:options] || []
      extra.join(" ")
    end

    def default_options
      {
        :verbose => true
      }
    end

    def get_jar_path
      file = File.expand_path(File.dirname(__FILE__) + '/../../vendor/Testingbot-Tunnel.jar')
      raise RuntimeException, "Could not find TestingBot-Tunnel.jar in vendor directory" unless File.exists?(file)

      file
    end

    def poll_ready
      seconds = 0
      while ((@available == false) && (seconds < TIMEOUT_SECONDS) && @errors.empty?)
        sleep 1
        seconds = seconds + 1
      end

      raise "Could not start Tunnel after #{TIMEOUT_SECONDS} seconds" if !is_connected? && @errors.empty?
    end
  end
end