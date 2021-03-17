# frozen_string_literal: true

module WebVTT
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
  end
end
