# frozen_string_literal: true

require 'csv'
require 'webvtt/cue'

module WebVTT
  # Class for converting a CSV file to a WebVTT document.
  class CSVParser
    # Base error for CSV parsing problems
    class ParsingError < StandardError; end

    # Raised when the timestamps of a single row are off (end time is lower than start time)
    #
    # @see {WebVTT::CSVParser#validate_timestamps!}
    class InvalidTimestampRangeError < ParsingError
      def initialize(cue:, line_number:)
        super("[Line #{line_number}] Invalid timestamp range: " \
              "\"#{cue.end_time}\" can not come before \"#{cue.start_time}\"")
      end
    end

    # Raised when the previous cue's end time is higher than the current cue's start time
    class InvalidTimestampSequenceError < ParsingError
      def initialize(current_cue:, previous_cue:, line_number:)
        super("[Line #{line_number}] Invalid timestamp sequence: " \
              "Current starting timestamp (\"#{current_cue.start_time}\") " \
              "can not be earlier than the line previous (\"#{previous_cue.start_time}\")")
      end
    end

    # Error raised when one of our expected keys are missing. This can be resolved by passing
    # a custom +key_map+ to the parser.
    #
    # @see {WebVTT::CSVParser.initialize}
    class MissingHeaderKeyError < ParsingError
      def initialize(missing_keys:)
        super("[Line 1] CSV is missing the following header keys: #{format_missing_keys(missing_keys)}")
      end

      def format_missing_keys(keys)
        quoted = keys.map { |v| %("#{v}") }
        return quoted.join(' and ') if quoted.size <= 2

        "#{quoted[0..-2].join(', ')}, and #{quoted[-1]}"
      end
    end

    # Error raised when a row in the input CSV only includes a single timestamp
    class MissingTimestampError < ParsingError
      def initialize(row)
        super(%([Line #{row.line_number}] Missing start or end timestamp value from "#{row.timestamp}"))
      end
    end

    # Raised if a timestamp is formatted in a way we're not expecting.
    class TimestampFormattingError < ParsingError
      def initialize(value:, line:)
        super(%([Line #{line}] Unable to parse timestamp from value "#{value}"))
      end
    end

    # Internal transient class for CSV rows to convert to Cues. Some rows may
    # have empty timestamps (used for adding more than one {WebVTT::Caption} to a cue).
    class Row
      attr_reader :timestamp, :speaker, :settings, :content, :line_number

      def initialize(timestamp:, speaker:, content:, line_number:, settings: {})
        @timestamp = timestamp
        @speaker = speaker
        @settings = settings
        @content = content
        @line_number = line_number
      end

      def caption
        WebVTT::Caption.new(speaker: speaker, text: escaped_content)
      end

      def timestamp?
        !timestamp.nil? && timestamp != ''
      end

      # @return [WebVTT::Cue, nil]
      # @raise [WebVTT::CSVParser::MissingTimestampError] if only one timestamp is found
      # @raise [WebVTT::CSVParser::TimestampFormattingError] if we receive a timestamp formatted in an unexpected way
      def cue
        return nil unless timestamp?

        start_time, end_time = normalize_timestamps
        WebVTT::Cue.new(start_time: start_time, end_time: end_time, captions: [caption], settings: settings)
      end

      private

      # Strips cue text content of illegal characters
      #
      # @return [String]
      # @see https://w3c.github.io/webvtt/#webvtt-cue-text-span
      def escaped_content
        content.gsub(/&/, '&amp;').gsub(/</, '&lt;').strip
      end

      def normalize_timestamps
        timestamps = timestamp.to_s.split(/[-–—]+/).map(&:strip)
        raise(MissingTimestampError, self) if timestamps.size < 2

        timestamps.map { |raw| normalize_timestamp(raw) }
      end

      def normalize_timestamp(value)
        case value
        when /^\d{2}:\d{2}:\d{2}\.\d{3}$/ then value
        when /^\d{2}:\d{2}:\d{2}$/        then "#{value}.000"
        when /^\d{2}:\d{2}.\d{3}$/        then "00:#{value}"
        when /^\d{2}:\d{2}$/              then "00:#{value}.000"
        when /^\d{2}\.\d{3}$/             then "00:00:#{value}"
        when /^\d{2}$/                    then "00:00:#{value}.000"
        else
          raise TimestampFormattingError.new(value: value, line: line_number)
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
          row = row_from_csv(raw_row, line: line_number)
          current_cue = extract_and_store_cue(row)

          validate_timestamps!(current_cue: current_cue, previous_cue: previous_cue, line_number: line_number)

          yield previous_cue if block_given? && previous_cue != current_cue

          previous_cue = current_cue
        rescue ParsingError => e
          @errors << e
        end
      end

      WebVTT::Document.new(cues: @cues) if @errors.size.zero?
    end
    # rubocop:enable Metrics/MethodLength

    private

    # Checks the incoming CSV headers against the key_map's values and alerts
    # us if any keys are missing.
    #
    # @param [Array<Symbol>] supplied_headers
    # @return [void]
    # @raise [WebVTT::CSVParser::MissingHeaderKeyError]
    def check_headers!(supplied_headers)
      missing_keys = @key_map.values - supplied_headers
      raise MissingHeaderKeyError.new(missing_keys: missing_keys) unless missing_keys.empty?
    end

    # @param [WebVTT::CSVParser::Row] row
    # @return [WebVTT::Cue,nil]
    def extract_cue_from_row(row)
      cue = row.cue
      return if cue.nil?

      cue
    end

    # @param [WebVTT::CSVParser::Row] row
    # @return [WebVTT::Cue]
    def extract_and_store_cue(row)
      cue = extract_cue_from_row(row)

      if cue.nil? && !@cues.empty?
        caption = row.caption
        @cues.last.captions << caption
      else
        @cues << cue
      end

      @cues.last
    end

    # Reads and parses the CSV file. If that file does not have all of the required headers
    # we'll add the error to +@errors+ and return an empty array so the +#each+ block within +#parse+ doesn't fail.
    #
    # @return [CSV::Table, Array]
    # @see {WebVTT::CSVParser#check_headers!}
    def parsed_csv
      parsed = CSV.parse(File.read(@csv_path), headers: true)
      check_headers!(parsed.headers)

      parsed
    rescue MissingHeaderKeyError => e
      @errors ||= [] # just in case
      @errors << e

      []
    end

    # generates a Row object from the CSV::Row object
    #
    # @param [CSV::Row] csv
    # @param [Hash] options
    # @option [Number] line
    # @return [WebVTT::CSVParser::Row]
    def row_from_csv(csv, line:)
      row_args = %i[timestamp speaker settings content].each_with_object({}) do |key, args|
        args[key] = csv[@key_map[key]]
        args
      end

      Row.new(line_number: line, **row_args)
    end

    # @param [Hash] options
    # @option [WebVTT::Cue] current_cue
    # @option [WebVTT::Cue] previous_cue
    # @option [Number] line_number
    # @return [void]
    # @raise [InvalidTimestampRangeError] if current_cue's end_time is before its start_time
    #
    # rubocop:disable Layout/LineLength
    def validate_timestamps!(current_cue:, previous_cue:, line_number:)
      raise InvalidTimestampRangeError.new(cue: current_cue, line_number: line_number) if
        current_cue.end_time_seconds < current_cue.start_time_seconds

      return if previous_cue.nil? || current_cue == previous_cue

      raise InvalidTimestampSequenceError.new(current_cue: current_cue, previous_cue: previous_cue, line_number: line_number) if
        previous_cue.start_time_seconds > current_cue.start_time_seconds
    end
    # rubocop:enable Layout/LineLength
  end
end
