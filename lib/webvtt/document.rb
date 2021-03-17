# frozen_string_literal: true

module WebVTT
  # Container class to combine style + cue nodes in a single document
  class Document
    attr_accessor :cues, :style

    def initialize(cues: [], style: [])
      @cues = cues
      @style = style
    end

    def to_s
      ([header] + @style + @cues).join("\n\n")
    end

    private

    def header
      'WEBVTT'
    end
  end
end
