# frozen_string_literal: true

RSpec.describe WebVTT::Caption do
  subject(:caption) { described_class.new(speaker: speaker, text: text) }

  let(:speaker) { 'Speaker' }
  let(:text) { 'Huh?' }

  describe '#to_s' do
    subject { caption.to_s }

    context 'when speaker is present' do
      it { is_expected.to eq '<v Speaker>Huh?</v>' }
    end

    context 'when no speaker present' do
      let(:speaker) { nil }

      it { is_expected.to eq 'Huh?' }
    end
  end
end
