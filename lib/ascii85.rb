# frozen_string_literal: true

require 'stringio'

#
# Ascii85 is an implementation of Adobe's binary-to-text encoding of the
# same name in pure Ruby.
#
# See http://en.wikipedia.org/wiki/Ascii85 for more information about the
# format.
#
# Author::  Johannes Holzfuß (johannes@holzfuss.name)
# License:: Distributed under the MIT License (see LICENSE file)
#
module Ascii85
  class << self
    #
    # Encodes the bytes of the given String as Ascii85.
    #
    # If +wrap_lines+ evaluates to +false+, the output will be returned as a
    # single long line. Otherwise +#encode+ formats the output into lines of
    # length +wrap_lines+ (minimum is 2, default is 80).
    #
    #     Ascii85.encode("Ruby")
    #     => <~;KZGo~>
    #
    #     Ascii85.encode("Supercalifragilisticexpialidocious", 15)
    #     => <~;g!%jEarNoBkD
    #        BoB5)0rF*),+AU&
    #        0.@;KXgDe!L"F`R
    #        ~>
    #
    #     Ascii85.encode("Supercalifragilisticexpialidocious", false)
    #     => <~;g!%jEarNoBkDBoB5)0rF*),+AU&0.@;KXgDe!L"F`R~>
    #
    #
    def encode(str, wrap_lines = 80, out: nil)
      if str.is_a?(IO)
        reader = str
      else
        reader = StringIO.new(str.to_s, 'rb')
      end

      bufreader = BufferedReader.new(reader, unencoded_chunk_size)
      bufwriter = BufferedWriter.new(out || StringIO.new(String.new, 'wb'), encoded_chunk_size)

      padding = "\0" * 4
      tuplebuf = '!!!!!'.dup

      writer = wrap_lines ? Wrapper.new(bufwriter, wrap_lines) : DummyWrapper.new(bufwriter)

      is_empty = true
      bufreader.each_chunk do |chunk|
        is_empty = false
        
        chunk.unpack('N*').each do |word|
          if word.zero?
            writer.write('z')
          else
            word, b0 = word.divmod(85)
            word, b1 = word.divmod(85)
            word, b2 = word.divmod(85)
            word, b3 = word.divmod(85)
            b4 = word 

            tuplebuf.setbyte(0, b4 + 33)
            tuplebuf.setbyte(1, b3 + 33)
            tuplebuf.setbyte(2, b2 + 33)
            tuplebuf.setbyte(3, b1 + 33)
            tuplebuf.setbyte(4, b0 + 33)

            writer.write(tuplebuf)
          end
        end

        next if (chunk.bytesize & 0b11).zero?

        padding_length = (-chunk.bytesize) % 4

        trailing = chunk[-(4 - padding_length)..]
        word =  (trailing + padding[0...padding_length]).unpack1('N')

        if word.zero?
          writer.write('!!!!!'[0..(4 - padding_length)])
        else
          word, b0 = word.divmod(85)
          word, b1 = word.divmod(85)
          word, b2 = word.divmod(85)
          word, b3 = word.divmod(85)
          b4 = word 

          tuplebuf.setbyte(0, b4 + 33)
          tuplebuf.setbyte(1, b3 + 33)
          tuplebuf.setbyte(2, b2 + 33)
          tuplebuf.setbyte(3, b1 + 33)
          tuplebuf.setbyte(4, b0 + 33)

          writer.write(tuplebuf[0..(4 - padding_length)])
        end
      end

      return ''.dup if is_empty
      return writer.finish.io.string if out.nil?

      writer.finish
    end

    #
    # Searches through +str+ and extracts the _first_ substring enclosed by +<~+
    # and +~>+.
    #
    # Returns the empty String if no valid delimiters are found.
    #
    #     Ascii85.extract("Foo<~;KZGo~>Bar<~z~>Baz")
    #     => ";KZGo"
    #
    #     Ascii85.extract("No delimiters")
    #     => ""
    #
    def extract(str)
      input = str.to_s

      # Make sure the delimiter strings have the correct encoding.
      opening_delim = '<~'.encode(input.encoding)
      closing_delim = '~>'.encode(input.encoding)

      # Get the positions of the opening/closing delimiters. If there is no pair
      # of opening/closing delimiters, return an unfrozen empty string.
      (start_pos = input.index(opening_delim))                or return ''.dup
      (end_pos   = input.index(closing_delim, start_pos + 2)) or return ''.dup

      # Get the string inside the delimiter-pair
      input[(start_pos + 2)...end_pos]
    end

    #
    # Searches through +str+ and decodes the _first_ substring enclosed by +<~+
    # and +~>+.
    #
    # +#decode+ expects an Ascii85-encoded String enclosed in +<~+ and +~>+
    # — it will ignore all characters outside these delimiters. The returned
    # String is always encoded as +ASCII-8BIT+.
    #
    #     Ascii85.decode("<~;KZGo~>")
    #     => "Ruby"
    #
    #     Ascii85.decode("Foo<~;KZGo~>Bar<~87cURDZ~>Baz")
    #     => "Ruby"
    #
    #     Ascii85.decode("No delimiters")
    #     => ""
    #
    # Raises Ascii85::DecodingError when malformed input is encountered.
    #
    def decode(str)
      decode_raw(extract(str))
    end

    #
    # Decodes the given raw Ascii85-String.
    #
    # +#decode_raw+ expects an Ascii85-encoded String NOT enclosed in +<~+ and
    # +~>+. The returned String is always encoded as +ASCII-8BIT+.
    #
    #     Ascii85.decode_raw(";KZGo")
    #     => "Ruby"
    #
    # Raises Ascii85::DecodingError when malformed input is encountered.
    #
    def decode_raw(str)
      input = str.to_s

      # Return an unfrozen String on empty input
      return ''.dup if input.empty?

      # Populate the lookup table (caches the exponentiation)
      lut = (0..4).map { |count| 85**(4 - count) }

      # Decode
      word   = 0
      count  = 0
      result = []

      input.each_byte do |c|
        case c.chr
        when ' ', "\t", "\r", "\n", "\f", "\0"
          # Ignore whitespace
          next

        when 'z'
          raise(Ascii85::DecodingError, "Found 'z' inside Ascii85 5-tuple") unless count.zero?

          # Expand z to 0-word
          result << 0

        when '!'..'u'
          # Decode 5 characters into a 4-byte word
          word  += (c - 33) * lut[count]
          count += 1

          if count == 5 && word > 0xffffffff
            raise(Ascii85::DecodingError, "Invalid Ascii85 5-tuple (#{word} >= 2**32)")
          elsif count == 5
            result << word

            word  = 0
            count = 0
          end

        else
          raise(Ascii85::DecodingError, "Illegal character inside Ascii85: #{c.chr.dump}")
        end
      end

      # Convert result into a String
      result = result.pack('N*')

      # We're done if all 5-tuples have been consumed
      return result if count.zero?

      raise(Ascii85::DecodingError, 'Last 5-tuple consists of single character') if count == 1

      # Finish last, partially decoded 32-bit word
      count -= 1
      word  += lut[count]

      result << ((word >> 24) & 0xff).chr if count >= 1
      result << ((word >> 16) & 0xff).chr if count >= 2
      result << ((word >> 8) & 0xff).chr if count == 3

      result
    end

    private

    class BufferedReader
      def initialize(io, buffer_size)
        @io = io
        @buffer_size = buffer_size
      end

      def each_chunk
        return enum_for(:each_chunk) unless block_given?

        until @io.eof?
          chunk = @io.read(@buffer_size)
          yield chunk if chunk
        end
      end
    end

    class BufferedWriter
      attr_accessor :io

      def initialize(io, buffer_size)
        @io = io
        @buffer_size = buffer_size
        @buffer = String.new(capacity: buffer_size)
      end

      def write(tuple)
        flush if @buffer.bytesize + tuple.bytesize > @buffer_size
        @buffer << tuple
      end

      def flush
        @io.write(@buffer)
        @buffer.clear
      end
    end

    class DummyWrapper
      def initialize(out)
        @out = out
        @out.write('<~')
      end

      def write(buffer)
        @out.write(buffer)
      end

      def finish
        @out.write('~>')
        @out.flush

        @out
      end
    end

    class Wrapper
      def initialize(out, wrap_lines)
        @line_length = [2, wrap_lines.to_i].max

        @out = out
        @out.write('<~')

        @cur_len = 2
      end

      def write(buffer)
        loop do
          s = buffer.bytesize

          if @cur_len + s < @line_length
            @out.write(buffer)
            @cur_len += s
            return
          end

          remaining = @line_length - @cur_len
          @out.write(buffer[0...remaining])
          @out.write("\n")
          @cur_len = 0
          buffer = buffer[remaining..]
          return if buffer.empty?
        end
      end

      def finish
        # Add the closing delimiter (may need to be pushed to the next line)
        @out.write("\n") if @cur_len + 2 > @line_length
        @out.write('~>')
        @out.flush

        @out
      end
    end

    def unencoded_chunk_size
      4 * 2048
    end

    def encoded_chunk_size
      5 * 2048
    end
  end

  #
  # This error is raised when Ascii85 encounters one of the following problems
  # in the input:
  #
  # * An invalid character. Valid characters are '!'..'u' and 'z'.
  # * A 'z' character inside a 5-tuple. 'z's are only valid on their own.
  # * An invalid 5-tuple that decodes to >= 2**32
  # * The last tuple consisting of a single character. Valid tuples always have
  #   at least two characters.
  #
  class DecodingError < StandardError; end
end
