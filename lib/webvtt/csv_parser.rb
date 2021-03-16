# frozen_string_literal: true

require 'csv'
require 'webvtt/cue'

module WebVTT
  # Class for converting a CSV file to a WebVTT document.
  class CSVParser
    # Base error for CSV parsing problems
    class ParsingError < StandardError; end

    # The timestamp sequences of either the previous timestamp and the current timestamp
    # or the current row's start/end times are mismatched (start should always be < end)
    class InvalidTimestampSequenceError < ParsingError
      def initialize(current_timestamp:, previous_timestamp:, line_number:)
        super("Invalid timestamp sequence on Line #{line_number}: "\
              "#{previous_timestamp} can not be greater than #{current_timestamp}")
      end
    end

    # Error raised when one of our expected keys are missing. This can be resolved by passing
    # a custom +key_map+ to the parser.
    #
    # @see {WebVTT::CSVParser.initialize}
    class MissingHeaderKeyError < ParsingError
      def initialize(missing_keys:)
        super("CSV is missing the following header keys: #{format_missing_keys(missing_keys)}")
      end

      def format_missing_keys(keys)
        quoted = keys.map { |v| %("#{v}") }
        return quoted.join(' and ') if quoted.size <= 2

        "#{quoted[0..-2].join(', ')}, and #{quoted[-1]}"
      end
    end

    # Raised if a timestamp is formatted in a way we're not expecting.
    class TimestampFormattingError < ParsingError
      def initialize(value:, line:)
        super("Line #{line}: Unable to parse timestamp from value '#{value}'")
      end
    end

    # Internal transient class for CSV rows to convert to Cues. Some rows may
    # have empty timestamps (used for adding more than one {WebVTT::Caption} to a cue).
    class Row
      attr_reader :timestamp, :speaker, :style, :content, :line_number

      def self.from_csv(row, line_number:, key_map:)
        new(timestamp: row[key_map[:timestamp]],
            speaker: row[key_map[:speaker]],
            content: row[key_map[:content]],
            style: row[key_map[:style]],
            line_number: line_number)
      end

      def initialize(timestamp:, speaker:, style:, content:, line_number:)
        @timestamp = timestamp
        @speaker = speaker
        @style = style
        @content = content
        @line_number = line_number
      end

      def caption
        WebVTT::Caption.new(speaker: speaker, text: content)
      end

      def timestamp?
        !timestamp.nil? && timestamp != ''
      end

      def cue
        return nil unless timestamp?

        start_time, end_time = normalize_timestamp
        WebVTT::Cue.new(start_time: start_time, end_time: end_time, captions: [caption])
      end

      private

      def normalize_timestamp
        timestamp.to_s.split(/[-–—]+/).map(&:chomp).map do |raw|
          case raw
          when /^(\d{2}:)?\d{2}:\d{2}\.\d{3}$/ then raw
          when /^(\d{2}:)?\d{2}:\d{2}$/        then "#{raw}.000"
          when /^\d{2}\.\d{3}$/                then "00:00:#{raw}"
          when /^\d{2}$/                       then "00:00:#{raw}.000"
          else
            raise TimestampFormattingError.new(value: raw, line: line_number)
          end
        end
      end
    end

    # By default, these are the CSV header keys we're expecting to be provided. The input CSV
    # may have other fields, but these four must be represented.
    DEFAULT_KEY_MAP = {
      timestamp: 'Time Stamp',
      speaker: 'Speaker',
      content: 'Text',
      style: 'Style'
    }.freeze

    attr_reader :errors

    # @param [Hash] options
    # @option [String,Pathname] path Path to the input CSV file
    # @option [Hash<Symbol => String>] key_map Dictionary used to provide header fields to the parser
    def initialize(path:, key_map: DEFAULT_KEY_MAP)
      @csv_path = path
      @key_map = key_map
    end

    # @yield [WebVTT::Cue]
    # @raise [WebVTT::CSVParser::InvalidTimestampSequenceError]
    #   if previous_cue timestamp is greater than current_cue timestamp
    # @raise [WebVTT::CSVParser::MissingHeaderKeyError] if any of the key_map values are missing from the csv header
    # @raise [WebVTT::CSVParser::TimestampFormattingError] if row timestamps are formatted in an unexpected way
    # rubocop:disable Metrics/MethodLength
    def parse
      @errors = []
      @cues = []
      line_number = 1
      previous_cue = nil

      parsed_csv.each do |raw_row|
        begin
          line_number += 1
          row = Row.from_csv(raw_row, key_map: @key_map, line_number: line_number)

          current_cue = extract_cue(row)
          validate_timestamps!(current_cue: current_cue, previous_cue: previous_cue, line_number: line_number)

          yield previous_cue if block_given? && previous_cue != current_cue

          previous_cue = current_cue
        rescue ParsingError => e
          @errors << e
        end
      end

      @cues unless @errors.size
    end
    # rubocop:enable Metrics/MethodLength

    private

    def check_headers!(supplied_headers)
      missing_keys = @key_map.values - supplied_headers
      raise MissingHeaderKeyError.new(missing_keys: missing_keys) unless missing_keys.empty?

      @need_to_check_headers = false
    end

    def extract_cue(row)
      cue = row.cue

      if cue.nil? && @cues.size
        caption = row.caption
        @cues.last.captions << caption
      else
        @cues << cue
      end

      @cues.last
    end

    # @return [CSV::Table]
    # @raise [WebVTT::CSVParser::MissingHeaderKeyError]
    def parsed_csv
      parsed = CSV.parse(File.read(@csv_path), headers: true)
      check_headers!(parsed.headers)

      parsed
    end

    def validate_timestamps!(current_cue:, previous_cue:, line_number:)
      # check previous_row.end_time vs current_cue.start_time
      if (previous_cue.nil? || current_cue == previous_cue) &&
         current_cue.end_time_seconds <= current_cue.start_time_seconds
        raise InvalidTimestampSequenceError.new(current_timestamp: current_cue.end_time,
                                                previous_timestamp: current_cue.start_time,
                                                line_number: line_number)

      elsif current_cue.start_time_seconds <= previous_cue.end_time_seconds
        raise InvalidTimestampSequenceError.new(current_timestamp: current_cue.start_time,
                                                previous_timestamp: previous_cue.end_time,
                                                line_number: line_number)
      end
    end
  end
end
