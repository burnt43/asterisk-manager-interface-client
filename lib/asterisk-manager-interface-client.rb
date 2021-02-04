module AmiClient
  class AbstractMessage < Hashie::Mash
    MESSAGE_LINE_REGEX = /\A(\w+): (.*)\z/

    attr_reader :type

    class << self
      def asterisk_key_to_ami_client_key(key)
        ActiveSupport::Inflector.underscore(key)
      end

      def ami_client_key_to_asterisk_key(key)
        ActiveSupport::Inflector.camelize(key)
      end

      def ami_client_class_name_from_asterisk_message_type(message_type)
        ActiveSupport::Inflector.camelize(message_type)
      end

      def build_from_raw_ami_message_string(ami_message_string)
        parse_state = :looking_for_message_type
        message = nil

        ami_message_string.lines.map(&:strip).each do |line|
          if (match_data = line.match(MESSAGE_LINE_REGEX))
            key_name = match_data.captures[0]
            value = match_data.captures[1]

            case parse_state
            when :looking_for_message_type
              class_name = ami_client_class_name_from_asterisk_message_type(value)
              message_class = AmiClient::Messages.const_get(class_name)
              message = message_class.new(value)
              parse_state = :looking_for_key_values
            when :looking_for_key_values
              attribute_setter_method_name = "#{asterisk_key_to_ami_client_key(key_name)}="
              message&.send(attribute_setter_method_name, value)
            end
          end
        end

        message
      end

      def build(type, &block)
        self.new(type).tap(&block)
      end
    end

    def initialize(type)
      @type = type
    end

    def to_s
    end
  end

  class Action < AmiClient::AbstractMessage
  end

  class Event < AmiClient::AbstractMessage
  end

  module Messages
    %w[
      Login
    ].each do |action_name|
      AmiClient::Messages.const_set(
        AmiClient::AbstractMessage.ami_client_class_name_from_asterisk_message_type(action_name),
        Class.new(AmiClient::Action)
      )
    end

    %w[
      Newstate
    ].each do |event_name|
      AmiClient::Messages.const_set(
        AmiClient::AbstractMessage.ami_client_class_name_from_asterisk_message_type(event_name),
        Class.new(AmiClient::Event)
      )
    end
  end

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
      login_action
    end

    private

    def login_action
      AmiClient::Action.build(:login) do |a|
        a.username = @user
        a.secret = @pass
      end
    end

    def tcp_socket
      @tcp_socket ||= TCPSocket.new(@host, @port)
    end

    def login!
      return if @logged_in
    end
  end
end
