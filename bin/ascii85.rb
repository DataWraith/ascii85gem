#!/usr/bin/env ruby
# encoding: utf-8

require "optparse"
require File.join(File.dirname(__FILE__), '..', 'lib', 'ascii85')

@options = {
  :wrap   => 80,
  :decode => false
}

ARGV.options do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] [file]"

  opts.on( "-w", "--wrap COLUMN", Integer,
          "Wrap lines at COLUMN. Default is 80, use 0 for no wrapping") do |opt|

    @options[:wrap] = opt.abs
    @options[:wrap] = false if opt.zero?
  end

  opts.on( "-d", "--decode", "Decode the input") do
    @options[:decode] = true
  end

  opts.on( "-h", "--help", "Display this help and exit") do
    puts opts
    exit
  end

  opts.on( "--version", "Output version information") do |opt|
    puts "Ascii85 v#{Ascii85::VERSION},\nwritten by Johannes Holzfuß"
    exit
  end

  remaining_args = opts.parse!

  case remaining_args.size
  when 0
    @options[:file] = '-'
  when 1
    @options[:file] = remaining_args.first
  else
    abort "Superfluous operand(s): \"#{remaining_args.join('", "')}\""
  end

end

if @options[:file] == '-'
  $stdin.binmode
  @input = $stdin.read
else
  unless File.exists?(@options[:file])
    abort "File not found: \"#{@options[:file]}\""
  end

  unless File.readable_real?(@options[:file])
    abort "File is not readable: \"#{@options[:file]}\""
  end

  File.open(@options[:file], 'rb') do |f|
    @input = f.read
  end
end

if @options[:decode]
  begin
    print Ascii85::decode(@input)
  rescue Ascii85::DecodingError => error
    abort "Decoding Error: #{error.message.to_s}"
  end
else
  print Ascii85::encode(@input, @options[:wrap])
end
