# frozen_string_literal: true

RSpec.describe WebVTT::CSVParser do
  subject(:document) { parser.parse }

  let(:parser) { described_class.new(path: file_path) }
  let(:file_path) { '/path/to/file.csv' }
  let(:csv_content) { '' }

  before do
    allow(File).to receive(:read).with(file_path).and_return(csv_content)
  end

  context 'simple cue' do
    let(:csv_content) do
      "Time Stamp,Speaker,Text,Style\n" \
      '00:00:00-00:00:02,Cool Dog,Woof!,'
    end

    it { is_expected.to be_an(WebVTT::Document) }

    it 'adds a Cue object for each line' do
      # require 'byebug'; byebug
      expect(document).to respond_to(:cues)
      expect(document.cues.size).to eq 1
      expect(document.cues.first).to be_a(WebVTT::Cue)
    end
  end

  context 'cue with multiple captions' do
    subject { document.cues.first.to_s }

    let(:csv_content) do
      "Time Stamp,Speaker,Text,Style\n" \
      "00:00:00-00:00:02,Cool Dog,Woof!,\n" \
      ',Cool Cat,Meow!'
    end

    let(:cue_str) do
      WebVTT::Cue.new(start_time: '00:00:00.000',
                      end_time: '00:00:02.000',
                      captions: [
                        WebVTT::Caption.new(speaker: 'Cool Dog', text: 'Woof!'),
                        WebVTT::Caption.new(speaker: 'Cool Cat', text: 'Meow!')
                      ]).to_s
    end

    it { is_expected.to eq cue_str }
  end

  describe 'different timestamp handling' do
    subject(:cue) { document.cues.first.to_s }

    let(:csv_content) do
      "Time Stamp,Speaker,Text,Style\n" \
      "#{start_time}-#{end_time},Cool Dog,Woof!,"
    end

    let(:formatted_cue) do
      "00:00:30.000 --> 00:00:32.000\n<v Cool Dog>Woof!</v>"
    end

    context 'with trailing milliseconds' do
      let(:start_time) { '00:00:30.000' }
      let(:end_time) { '00:00:32.000' }

      it { is_expected.to eq formatted_cue }
    end

    context 'without trailing milliseconds' do
      let(:start_time) { '00:00:30' }
      let(:end_time) { '00:00:32' }

      it { is_expected.to eq formatted_cue }
    end

    context 'only seconds + milliseconds' do
      let(:start_time) { '30.000' }
      let(:end_time) { '32.000' }

      it { is_expected.to eq formatted_cue }
    end

    context 'only seconds' do
      let(:start_time) { '30' }
      let(:end_time) { '32' }

      it { is_expected.to eq formatted_cue }
    end
  end

  describe 'error handling' do
    subject(:error) { parser.errors.first }

    before do
      parser.parse

      # ensure that we got an error each time
      expect(parser.errors.size).to eq 1
    end

    describe 'timestamp formatting' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        '00:001:00-00:02:00,Cool Dog,Woof!,'
      end

      it 'stores a TimestampFormattingError' do
        expect(error).to be_a(WebVTT::CSVParser::TimestampFormattingError)
        expect(error.message).to eq "Line 2: Unable to parse timestamp from value '00:001:00'"
      end
    end

    describe 'invalid timestamp sequence' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        "00:10:00-00:12:00,,Hi there,\n" \
        '00:08:00-00:09:00,,Sup?,'
      end

      it 'raises an InvalidTimestampSequenceError' do
        expect(error).to be_a(WebVTT::CSVParser::InvalidTimestampSequenceError)
        expect(error.message)
          .to eq "Invalid timestamp sequence on Lines 2, 3: " \
                 "current start timestamp is 00:08:00.000 and the previous one was 00:12:00.000"
      end
    end

    describe 'invalid cue timestamp sequence' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        '00:10:00-00:08:00,,Hi!,'
      end

      it 'raises an InvalidTimestampRangeError' do
        expect(error).to be_a(WebVTT::CSVParser::InvalidTimestampRangeError)
        expect(error.message)
          .to eq "Invalid timestamp range on Line 2: 00:08:00.000 can not come before 00:10:00.000"
      end
    end

    describe 'missing header keys' do
      let(:csv_content) do
        "Times,Content\n00:00:00-00:01:00,Hi there"
      end

      it 'raises a MissingHeaderKeyError' do
        expect(error).to be_a(WebVTT::CSVParser::MissingHeaderKeyError)
        expect(error.message)
          .to eq 'CSV is missing the following header keys: "Time Stamp", "Speaker", "Text", and "Style"'
      end
    end
  end
end
