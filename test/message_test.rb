require './test/test_helper.rb'

class MessageTest < AmiClient::Testing::Test
  def test_build_from_raw_ami_message_string
    raw_message =
      "Event: Newstate\n" \
      "Privilege: call,all\n" \
      "Channel: PJSIP/496-mttpbx-0001131b\n" \
      "ChannelState: 5\n" \
      "ChannelStateDesc: Ringing\n" \
      "CallerIDNum: 496\n" \
      "CallerIDName: Mike OLeary\n" \
      "ConnectedLineNum: 7327041400\n" \
      "ConnectedLineName: 7327041400\n" \
      "Language: en\n" \
      "AccountCode: mttpbx\n" \
      "Context: sip-outbound-mttpbx\n" \
      "Exten: s\n" \
      "Priority: 1\n" \
      "Uniqueid: 1612459029.204043\n" \
      "Linkedid: 1612459028.204037\n"

    result = AmiClient::AbstractMessage.build_from_raw_ami_message_string(raw_message)

    assert_instance_of(AmiClient::Messages::Newstate, result)
    assert_equal('call,all',                  result.privilege)
    assert_equal('PJSIP/496-mttpbx-0001131b', result.channel)
    assert_equal('5',                         result.channel_state)
    assert_equal('Ringing',                   result.channel_state_desc)
    assert_equal('496',                       result.caller_id_num)
    assert_equal('Mike OLeary',               result.caller_id_name)
    assert_equal('7327041400',                result.connected_line_num)
    assert_equal('7327041400',                result.connected_line_name)
    assert_equal('en',                        result.language)
    assert_equal('mttpbx',                    result.account_code)
    assert_equal('sip-outbound-mttpbx',       result.context)
    assert_equal('s',                         result.exten)
    assert_equal('1',                         result.priority)
    assert_equal('1612459029.204043',         result.uniqueid)
    assert_equal('1612459028.204037',         result.linkedid)
  end

  def test_build_from_raw_ami_message_string_with_unknown_type
    raw_message =
      "Event: Doesnotexist\n" \
      "Foo: bar\n" \

    result = AmiClient::AbstractMessage.build_from_raw_ami_message_string(raw_message)

    assert_nil(result)
  end

  def test_to_ami_message_string
    login_message = AmiClient::Messages::Login.build do |m|
      m.username = 'joe123'
      m.secret   = 'mak0*beam'
    end

    string = login_message.to_ami_message_string
    lines = string.lines.map(&:chomp)

    assert_equal('Action: Login',     lines[0])
    assert_equal('Username: joe123',  lines[1])
    assert_equal('Secret: mak0*beam', lines[2])
    assert_equal('',                  lines[3])
  end
end
