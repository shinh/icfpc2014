class Ghost
  attr_reader :name

  def initialize(name)
    @name = name

    @insts = []
    @labels = {}
    @rlabels = {}
    @anon_num = 0
  end

  def check_rm(a)
    if a.is_a?(Fixnum) || a.is_a?(Ghost)
      return true
    end

    if !a.is_a?(Array)
      return false
    end

    if a.size != 1
      return false
    end

    return a[0].is_a?(Fixnum) || a[0].is_a?(Ghost)
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

  def stringify(a)
    if a.is_a?(Ghost)
      a.name
    else
      a.to_s
    end
  end

  def emit
    ninst = 0
    @insts.each do |op, *args|
      o = []
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
        elsif a.is_a?(Array)
          o << "[#{stringify(a[0])}]"
        else
          o << stringify(a)
        end
      end
      l = op.to_s + ' ' + o * ','
      if !c.empty?
        l += ' ; ' + c * ' '
      end
      puts l

      ninst += 1
    end
  end

  def set_dir
    int(0)
  end

  def get_lpos
    int(1)
  end

  def get_id
    int(3)
  end

  def get_pos
    int(5)
  end

  def get_stat
    int(6)
  end

  def get_map
    int(7)
  end

  def dbg
    int(8)
  end

  def jmp(s)
    jeq(s, 0, 0)
  end
end

if !system('make ghost_inst.rb > make.log')
  raise "make failed"
end

require './ghost_inst.rb'

A = Ghost.new('a')
B = Ghost.new('b')
C = Ghost.new('c')
D = Ghost.new('d')
E = Ghost.new('e')
F = Ghost.new('f')
G = Ghost.new('g')
H = Ghost.new('h')
PC = Ghost.new('pc')
