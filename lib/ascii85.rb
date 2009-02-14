#
# Ascii85 is an implementation of Adobe's binary-to-text encoding of the same
# name in pure Ruby.
#
# See http://www.adobe.com/products/postscript/pdfs/PLRM.pdf page 131 and
# http://en.wikipedia.org/wiki/Ascii85 for more information about the format.
#
# Author::  Johannes Holzfuß <Drangon@gmx.de>
# License:: Distributed under the MIT License (see README.txt)
#


module Ascii85
  VERSION = '0.9.0'

  #
  # Encodes the given String as Ascii85.
  #
  # If +wrap_lines+ evaluates to +false+, the output will be returned as a
  # single long line. Otherwise #encode formats the output into lines of
  # length +wrap_lines+ (minimum is 2).
  #
  #     Ascii85::encode("Ruby")
  #     => <~;KZGo~>
  #
  #     Ascii85::encode("Supercalifragilisticexpialidocious", 15)
  #     => <~;g!%jEarNoBkD
  #        BoB5)0rF*),+AU&
  #        0.@;KXgDe!L"F`R
  #        ~>
  #
  #     Ascii85::encode("Supercalifragilisticexpialidocious", false)
  #     => <~;g!%jEarNoBkDBoB5)0rF*),+AU&0.@;KXgDe!L"F`R~>
  #
  #
  def self.encode(str, wrap_lines = 80)

    return '' if str.to_s.empty?

    # Compute number of \0s to pad the message with (0..3)
    padding_length = (-str.to_s.length) % 4

    # Extract big-endian integers
    tuples = (str.to_s + ("\0" * padding_length)).unpack('N*')

    # Encode
    tuples.map! do |tuple|
      if tuple == 0
        'z'
      else
        tmp = ""
        5.times do
          tmp += ((tuple % 85) + 33).chr
          tuple /= 85
        end
        tmp.reverse
      end
    end

    # We can't use the z-abbreviation if we're going to cut off padding
    if (padding_length > 0) and (tuples.last == 'z')
      tuples[-1] = '!!!!!'
    end

    # Cut off the padding
    tuples[-1] = tuples[-1][0..(4 - padding_length)]

    # Add start-marker and join into a String
    result = '<~' + tuples.join

    # If we don't need to wrap the lines to a certain length, add ~> and return
    if (!wrap_lines)
      return result + '~>'
    end

    # Otherwise we wrap the lines

    line_length = [2, wrap_lines.to_i].max

    wrapped = []
    0.step(result.length, line_length) do |index|
      wrapped << result.slice(index, line_length)
    end

    # Add end-marker -- on a new line if necessary
    if (wrapped.last.length + 2) > line_length
      wrapped << '~>'
    else
      wrapped[-1] += '~>'
    end

    return wrapped.join("\n")
  end

  #
  # Searches through +str+ and decodes the _first_ Ascii85-String found
  #
  # #decode expects an Ascii85-encoded String enclosed in <~ and ~>. It will
  # ignore all characters outside these markers.
  #
  #     Ascii85::decode("<~;KZGo~>")
  #     => "Ruby"
  #
  #     Ascii85::decode("Foo<~;KZGo~>Bar<~;KZGo~>Baz")
  #     => "Ruby"
  #
  #     Ascii85::decode("No markers")
  #     => ""
  #
  # #decode will raise Ascii85::DecodingError when malformed input is
  # encountered.
  #
  def self.decode(str)

    # Find the Ascii85 encoded data between <~ and ~>
    input = str.to_s.match(/<~.*?~>/mn)

    return '' if input.nil?

    # Remove the delimiters
    input = input.to_s[2..-3]

    return '' if input.empty?

    # Decode
    result = []

    count = 0
    word = 0

    input.each_byte do |c|

      case c.chr
      when /[ \t\r\n\f\0]/
        # Ignore whitespace
        next

      when 'z'
        if count == 0
          # Expand z to 0-word
          result << 0
        else
          raise(Ascii85::DecodingError, "Found 'z' inside Ascii85 5-tuple")
        end

      when '!'..'u'
        # Decode 5 characters into a 4-byte word
        word += (c - 33) * 85**(4 - count)
        count += 1

        if count == 5

          if word >= 2**32
            raise(Ascii85::DecodingError,
                  "Invalid Ascii85 5-tuple (#{word} >= 2**32)")
          end

          result << word
          word = 0
          count = 0
        end

      else
        raise(Ascii85::DecodingError,
              "Illegal character inside Ascii85: #{c.chr.dump}")
      end

    end

    # Convert result into a String
    result = result.pack('N*')

    if count > 0
      # Finish last, partially decoded 32-bit-word

      if count == 1
        raise(Ascii85::DecodingError,
              "Last 5-tuple consists of single character")
      end

      count -= 1
      word += 85**(4 - count)

      result += ((word >> 24) & 255).chr if count >= 1
      result += ((word >> 16) & 255).chr if count >= 2
      result += ((word >>  8) & 255).chr if count == 3
    end

    return result
  end

  class DecodingError < StandardError; end

end
