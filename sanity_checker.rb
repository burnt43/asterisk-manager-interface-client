require 'socket'
require 'hashie'
require 'active_support/inflector'
require 'asterisk-manager-interface-client.rb'

client = AmiClient::Client.new('pbx', user: 'james', pass: 'mako*beam')

client.on_message = ->(message) {
}

client.read!
