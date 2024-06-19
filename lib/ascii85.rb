# frozen_string_literal: true

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
  #
  # Encodes the bytes of the given String as Ascii85.
  #
  # If +wrap_lines+ evaluates to +false+, the output will be returned as
  # a single long line. Otherwise #encode formats the output into lines
  # of length +wrap_lines+ (minimum is 2, default is 80).
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
  def self.encode(str, wrap_lines = 80)
    to_encode = str.to_s
    input_size = to_encode.bytesize

    return ''.dup if input_size.zero?

    # Compute number of \0s to pad the message with (0..3)
    padding_length = (-input_size) % 4

    # Extract big-endian integers
    tuples = to_encode.unpack('N*')

    if padding_length != 0
      trailing = to_encode[-(4 - padding_length)..]
      padding = "\0" * padding_length
      tuples << (trailing + padding).unpack1('N')
    end

    # Encode
    tuples.map! do |tuple|
      if tuple.zero?
        'z'
      else
        tmp = '!!!!!'.dup

        5.times do |i|
          tmp.setbyte(4 - i, (tuple % 85) + 33)
          tuple /= 85
        end

        tmp
      end
    end

    # We can't use the z-abbreviation if we're going to cut off padding
    tuples[-1] = '!!!!!' if padding_length.positive? && (tuples.last == 'z')

    # Cut off the padding
    tuples[-1] = tuples[-1][0..(4 - padding_length)]

    # If we don't need to wrap the lines, add delimiters and return
    return "<~#{tuples.join}~>" unless wrap_lines

    # Otherwise we wrap the lines
    line_length = [2, wrap_lines.to_i].max

    wrapped = '<~'.dup
    cur_len = 2
    idx     = 0
    buffer  = tuples.first

    until idx >= tuples.size && buffer.nil?
      # Line is full -> Linebreak
      if cur_len == line_length
        wrapped << "\n"
        cur_len = 0
        next
      end

      # Buffer fits into line
      if cur_len + buffer.bytesize <= line_length
        wrapped << buffer
        cur_len += buffer.bytesize
        idx += 1
        buffer = tuples[idx]
        next
      end

      # Otherwise break buffer into two pieces and append the first one
      remaining = line_length - cur_len
      wrapped << buffer[0...remaining]
      buffer = buffer[remaining..]
      cur_len += remaining
    end

    # Add the closing delimiter (may need to be pushed to the next line)
    wrapped << "\n" if cur_len + 2 > line_length
    wrapped << '~>'

    wrapped
  end

  #
  # Searches through +str+ and extracts the _first_ Ascii85-String delimited
  # by +<~+ and +~>+.
  #
  # Returns the empty String if no valid delimiters are found.
  #
  #     Ascii85.extract("Foo<~;KZGo~>Bar<~z~>Baz")
  #     => ";KZGo"
  #
  #     Ascii85.extract("No delimiters")
  #     => ""
  #
  def self.extract(str)
    input = str.to_s

    # Make sure the delimiter strings have the correct encoding.
    opening_delim = '<~'.encode(input.encoding)
    closing_delim = '~>'.encode(input.encoding)

    # Get the positions of the opening/closing delimiters. If there is
    # no pair of opening/closing delimiters, return the empty string.
    (start_pos = input.index(opening_delim))                or return ''.dup
    (end_pos   = input.index(closing_delim, start_pos + 2)) or return ''.dup

    # Get the string inside the delimiter-pair
    input[(start_pos + 2)...end_pos]
  end

  #
  # Searches through +str+ and decodes the _first_ Ascii85-String found.
  #
  # #decode expects an Ascii85-encoded String enclosed in +<~+ and +~>+ — it
  # will ignore all characters outside these delimiters. The returned String is
  # always encoded as ASCII-8BIT.
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
  def self.decode(str)
    decode_raw(extract(str))
  end

  #
  # Decodes the given raw Ascii85-String.
  #
  # #decode_raw expects an Ascii85-encoded String NOT enclosed in +<~+ and +~>+.
  # The returned String is always encoded as ASCII-8BIT.
  #
  #     Ascii85.decode_raw(";KZGo")
  #     => "Ruby"
  #
  # Raises Ascii85::DecodingError when malformed input is encountered.
  #
  def self.decode_raw(str)
    input = str.to_s

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

        if count == 5

          if word > 0xffffffff
            raise(Ascii85::DecodingError,
                  "Invalid Ascii85 5-tuple (#{word} >= 2**32)")
          end

          result << word

          word  = 0
          count = 0
        end

      else
        raise(Ascii85::DecodingError,
              "Illegal character inside Ascii85: #{c.chr.dump}")
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

    result << ((word >> 24) & 255).chr if count >= 1
    result << ((word >> 16) & 255).chr if count >= 2
    result << ((word >> 8) & 255).chr if count == 3

    result
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
