# frozen_string_literal: true

RSpec.describe WebVTT::Comment do
  subject(:comment) { described_class.new(text) }

  let(:text) { nil }

  describe '#to_s' do
    subject { comment.to_s }

    context 'when a comment is present' do
      let(:text) { 'A comment or note' }

      it { is_expected.to eq "NOTE\n#{text}" }
    end

    context 'when no comment' do
      it { is_expected.to be nil }
    end
  end
end
