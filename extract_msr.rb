#!/usr/bin/env ruby

require 'set'
require 'optparse'

def show_help(opts_help)
  STDERR.puts opts_help
  STDERR.puts <<-EOS
Generate a C header file for MSR address definition. 

Copy the text of the relevant MSR tables from the Intel's manual, save it
in a file, and pass that file to this script. 

CAUTION: 
This script extracts definitions naively. The generated header file may 
contain garbage or incorrect definition. The author tested this script
with the Intel's manual (September 2016) and Adobe Acrobat Reader DC.
  EOS
end

parser = OptionParser.new do |opts|
  opts.banner =  "Usage: #{File.basename(__FILE__)} path_to_pasted_text_file\n"
  opts.on("-h", "--help", "Print his help") do
    show_help(opts)
    exit
  end
end
parser.parse!
if ARGV.length < 1
  STDERR.puts "Error: argument missing"
  show_help(parser)
  exit
end


# Beforehand, concatenate some hex addresses which are 
# written separetely in two lines
raw = File.read("./copied.txt")
raw.gsub!(/([0-9A-F]+)_\n([0-9A-F]+)H\n/, '\1\2H ')
raw_lines = raw.lines


# Collect lines which contain MSR's names and values
# while grouping them by processor family
cur_family_lines = nil
by_family = []

raw_lines.length.times do |i|
  case raw_lines[i]
  when /^35\.\d+ (MSRS|ARCHITECTURAL MSRS)/
    cur_family_lines = []
    by_family.push [raw_lines[i], cur_family_lines]
  when /^[0-9A-F]+H / 
    relevant_lines = [raw_lines[i]]
    unless raw_lines[i + 1] =~ /^[0-9A-F]+H / 
      relevant_lines.push raw_lines[i + 1]
    end
    cur_family_lines.push relevant_lines
  end
end

output_components = []
by_family.each do |(famly_name, lines)|
  family_output = {family_name: famly_name, msrs: []}

  lines.each do |words|
    split = words.join("").split(/[\t ]+/)

    if split[1].chomp =~ /^\d+$/
      # Usual cases
      name = split[2]
    else
      # When "Decimal" columns in "Register Address" are empty
      name = split[1]
    end
    # Skip some garbage lines
    next if name =~ /[:-]/ || ["Reserved", "and"].include?(name)
    # Trim exceptional garbage
    if name[-5..-1] == "Table"
      # I saw that happens for "MCG_STATUS" and "MTRRphysBase1"
      name = name[0..-6]
    # garbases due to superscripts or empty bit description
    elsif [ "BBL_CR_CTL30", "IA32_MCG_STATUS0", "DEBUGCTLMSR0"].include? name
      name = name[0..-2]
    elsif name =~ /MC\d*_ADDR\d/
      name = name[0..-2]  # Due to a superscript '0' 
    end

    unless name[0..3] == "MSR_"
      name = "MSR_" + name
    end
    name.gsub!(/(\n|\(.*$)/, "")

    # split[1] is like "01289ADH", the last 'H' is suffix
    value = split[0][0..-2].to_i(16)

    family_output[:msrs].push [name, value]
  end

  output_components.push family_output
end

# Filter duplicates
all_msrs = Set.new
output_components.each do |msr_family|
  msr_family[:msrs].select! do |name, _|
    if all_msrs.include? name
      false
    else
      all_msrs.add name
      true
    end
  end
end

# Print them
puts <<EOS
#ifndef X86_MSR_ADDERESSES_H
#define X86_MSR_ADDERESSES_H

/*
 *  Free Public License 1.0.0
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF 
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES 
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN 
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF 
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 *  Naming Convention:
 *  Each constant is named by prefixing "MSR_" to the name in the Intel's
 *  manual. (e.g. IA32_TIME_STAMP_COUNTER -> MSR_IA32_TIME_STAMP_COUNTER)
 *  If the original Intel's name is prefixed with "MSR_", the corresponding
 *  constant has the exact same name.
 *
 *  CAUTION:
 *  This file is automatically generated from Intel 64 and IA-32
 *  Architectures Software Developer Manuals. This may contain garbage or
 *  incorrect definitions.
 */



EOS
output_components.each.with_index do |msr_family, i|
  unless i == 0
    puts "\n" * 3
  end

  puts <<-EOS
/*
 * #{msr_family[:family_name].chomp}
 */
  EOS

  unless msr_family[:msrs].empty?
    longest_name = msr_family[:msrs].map {|name, _| name.length}.max
    msr_family[:msrs].each do |name, value|
      print "#define #{name}"
      print " " * (longest_name + 4 - name.length)
      print "0x%08xU\n" % value
    end
  else
    puts "// All MSRs are already defined above"
  end
end

puts "#endif"
