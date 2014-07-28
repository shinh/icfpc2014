class Lman
  def initialize
    @insts = []
    @labels = {}
    @rlabels = {}
    @anon_num = 0
  end

  def label(a)
    if !a.is_a?(Symbol)
      raise "Not a label: #{a}"
    end
    @labels[a] = @insts.size
    @rlabels[@insts.size] = a
  end

  def anon_label
    l = "_L#{@anon_num}"
    @anon_num += 1
    l.to_sym
  end

  def emit
    ninst = 0
    @insts.each do |op, *args|
      o = ["#{op}".upcase]
      c = []

      if l = @rlabels[ninst]
        c << "@#{l}"
      end

      args.each do |a|
        if a.is_a?(Symbol)
          if !@labels[a]
            raise "Undefined label #{a}"
          end
          o << @labels[a]
          c << "#{a}"
        else
          o << a
        end
      end
      l = o * ' '
      if !c.empty?
        l += ' ; ' + c * ' '
      end
      puts l

      ninst += 1
    end
  end
end

if !system('make lman_inst.rb > make.log')
  raise "make failed"
end

require './lman_inst.rb'

L = Lman.new
