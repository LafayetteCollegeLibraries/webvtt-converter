# frozen_string_literal: true

require 'csv'
require 'webvtt/cue'
require 'webvtt/csv_parser/errors'
require 'webvtt/csv_parser/row'

module WebVTT
  # Class for converting a CSV file to a WebVTT document.
  class CSVParser
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
