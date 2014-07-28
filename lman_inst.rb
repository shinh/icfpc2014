class Lman
  def ldc(a0)
    raise if !a0.is_a?(Fixnum)
    @insts << [:ldc, a0]
  end

  def ldf(a0)
    raise if !a0.is_a?(Symbol)
    @insts << [:ldf, a0]
  end

  def ap(a0)
    raise if !a0.is_a?(Fixnum)
    @insts << [:ap, a0]
  end

  def rtn()
    @insts << [:rtn]
  end

  def ld(a0, a1)
    raise if !a0.is_a?(Fixnum)
    raise if !a1.is_a?(Fixnum)
    @insts << [:ld, a0, a1]
  end

  def st(a0, a1)
    raise if !a0.is_a?(Fixnum)
    raise if !a1.is_a?(Fixnum)
    @insts << [:st, a0, a1]
  end

  def add()
    @insts << [:add]
  end

  def sub()
    @insts << [:sub]
  end

  def mul()
    @insts << [:mul]
  end

  def div()
    @insts << [:div]
  end

  def ceq()
    @insts << [:ceq]
  end

  def cgt()
    @insts << [:cgt]
  end

  def cgte()
    @insts << [:cgte]
  end

  def cons()
    @insts << [:cons]
  end

  def car()
    @insts << [:car]
  end

  def cdr()
    @insts << [:cdr]
  end

  def atom()
    @insts << [:atom]
  end

  def brk()
    @insts << [:brk]
  end

  def dbug()
    @insts << [:dbug]
  end

  def dum(a0)
    raise if !a0.is_a?(Fixnum)
    @insts << [:dum, a0]
  end

  def rap(a0)
    raise if !a0.is_a?(Fixnum)
    @insts << [:rap, a0]
  end

  def tsel(a0, a1)
    raise if !a0.is_a?(Symbol)
    raise if !a1.is_a?(Symbol)
    @insts << [:tsel, a0, a1]
  end

end
