require 'stringio'
require 'socket'

# TODO:
# 2. have a 'warning class does not exist' so I know what message types to add
# 3. write callback to log messages (parsed_from) so I can capture all the vm messages on module reload

module AmiClient
  class AbstractMessage < Hashie::Mash
    MESSAGE_LINE_REGEX = /\A(\w+): (.*)\z/

    attr_reader :parsed_from

    class << self
      # Convert a key from an AMI message into the name we will use for
      # the Hashie::Mash property.
      # Ex: 'ChannelState' -> 'channel_state'
      def asterisk_key_to_ami_client_key(key)
        ActiveSupport::Inflector.underscore(key)
      end

      # Convert the name we use to store an key for an AMI message back to
      # something that resembles what asterisk would use.
      # Ex: 'channel_state' -> 'ChannelState'.
      # NOTE: using asterisk_key_to_ami_client_key and then
      #   ami_client_key_to_asterisk_key IS NOT guarenteed to get back the
      #   original asterisk key.
      #   Ex: 'ChannelID' -> 'channel_id' -> 'ChannelId'.
      def ami_client_key_to_asterisk_key(key)
        ActiveSupport::Inflector.camelize(key)
      end

      # Convert the type of message from the AMI into the demodulized name
      # of the class we will use to represent it. I think in most cases
      # this will actually leave the string alone since the Asterisk message
      # types are already camelized.
      # Ex: 'Newstate' -> 'Newstate'
      def ami_client_class_name_from_asterisk_message_type(message_type)
        ActiveSupport::Inflector.camelize(message_type)
      end

      # Parse a raw string from the AMI into an object of some type that
      # is a descendant of AmiClient::AbstractMessage.
      def build_from_raw_ami_message_string(ami_message_string)
        parse_state = :looking_for_message_type
        message = nil

        ami_message_string.lines.map(&:chomp).each do |line|
          if (match_data = line.match(MESSAGE_LINE_REGEX))
            key_name = match_data.captures[0]
            value = match_data.captures[1]

            case parse_state
            when :looking_for_message_type
              class_name = ami_client_class_name_from_asterisk_message_type(value)

              message_class =
                begin
                  AmiClient::Messages.const_get(class_name)
                rescue NameError
                  nil
                end

              unless message_class
                warn(
                  "[\033[0;33mWARNING\033[0;0m] - " \
                  "'#{class_name}' is an unknown type. To fix this add this " \
                  "const within AmiClient::Messages."
                )
                return nil
              end

              message = message_class.new(parsed_from: ami_message_string)
              parse_state = :looking_for_key_values
            when :looking_for_key_values
              attribute_setter_method_name = "#{asterisk_key_to_ami_client_key(key_name)}="
              message&.send(attribute_setter_method_name, value)
            end
          end
        end

        message
      end

      # Example Usage:
      #   AmiClient::Messages::Login.build do |m|
      #     m.username = 'joe123'
      #     m.secret   = 'mak0*beam'
      #   end
      def build(&block)
        if self == AmiClient::AbstractMessage ||
           self == AmiClient::Action ||
           self == AmiClient::Event
        then
          raise "Cannot call build() on #{self.name}"
        end

        self.new.tap(&block)
      end
    end # class << self

    def initialize(parsed_from: nil)
      @parsed_from = parsed_from
    end

    def to_ami_message_string
      StringIO.new.tap do |s|
        # Header
        s.puts "#{my_parent_type}: #{my_type}"

        # Attributes
        self.each do |attr_name, value|
          attr_name_for_message = AmiClient::AbstractMessage.ami_client_key_to_asterisk_key(attr_name)
          s.puts "#{attr_name_for_message}: #{value}"
        end

        # Final New Line
        s.puts
      end.string
    end

    private

    def my_type
      self.class.name.demodulize
    end

    def my_parent_type
      self.class.superclass.name.demodulize
    end
  end # AbstractMessage

  class Action < AmiClient::AbstractMessage
  end

  class Event < AmiClient::AbstractMessage
  end

  class Response < AmiClient::AbstractMessage
  end

  module Messages
    # This proc in turn creates another proc which can be transformed into a
    # block to pass into the .each() method to create all the constants
    # within this module with the chosen parent class.
    const_creator_block_creator = ->(parent_class) {
      ->(name) {
        AmiClient::Messages.const_set(
          AmiClient::AbstractMessage.ami_client_class_name_from_asterisk_message_type(name),
          Class.new(parent_class)
        )
      }
    }

    # Create classes for each Action message.
    action_creator = const_creator_block_creator.call(AmiClient::Action)
    %w[
      Login
    ].each(&action_creator)

    # Create classes for each Event message.
    event_creator = const_creator_block_creator.call(AmiClient::Event)
    %w[
      AgentCalled
      AgentComplete
      AgentConnect
      BridgeCreate
      BridgeDestroy
      BridgeEnter
      BridgeLeave
      Cdr
      DeviceStateChange
      DialBegin
      DialEnd
      ExtensionStatus
      Hangup
      HangupRequest
      LocalBridge
      MessageWaiting
      MusicOnHoldStart
      MusicOnHoldStop
      NewAccountCode
      NewCallerid
      Newchannel
      NewConnectedLine
      Newstate
      QueueCallerJoin
      QueueCallerLeave
      QueueMemberAdded
      QueueMemberPause
      QueueMemberRemoved
      QueueMemberStatus
      SoftHangupRequest
      UserEvent
    ].each(&event_creator)

    # Create classes for each Response message.
    response_creator = const_creator_block_creator.call(AmiClient::Response)
    %w[
      Success
    ].each(&response_creator)

  end # Messages

  class Client
    def initialize(
      host,
      port: 5038,
      user:,
      pass:
    )
      @host = host
      @port = port
      @user = user
      @pass = pass

      @logged_in = false

      @callbacks = {}
    end

    def on_message=(on_message_callback)
      @callbacks[:on_message] = on_message_callback
    end

    def read!
      if login!
        loop do
          message = read_next_message!
          run_on_message_callback(message)
        end
      end
    end

    private

    #
    # Callback Methods
    #

    def run_on_message_callback(message)
      callback = @callbacks[:on_message]
      return unless callback

      callback.call(message)
    end

    #
    # Socket Methods
    #

    def tcp_socket
      @tcp_socket ||= TCPSocket.new(@host, @port).tap do |s|
        # Read the first line when we connect, which should be the welcome
        # string that has the version info in it.
        ami_welcome_string = s.gets
      end
    end

    def read_next_message!
      raw_message = StringIO.new.tap do |s|
        # Flag to skip any blank lines we see before we get a line that has
        # actual data in it.
        skip_blanks = true

        while (line = tcp_socket.gets.chomp)
          # Ignore blank line
          next if skip_blanks && line.blank?

          # A non-blank line has been found, so unset this flag.
          skip_blanks = false

          # Write line to buffer.
          s.puts line

          # If line is blank, then we consider the message in the buffer is
          # complete and we can break out of this loop.
          break if line.blank?
        end
      end

      AmiClient::AbstractMessage.build_from_raw_ami_message_string(raw_message.string)
    end

    #
    # Login Methods
    #

    def login_action
      @login_action ||= AmiClient::Messages::Login.build do |m|
        m.username = @user
        m.secret   = @pass
      end
    end

    def logged_in?
      @logged_in
    end

    def login!
      return true if logged_in?

      tcp_socket.puts(login_action.to_ami_message_string)
      response = read_next_message!

      if response.is_a?(AmiClient::Messages::Success) &&
         response.message == 'Authentication accepted'
      then
        @logged_in = true
      else
        @logged_in = false
      end
    end
  end # Client
end
