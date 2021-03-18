# frozen_string_literal: true

require 'webvtt'
require 'optparse'
require 'colorize'

# Class used to power the +csv2vtt+ executable to convert CSV files to VTTs.
class WebVTT::CSVParser::CLI
  def initialize(args = ARGV, key_map: WebVTT::CSVParser::DEFAULT_KEY_MAP)
    @args = args.dup
    @key_map = key_map
  end

  def run!
    @options = parse_options
    ensure_output_is_file!

    document = csv_parser.parse

    # handle_errors will exit, so we don't need to add an else statement
    handle_errors(csv_parser.errors) if document.nil?

    write_file_and_exit!(document)
  rescue Errno::ENOENT => e
    handle_errors([e])
  end

  private

  def csv_parser
    @csv_parser ||= WebVTT::CSVParser.new(path: @options[:input], key_map: @key_map)
  end

  def ensure_output_is_file!
    return unless File.directory?(@options[:output])

    @options[:output] = File.join(@options[:output], "#{File.basename(@options[:input], '.*')}.vtt")
  end

  def handle_errors(errors)
    message "Encountered #{errors.count} error#{'s' unless errors.count == 1}:s"
    errors.each { |error| error_message error.message }

    exit 1
  end

  def error_message(str, pad: 0)
    puts (' ' * pad) + str.colorize(background: :magenta, color: :black)
  end

  def message(str, pad: 0)
    puts (' ' * pad) + str.colorize(color: :blue)
  end

  def option_parser
    OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] <input csv file>"
      opts.on('-oOUT', '--output=OUT')
      opts.on('-h', '--help') do
        puts opts
        exit 0
      end
    end
  end

  def parse_options
    options = {}
    input_file = option_parser.parse(@args, into: options).first
    raise ArgumentError, 'Input file is missing' if input_file.nil?

    options[:output] ||= Dir.pwd
    options[:input] = input_file
    options
  end

  def write_file_and_exit!(document)
    File.open(@options[:output], 'w') { |io| io.puts(document) }

    message("Wrote VTT content to #{@options[:output]}")

    exit 0
  end
end
