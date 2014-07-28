#!/usr/bin/env ruby

puts 'class Lman'

[[:ldc, :int],
 [:ldf, :sym],
 [:ap, :int],
 [:rtn],
 [:ld, :int, :int],
 [:st, :int, :int],
 [:add],
 [:sub],
 [:mul],
 [:div],
 [:ceq],
 [:cgt],
 [:cgte],
 [:cons],
 [:car],
 [:cdr],
 [:atom],
 [:brk],
 [:dbug],
 [:dum, :int],
 [:rap, :int],
 [:tsel, :sym, :sym],
].each do |op, *args|
  as = args.each_index.map{|i|"a#{i}"}
  puts "  def #{op}(#{as * ', '})"
  args.zip(as).each do |t, a|
    case t
    when :int
      puts %Q(    raise if !#{a}.is_a?(Fixnum))
    when :sym
      puts %Q(    raise if !#{a}.is_a?(Symbol))
    else
      raise "#{t}"
    end
  end
  puts "    @insts << [#{([":#{op}"] + as) * ', '}]"
  puts "  end"
  puts
end

puts 'end'
