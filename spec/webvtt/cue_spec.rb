# frozen_string_literal: true

RSpec.describe WebVTT::Cue do
  subject(:cue) do
    described_class.new(start_time: start_time,
                        end_time: end_time,
                        identifier: identifier,
                        captions: captions,
                        settings: settings)
  end
  let(:start_time) { '00:00:00' }
  let(:end_time) { '00:00:02' }
  let(:identifier) { nil }
  let(:captions) do
    [WebVTT::Caption.new(speaker: 'Cool Dog', text: 'Woof!')]
  end
  let(:settings) { nil }

  describe '#start_time_seconds' do
    subject { cue.start_time_seconds }

    let(:start_time) { '01:23:45' }

    it { is_expected.to eq 5025.0 }
  end

  describe '#end_time_seconds' do
    subject { cue.end_time_seconds }

    let(:end_time) { '01:23:45' }

    it { is_expected.to eq 5025.0 }
  end

  describe '#to_s' do
    subject { cue.to_s }

    context 'when all of the pieces are present' do
      let(:identifier) { 'Monologue' }
      let(:settings) { { align: 'start' } }
      let(:expected_text) do
        "Monologue\n00:00:00 --> 00:00:02 align:start\n<v Cool Dog>Woof!</v>"
      end

      it { is_expected.to eq expected_text }
    end

    context 'when no identifier' do
      let(:settings) { { align: 'start' } }
      let(:expected_text) do
        "00:00:00 --> 00:00:02 align:start\n<v Cool Dog>Woof!</v>"
      end

      it { is_expected.to eq expected_text }
    end

    context 'when no settings' do
      let(:expected_text) { "00:00:00 --> 00:00:02\n<v Cool Dog>Woof!</v>" }

      it { is_expected.to eq expected_text }
    end

    context 'with just a timestamp and caption' do
      let(:captions) { [WebVTT::Caption.new(text: 'Hello')] }

      it { is_expected.to eq "00:00:00 --> 00:00:02\nHello" }
    end

    context 'with multiple captions' do
      let(:captions) { [WebVTT::Caption.new(text: 'Hello'), WebVTT::Caption.new(text: 'Hi!')] }

      it { is_expected.to eq "00:00:00 --> 00:00:02\n- Hello\n- Hi!" }
    end
  end
end
