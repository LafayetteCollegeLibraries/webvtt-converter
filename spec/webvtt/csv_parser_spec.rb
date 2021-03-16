# frozen_string_literal: true

RSpec.describe WebVTT::CSVParser do
  subject(:cues) { parser.parse }

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

    it { is_expected.to be_an(Array) }

    it 'produces a Cue object for each line' do
      expect(cues.size).to eq 1
      expect(cues.first).to be_a(WebVTT::Cue)
    end
  end

  context 'cue with multiple captions' do
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

    it 'produces a Cue object with two captions' do
      expect(cues.first.to_s).to eq cue_str
    end
  end

  describe 'different timestamp handling' do
    subject(:cue) { parser.parse.first.to_s }

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
    describe 'timestamp formatting' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        '00:001:00-00:02:00,Cool Dog,Woof!,'
      end

      it 'raises a TimestampFormattingError' do
        expect { parser.parse }.to raise_error(WebVTT::CSVParser::TimestampFormattingError)
      end
    end

    describe 'invalid timestamp sequence' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        "00:10:00-00:12:00,,Hi there,\n" \
        '00:08:00-00:09:00,,Sup?'
      end

      it 'raises an InvalidTimestampSequenceError' do
        expect { parser.parse }.to raise_error(WebVTT::CSVParser::InvalidTimestampSequenceError)
      end
    end

    describe 'invalid cue timestamp sequence' do
      let(:csv_content) do
        "Time Stamp,Speaker,Text,Style\n" \
        '00:10:00-00:08:00,,Hi!,'
      end

      it 'raises an InvalidTimestampSequenceError' do
        expect { parser.parse }.to raise_error(WebVTT::CSVParser::InvalidTimestampSequenceError)
      end
    end

    describe 'missing header keys' do
      let(:csv_content) do
        "Times,Content\n00:00:00-00:01:00,Hi there"
      end

      it 'raises a MissingHeaderKeyError' do
        expect { parser.parse }
          .to raise_error(WebVTT::CSVParser::MissingHeaderKeyError, /"Time Stamp", "Speaker", "Text", and "Style"/)
      end
    end
  end
end
