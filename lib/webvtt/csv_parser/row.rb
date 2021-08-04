# frozen_string_literal: true

module WebVTT
  class CSVParser
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
        when /^\d{1}:\d{2}:\d{2}$/        then "0#{value}.000"
        when /^\d{2}:\d{2}.\d{3}$/        then "00:#{value}"
        when /^\d{2}:\d{2}$/              then "00:#{value}.000"
        when /^\d{2}\.\d{3}$/             then "00:00:#{value}"
        when /^\d{2}$/                    then "00:00:#{value}.000"
        else
          raise TimestampFormattingError.new(value: value, line: line_number)
        end
      end
    end
  end
end
