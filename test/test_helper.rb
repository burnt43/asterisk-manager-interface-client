require 'minitest/pride'
require 'minitest/autorun'

require 'active_support/inflector'
require 'hashie'
require 'socket'

require './lib/asterisk-manager-interface-client'

module AmiClient
  module Testing
    class Test < Minitest::Test
    end
  end
end
