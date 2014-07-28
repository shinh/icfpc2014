#!/usr/bin/env ruby

puts 'class Ghost'

[[:mov, :rm, :rm],
 [:inc, :rm],
 [:dec, :rm],
 [:add, :rm, :rm],
 [:sub, :rm, :rm],
 [:mul, :rm, :rm],
 [:div, :rm, :rm],
 [:and, :rm, :rm],
 [:or, :rm, :rm],
 [:xor, :rm, :rm],
 [:jlt, :sym, :rm, :rm],
 [:jeq, :sym, :rm, :rm],
 [:jgt, :sym, :rm, :rm],
 [:int, :int],
 [:hlt],
].each do |op, *args|
  as = args.each_index.map{|i|"a#{i}"}
  puts "  def #{op}(#{as * ', '})"
  args.zip(as).each do |t, a|
    case t
    when :int
      puts %Q(    raise if !#{a}.is_a?(Fixnum))
    when :sym
      puts %Q(    raise if !#{a}.is_a?(Symbol))
    when :rm
      puts %Q(    raise if !check_rm(#{a}))
    else
      raise "#{t}"
    end
  end
  puts "    @insts << [#{([":#{op}"] + as) * ', '}]"
  puts "  end"
  puts
end

puts 'end'
