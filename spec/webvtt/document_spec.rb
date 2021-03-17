# frozen_string_literal: true
RSpec.describe WebVTT::Document do
  let(:document) { described_class.new(cues: cues, style: style) }
  let(:style) { [] }
  let(:cues) do
    [
      WebVTT::Cue.new(start_time: '00:00:00.000', end_time: '00:00:01.000', captions: [WebVTT::Caption.new(text: 'Woof!', speaker: 'Dog')]),
      WebVTT::Cue.new(start_time: '00:00:05.000', end_time: '00:00:06.000', captions: [WebVTT::Caption.new(text: 'Meow!', speaker: 'Cat')])
    ]
  end

  describe '#to_s' do
    subject { document.to_s }

    let(:expected_vtt_doc) do
      "WEBVTT\n" \
      "\n" \
      "00:00:00.000 --> 00:00:01.000\n" \
      "<v Dog>Woof!</v>\n" \
      "\n" \
      "00:00:05.000 --> 00:00:06.000\n" \
      "<v Cat>Meow!</v>"
    end

    it { is_expected.to eq expected_vtt_doc }
  end
end
