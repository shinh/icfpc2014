require './lman'

$funcs = {}

# class Symbol
#   %i(+ - * /).each do |s|
#     define_method(s) do |a|
#       AST.new(s) + a
#     end
#   end
# end

class AST
  def initialize(op, *args)
    @op = op
    @args = args
    @func = nil
  end

  def to_s
    "#{@op}(#{@args * ', '})"
  end

  def var(n)
    a = @args[n]
    if a.is_a?(Fixnum)
      L.ldc(a)
    elsif a.is_a?(Symbol)
      L.ld(0, @func.var(a))
    else
      a.emit(@func)
    end
  end

  def +(a)
    AST.new(:+, self, a)
  end

  def -(a)
    AST.new(:-, self, a)
  end

  def *(a)
    AST.new(:*, self, a)
  end

  def /(a)
    AST.new(:/, self, a)
  end

  def ==(a)
    AST.new(:==, self, a)
  end

  def >(a)
    AST.new(:>, self, a)
  end

  def >=(a)
    AST.new(:>=, self, a)
  end

  def [](n)
    a = self
    n.times{a = AST.new(:cdr, a)}
    AST.new(:car, a)
  end

  def at(n, sz)
    a = self
    n.times{a = AST.new(:cdr, a)}
    if n == sz - 1
      a
    else
      AST.new(:car, a)
    end
  end

  def stmt(n)
    var(n)
  end

  def emit(func)
    @func = func

    case @op
    when :ld
      var(0)

    when :ldf
      L.ldf(@args[0])

    when :gld
      L.ld(2, @args[0])

    when :gst
      var(1)
      L.st(2, @args[0])

    when :ldc
      L.ldc(@args[0])

    when :st
      var(1)
      L.st(0, func.var(@args[0]))

    when :arg
      L.ld(1, @args[0])

    when :ret
      var(0)
      L.rtn

    when :car
      var(0)
      L.car

    when :cdr
      var(0)
      L.cdr

    when :cons
      var(0)
      var(1)
      L.cons

    when :atom
      var(0)
      L.atom

    when :if_
      l1 = L.anon_label
      l2 = L.anon_label
      var(0)
      L.tsel(l1, l2)
      L.label(l1)
      stmt(1)
      L.label(l2)

    when :ifelse_
      l1 = L.anon_label
      l2 = L.anon_label
      l3 = L.anon_label
      var(0)
      L.tsel(l1, l2)
      L.label(l1)
      stmt(1)
      L.ldc(0)
      L.tsel(l3, l3)
      L.label(l2)
      stmt(2)
      L.label(l3)

    when :while_
      l0 = L.anon_label
      l1 = L.anon_label
      l2 = L.anon_label
      L.label(l0)
      var(0)
      L.tsel(l1, l2)
      L.label(l1)

      orig_while = $cur_while
      $cur_while = [l0, l2]
      #STDERR.puts "enter #{$cur_while}"
      stmt(1)
      #STDERR.puts "exit #{$cur_while}"
      $cur_while = orig_while

      L.ldc(0)
      L.tsel(l0, l0)
      L.label(l2)

    when :next_
      #STDERR.puts "next #{$cur_while}"
      L.ldc(0)
      L.tsel($cur_while[0], $cur_while[0])

    when :break_
      L.ldc(0)
      L.tsel($cur_while[1], $cur_while[1])

    when :do_
      #STDERR.puts @args
      #STDERR.puts
      @args.size.times do |i|
        stmt(i)
      end

    when :call
      name = @args[0]
      args = @args[1..-1]

      if !$funcs[name]
        raise "Unknown function: #{name}"
      end
      if $funcs[name].num_args != args.size
        raise "Invalid argument count: #{name}"
      end

      args.size.times do |i|
        var(i + 1)
      end
      L.ldf(name)
      L.ap(args.size)

    when :+
      var(0)
      var(1)
      L.add

    when :-
      var(0)
      var(1)
      L.sub

    when :*
      var(0)
      var(1)
      L.mul

    when :/
      var(0)
      var(1)
      L.div

    when :==
      var(0)
      var(1)
      L.ceq

    when :>
      var(0)
      var(1)
      L.cgt

    when :>=
      var(0)
      var(1)
      L.cgte

    when :dbg
      var(0)
      L.dbug

    when :brk
      L.brk

    when :comment
      L.label("# #{@args[0]}".to_sym)

    else
      raise "Unknown op: #@op"
    end
  end
end

class Func
  def initialize(name, *args, &proc)
    @name = name
    @asts = []
    @vars = {}

    args.each do |a|
      alloc_var(a)
    end
    @args = args

    instance_eval(&proc)

    $funcs[name] = self
  end

  def num_args
    @args.size
  end

  def var(s)
    if !@vars[s]
      raise "Unknown var: #{s}"
    end
    @vars[s]
  end

  def alloc_var(s)
    if !@vars[s]
      @vars[s] = @vars.size
    end
  end

  def ldf(l)
    AST.new(:ldf, l)
  end

  def ld(s)
    AST.new(:ld, s)
  end

  def gld(n)
    AST.new(:gld, n)
  end

  def gst(n, s)
    @asts << AST.new(:gst, n, s)
    nil
  end

  def ldc(n)
    AST.new(:ldc, n)
  end

  def arg(n)
    AST.new(:arg, n)
  end

  def car(a)
    AST.new(:car, a)
  end

  def cdr(a)
    AST.new(:cdr, a)
  end

  def cons(a, b)
    AST.new(:cons, a, b)
  end

  def tuple(*a)
    v = a.pop
    while !a.empty?
      v = cons(a.pop, v)
    end
    v
  end

  def list(*a)
    v = 0
    while !a.empty?
      v = cons(a.pop, v)
    end
    v
  end

  def inc(s, n)
    st(s, ld(s) + n)
  end

  def atom(a)
    AST.new(:atom, a)
  end

  def st(s, a)
    alloc_var(s)
    @asts << AST.new(:st, s, a)
    nil
  end

  def ret(a)
    @asts << AST.new(:ret, a)
    nil
  end

  def if_(s, a)
    raise "Not a statement" if a != nil
    @asts << AST.new(:if_, s, @asts.pop)
    nil
  end

  def ifelse_(s, a, b)
    raise "Not a statement" if a != nil
    raise "Not a statement" if b != nil
    b = @asts.pop
    a = @asts.pop
    @asts << AST.new(:ifelse_, s, a, b)
    nil
  end

  def while_(s, a)
    raise "Not a statement" if a != nil
    @asts << AST.new(:while_, s, @asts.pop)
    nil
  end

  def proc_impl(&a)
    oasts = @asts
    @asts = []
    l = instance_eval(&a)
    r = AST.new(:do_, *@asts)
    @asts = oasts
    [r, l]
  end

  def whileP(s, &a)
    r, l = proc_impl(&a)
    if l
      raise "Not a statement"
    end
    @asts << AST.new(:while_, s, r)
    nil
  end

  def ifP(s, &a)
    r, l = proc_impl(&a)
    if l
      raise "Not a statement #{l} (cond=#{s})"
    end
    @asts << AST.new(:if_, s, r)
    nil
  end

  def exprP(&a)
    r, l = proc_impl(&a)
    if !l
      raise "Not an expr"
    end
    AST.new(:do_, r, l)
  end

  def do_(*stmts)
    asts = []
    stmts.each do |a|
      raise "Not a statement" if a != nil
      asts << @asts.pop
    end
    @asts << AST.new(:do_, *asts.reverse)
    nil
  end

  def next_
    @asts << AST.new(:next_)
    nil
  end

  def break_
    @asts << AST.new(:break_)
    nil
  end

  def expr(*stmts)
    asts = []
    asts << stmts.pop
    stmts.each do |a|
      raise "Not a statement" if a != nil
      asts << @asts.pop
    end
    AST.new(:do_, *asts.reverse)
  end

  def call(name, *args)
    AST.new(:call, name, *args)
  end

  def dbg(s)
    @asts << AST.new(:dbg, s)
    nil
  end

  def brk
    @asts << AST.new(:brk)
    nil
  end

  def hlt
    dbg(-42)
    brk
  end

  def comment(s)
    @asts << AST.new(:comment, s)
    nil
  end

  def emit
    L.label(@name)

    impl = "#{@name}_impl".to_sym
    @args.size.times do |i|
      L.ld(0, i)
    end
    (@vars.size - @args.size).times do |i|
      L.ldc(0)
    end

    L.ldf(impl)
    L.ap(@vars.size)
    L.rtn

    L.label(impl)

    @asts.each do |ast|
      ast.emit(self)
    end
  end
end

def emit
  $funcs.each do |name, func|
    func.emit
  end
  L.emit
end

if $0 == __FILE__
  Func.new(:main, :state, :undocumented) do
    st(:ai_state, 0)
    ret(cons(:ai_state, ldf(:step)))
  end

  Func.new(:step, :ai, :state) do
    st(:map, ld(:state)[0])
    st(:x, car(ld(:state)[1][1]))
    st(:y, cdr(ld(:state)[1][1]))

    st(:v, call(:getXY, :map, :x, :y))
    dbg(ld(:v))

    # st(:v, ld(:map))
    # while_(:y, do_(st(:y, ld(:y) - 1),
    #                st(:v, cdr(ld(:v)))))
    # st(:v, car(:v))
    # dbg(ld(:v))

    #dbg(ld(:x))
    #dbg(ld(:y))

    st(:s, ld(:ai))
    st(:s, ld(:s) + 1)
    if_(ld(:s) == 24, st(:s, 0))
    ret(cons(ld(:s), ld(:s) / 6))
  end

  Func.new(:getXY, :map, :x, :y) do
    st(:v, ld(:map))
    while_(:y, do_(st(:y, ld(:y) - 1),
                   st(:v, cdr(:v))))
    st(:v, car(:v))
    while_(:x, do_(st(:x, ld(:x) - 1),
                   st(:v, cdr(:v))))
    ret(car(:v))
  end

  emit
end
