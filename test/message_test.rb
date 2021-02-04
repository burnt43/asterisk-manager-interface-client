require './test/test_helper.rb'

class MessageTest < AmiClient::Testing::Test
  def test_foobar
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
  end
end
