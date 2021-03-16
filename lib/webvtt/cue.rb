# frozen_string_literal: true

module WebVTT
  # Small wrapper class for captions. When a caption has a speaker, their name
  # is put into a +<v>+ tag to identify them.
  class Caption
    attr_reader :speaker, :text

    # @param [Hash] options
    # @option [String] speaker
    # @option [String] text
    def initialize(speaker: nil, text: nil)
      @speaker = speaker
      @text = text
    end

    # @return [true, false]
    def speaker?
      !speaker.nil? && speaker != ''
    end

    # @return [String]
    def to_string
      return unless text
      return text unless speaker?

      "<v #{speaker}>#{text}</v>"
    end

    alias to_s to_string
  end

  # Teeniest class to wrap comments
  class Comment
    def initialize(text)
      @text = text
    end

    def to_string
      return if @text.nil? || @text == ''

      "NOTE\n#{@text}"
    end

    alias to_s to_string
  end

  # Wrapper class to normalize cue-settings
  class CueSettings
    def initialize(settings = {})
      @settings = settings
    end

    def empty?
      @settings.nil? || @settings.empty?
    end

    def to_string
      return '' if empty?

      @settings.keep_if { |key, _val| valid_keys.include?(key.to_sym) }
               .map { |key, val| "#{key}:#{val}" }
               .join(' ')
    end
    alias to_s to_string

    private

    def valid_keys
      %i[vertical line position size align region]
    end
  end

  # Main class for VTT cue objects
  #
  # @example
  #   cue = Cue.new(start_time: '00:00:01',
  #                 end_time: '00:00:02',
  #                 captions: [WebVTT::Caption.new(text: 'Hello!', speaker: 'Narrator')])
  #   cue.to_s
  #   # => "00:00:01.000 --> 00:00:02.000\n<v Narrator>Hello!</v>"
  class Cue
    attr_reader :start_time, :end_time, :speaker, :identifier
    attr_accessor :captions, :settings

    # @param [Hash] options
    # @option [String] start_time
    # @option [String] end_time
    # @option [String] identifier
    # @option [Array<WebVTT::Caption>] captions
    # @option [Hash, CueSettings] settings
    def initialize(start_time:, end_time:, identifier: nil, captions: [], settings: {})
      @start_time = start_time
      @end_time = end_time
      @identifier = identifier
      @captions = captions
      @settings = settings.is_a?(CueSettings) ? settings : CueSettings.new(settings)
      @speaker = speaker
    end

    # Used for sorting, converts +start_time+ to seconds
    #
    # @return [Float]
    def start_time_seconds
      @start_time_seconds ||= timestamp_to_seconds(start_time)
    end

    # Used for sorting, converts +end_time+ to seconds
    #
    # @return [Float]
    def end_time_seconds
      @end_time_seconds ||= timestamp_to_seconds(end_time)
    end

    # @return [String]
    def to_string
      [identifier, timestamp_and_settings, annotated_captions].compact.join("\n")
    end
    alias to_s to_string

    private

    # In instances where we have multiple captions, we'll display each
    # on a new-line with a hyphen prefix
    #
    # @return [String]
    def annotated_captions
      return captions.first.to_s unless captions.size > 1

      captions.map { |caption| "- #{caption}" }.join("\n")
    end

    # @return [String]
    def timestamp
      "#{start_time} --> #{end_time}"
    end

    # timestamp and settings concatted.
    #
    # @return [String]
    def timestamp_and_settings
      return timestamp if settings.empty?

      "#{timestamp} #{settings}"
    end

    def timestamp_to_seconds(timestamp)
      hours, minutes, seconds = timestamp.split(':').map(&:to_f)
      (hours * 3600) + (minutes * 60) + seconds
    end
  end
end
