package main

import "bufio"
import "bytes"
import "io"
import "flag"
import "fmt"
import "os"
import "strconv"
import "strings"

var flag_call_stat = flag.Bool("call_stat", false, "")
var flag_pc_stat = flag.Bool("pc_stat", false, "")
var flag_quiet = flag.Bool("quiet", false, "")

// Utility

func Error(msg string) {
	panic(msg)
	//fmt.Println(msg)
	//os.Exit(1)
}

func OpenFile(name string) *bufio.Reader {
	fp, err := os.Open(name)
	if err != nil { panic(err) }
	return bufio.NewReader(fp)
}

func ReadLines(filename string) []string {
	fmt.Printf("Parsing %s...\n", filename)
	fp := OpenFile(filename)
	lines := []string{}
	for true {
		line, err := fp.ReadString('\n')
		if err == io.EOF { break }
		toks := strings.Split(line, ";")
		line = strings.TrimRight(toks[0], " \n")
		lines = append(lines, line)
	}
	return lines
}

// For both GHC / GCC

const (
	MOV = iota
	INC
	DEC
	ADD
	SUB
	MUL
	DIV
	AND
	OR
	XOR
	JLT
	JEQ
	JGT
	INT
	HLT

	LDC
	LD
	// ADD SUB MUL DIV
	CEQ
	CGT
	CGTE
	ATOM
	CONS
	CAR
	CDR
	SEL
	JOIN
	LDF
	AP
	RTN
	DUM
	RAP
	STOP
	TSEL
	TAP
	TRAP
	ST
	DBUG
	BRK
)

var OP_STRS = [...]string{
	"MOV",
	"INC",
	"DEC",
	"ADD",
	"SUB",
	"MUL",
	"DIV",
	"AND",
	"OR",
	"XOR",
	"JLT",
	"JEQ",
	"JGT",
	"INT",
	"HLT",

	"LDC",
	"LD",
	// ADD SUB MUL DIV
	"CEQ",
	"CGT",
	"CGTE",
	"ATOM",
	"CONS",
	"CAR",
	"CDR",
	"SEL",
	"JOIN",
	"LDF",
	"AP",
	"RTN",
	"DUM",
	"RAP",
	"STOP",
	"TSEL",
	"TAP",
	"TRAP",
	"ST",
	"DBUG",
	"BRK",
}

// GHC

const (
	PC = 8
)

const (
	REG = iota
	IMM
	REG_REF
	IMM_REF
)

type GHCArg struct {
	ty int
	v uint8
}

type GHCInst struct {
	op int
	args []GHCArg
}

type GHC []*GHCInst

func ParseGHC(filename string) *GHC {
	lines := ReadLines(filename)
	ghc := new(GHC)
	for n, line := range(lines) {
		n++
		if len(line) == 0 {
			continue
		}

		toks := strings.Split(line, " ")
		if len(toks) > 2 {
			Error(fmt.Sprintf("GHC: too many ops at %d: %s", n, line))
		}

		op := -1
		for i, o := range(OP_STRS) {
			if o == strings.ToUpper(toks[0]) {
				op = i
				break
			}
		}
		if op == -1 || op > HLT {
			Error(fmt.Sprintf("GHC: invalid op at %d: %s", n, line))
		}

		if op == HLT && len(toks) != 1 || op != HLT && len(toks) != 2 {
			Error(fmt.Sprintf("GHC: invalid args at %d: %s", n, line))
		}

		inst := new(GHCInst)
		inst.op = op

		if op != HLT {
			toks = strings.Split(toks[1], ",")
			expected_num_args := 2
			if op == INC || op == DEC || op == INT {
				expected_num_args = 1
			}
			if op == JLT || op == JEQ || op == JGT {
				expected_num_args = 3
			}
			if len(toks) != expected_num_args {
				Error(fmt.Sprintf(
					"GHC: unexpected number of args at %d: %s", n, line))
			}

			var args []GHCArg
			for _, a := range(toks) {
				var arg GHCArg
				ref := 0
				if a[0] == '[' {
					a = strings.TrimLeft(a, "[")
					a = strings.TrimRight(a, "]")
					ref = 2
				}

				if a[0] >= '0' && a[0] <= '9' {
					arg.ty = IMM | ref
					v, e := strconv.Atoi(a)
					if e != nil { panic(e) }
					if v < 0 || v > 255 {
						Error(fmt.Sprintf(
							"GHC: invalid arg at %d: %s", n, line))
					}
					arg.v = uint8(v)
				} else if len(a) == 1 {
					arg.ty = REG | ref
					v := int(a[0] - 'a')
					if arg.v < 0 || arg.v > 7 {
						Error(fmt.Sprintf(
							"GHC: invalid arg at %d: %s", n, line))
					}
					arg.v = uint8(v)
				} else if a == "pc" {
					arg.ty = REG | ref
					arg.v = PC
				} else {
					Error(fmt.Sprintf(
						"GHC: invalid arg at %d: %s", n, line))
				}

				args = append(args, arg)
			}

			if op == INT || op == JLT || op == JEQ || op == JGT {
				if args[0].ty != IMM {
					Error(fmt.Sprintf(
						"GHC: invalid jmp target at %d: %s", n, line))
				}
			}

			inst.args = args
		}

		*ghc = append(*ghc, inst)

		if len(*ghc) > 256 {
			Error(fmt.Sprintf("GHC: too many instructions at %d: %s", n, line))
		}
	}

	return ghc
}

type GHCState struct {
	ghc GHC
	reg [9]uint8
	mem *[256]uint8
	mp *Map
	ghost *Ghost
	plan int
}

func (st *GHCState) getV(a GHCArg) uint8 {
	v := a.v
	if (a.ty & 1) == REG {
		v = st.reg[v]
	}
	return v
}

func (st *GHCState) get(a GHCArg) uint8 {
	v := st.getV(a)
	if (a.ty & 2) == 2 {
		v = st.mem[v]
	}
	return v
}

func (st *GHCState) set(a GHCArg, v uint8) {
	if (a.ty & 2) == 2 {
		st.mem[st.getV(a)] = v
	} else if a.ty == REG {
		st.reg[a.v] = v
	} else {
		Error("GHC: Invalid output operand")
	}
}

func (st *GHCState) runInt(id uint8) {
	switch id {
	case 0:
		plan := int(st.reg[0])
		if plan >= 0 && plan < 4 {
			st.plan = plan
		}
	case 1:
		st.reg[0] = uint8(st.mp.lman.pos.x)
		st.reg[1] = uint8(st.mp.lman.pos.y)
	case 2:
		Error("GHC: int 2 is undefined")
	case 3:
		st.reg[0] = uint8(st.ghost.id)
	case 4:
		g := st.mp.ghosts[st.reg[0]]
		st.reg[0] = uint8(g.opos.x)
		st.reg[1] = uint8(g.opos.y)
	case 5:
		g := st.mp.ghosts[st.reg[0]]
		st.reg[0] = uint8(g.pos.x)
		st.reg[1] = uint8(g.pos.y)
	case 6:
		g := st.mp.ghosts[st.reg[0]]
		st.reg[0] = uint8(g.vit)
		st.reg[1] = uint8(g.plan)
	case 7:
		x := int(st.reg[0])
		y := int(st.reg[1])
		if x >= st.mp.width || y >= st.mp.height {
			st.reg[0] = 0
		} else {
			st.reg[0] = uint8(st.mp.get(x, y))
		}
	case 8:
		var buf bytes.Buffer
		buf.WriteString("trace ghost")
		buf.WriteString(strconv.Itoa(st.ghost.id))
		buf.WriteString(": ")
		buf.WriteString(strconv.Itoa(int(st.reg[8])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[0])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[1])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[2])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[3])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[4])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[5])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[6])))
		buf.WriteString(" ")
		buf.WriteString(strconv.Itoa(int(st.reg[7])))
		fmt.Println(buf.String())
	}
}

func (st *GHCState) run() int {
	t := 0
	for ; t < 1024 && int(st.reg[PC]) < len(st.ghc); t++ {
		inst := st.ghc[st.reg[PC]]

		switch inst.op {
		case MOV:
			st.set(inst.args[0], st.get(inst.args[1]))
		case INC:
			st.set(inst.args[0], st.get(inst.args[0]) + 1)
		case DEC:
			st.set(inst.args[0], st.get(inst.args[0]) - 1)
		case ADD:
			st.set(inst.args[0], st.get(inst.args[0]) + st.get(inst.args[1]))
		case SUB:
			st.set(inst.args[0], st.get(inst.args[0]) - st.get(inst.args[1]))
		case MUL:
			st.set(inst.args[0], st.get(inst.args[0]) * st.get(inst.args[1]))
		case DIV:
			st.set(inst.args[0], st.get(inst.args[0]) / st.get(inst.args[1]))
		case AND:
			st.set(inst.args[0], st.get(inst.args[0]) & st.get(inst.args[1]))
		case OR:
			st.set(inst.args[0], st.get(inst.args[0]) | st.get(inst.args[1]))
		case XOR:
			st.set(inst.args[0], st.get(inst.args[0]) ^ st.get(inst.args[1]))
		case JLT:
			if st.get(inst.args[1]) < st.get(inst.args[2]) {
				st.reg[PC] = inst.args[0].v - 1
			}
		case JEQ:
			if st.get(inst.args[1]) == st.get(inst.args[2]) {
				st.reg[PC] = inst.args[0].v - 1
			}
		case JGT:
			if st.get(inst.args[1]) > st.get(inst.args[2]) {
				st.reg[PC] = inst.args[0].v - 1
			}
		case INT:
			st.runInt(inst.args[0].v)
		case HLT:
			break
		default:
			panic("Unknown op")
		}

		st.reg[PC]++
	}

	fmt.Printf("ghost%d plan (%d cycles) (%d,%d): %d\n",
		st.ghost.id, t, st.ghost.pos.x, st.ghost.pos.y, st.plan)

	return st.plan
}

func (ghc GHC) run(mp *Map, ghost *Ghost) int {
	if ghc == nil { return -1 }

	st := new(GHCState)
	st.ghc = ghc
	st.mp = mp
	st.ghost = ghost
	st.mem = &ghost.mem
	st.plan = -1
	//fmt.Printf("%d %d %d %d\n", st.mem[0], st.mem[1], st.mem[2], st.mem[3])
	return st.run()
}

// GCC

const (
	TAG_INT = iota
	TAG_CONS
	TAG_CLOSURE

	TAG_FRAME
	TAG_DUM
)

var TAG_STRS = [...]string{
	"TAG_INT",
	"TAG_CONS",
	"TAG_CLOSURE",

	"TAG_FRAME",
	"TAG_DUM",
}

type Value struct {
	tag int
	v int
	c *Cons
}

type Cons struct {
	car Value
	cdr Value
}

func MakeValue(tag int, v int) Value {
	return Value{tag, v, nil}
}

func MakeIntValue(v int) Value {
	return MakeValue(TAG_INT, v)
}

func MakeCons(x Value, y Value) Value {
	c := new(Cons)
	c.car = x
	c.cdr = y
	return Value{TAG_CONS, 0, c}
}

func MakeTuple(values []Value) Value {
	if len(values) < 2 {
		panic("Tuple too small")
	}

	v := MakeCons(values[len(values) - 2], values[len(values) - 1])
	for i := len(values) - 3; i >= 0; i-- {
		v = MakeCons(values[i], v)
	}
	return v
}

func MakeList(values []Value) Value {
	values = append(values, MakeIntValue(0))
	return MakeTuple(values)
}

func (v Value) str() string {
	var buf bytes.Buffer
	switch v.tag {
	case TAG_INT:
		buf.WriteString(strconv.Itoa(v.v))
	case TAG_CLOSURE:
		buf.WriteString("FUNC:")
		buf.WriteString(strconv.Itoa(v.v))
	case TAG_CONS:
		buf.WriteString("(")
		buf.WriteString(v.c.car.str())
		buf.WriteString(", ")
		buf.WriteString(v.c.cdr.str())
		buf.WriteString(")")
	}
	return buf.String()
}

func (v Value) show() {
	fmt.Println(v.str)
}

type Frame struct {
	tag int
	parent *Frame
	v []Value
}

type GCCInst struct {
	op int
	args []int
}

type GCC []*GCCInst

type GCCState struct {
	gcc GCC
	stack []Value
	calls []int
	fp *Frame
	mp *Map

	c int
	s int
	d int
	e int

	cycles int

	call_stat map[int]int
	pc_stat map[int]int
}

func MakeGCCState(mp *Map, gcc GCC) *GCCState {
	st := new(GCCState)
	st.mp = mp
	st.gcc = gcc
	st.stack = make([]Value, 1000)
	st.calls = make([]int, 10000)
	st.call_stat = make(map[int]int)
	st.pc_stat = make(map[int]int)
	return st
}

func ParseGCC(filename string) *GCC {
	lines := ReadLines(filename)
	gcc := new(GCC)
	for n, line := range(lines) {
		n++
		if len(line) == 0 {
			continue
		}

		toks := strings.Split(line, " ")

		op := -1
		for i, o := range(OP_STRS) {
			if o == strings.ToUpper(toks[0]) {
				op = i
				break
			}
		}
		if op <= HLT && (op < ADD || op > DIV) {
			Error(fmt.Sprintf("GCC: invalid op at %d: %s", n, line))
		}

		// TODO: Check the number of args.

		var args []int
		for _, tok := range(toks[1:]) {
			a, e := strconv.Atoi(tok)
			if e != nil {
				Error(fmt.Sprintf("GCC: invalid operand at %d: %s", n, line))
			}
			args = append(args, a)
		}

		inst := new(GCCInst)
		inst.op = op
		inst.args = args
		*gcc = append(*gcc, inst)

		if len(*gcc) > 1048576 {
			Error(fmt.Sprintf("GCC: too many instructions at %d: %s", n, line))
		}
	}

	return gcc
}

func (st *GCCState) error(msg string) {
	var buf bytes.Buffer
	buf.WriteString(fmt.Sprintf("GCC: pc=%d %s\n", st.c, msg))
	buf.WriteString(fmt.Sprintf("Current frame:\n"))
	for i, v := range(st.fp.v) {
		buf.WriteString(fmt.Sprintf("%d: %s\n", i, v.str()))
	}
	buf.WriteString(fmt.Sprintf("Current stack:\n"))
	for i := st.s - 1; i >= 0; i-- {
		buf.WriteString(fmt.Sprintf("%d: %s\n", i, st.stack[i].str()))
	}
	Error(buf.String())
}

func (st *GCCState) push(v Value) {
	st.stack[st.s] = v
	st.s++
}

func (st *GCCState) pop() Value {
	st.s--
	if st.s < 0 {
		st.error("empty stack")
	}
	return st.stack[st.s]
}

func (st *GCCState) pushCall(c int) {
	st.calls[st.d] = c
	st.d++
}

func (st *GCCState) popCall() int {
	st.d--
	return st.calls[st.d]
}

func (st *GCCState) checkType(v Value, tag int) {
	if tag != v.tag {
		st.error(fmt.Sprintf(
			"Unexpected tag type expected=%s actual=%s",
			TAG_STRS[tag], TAG_STRS[v.tag]))
	}
}

func (st *GCCState) call(n int, c int) {
	st.call_stat[c]++

	fp := new(Frame)
	fp.tag = TAG_FRAME
	fp.v = make([]Value, n)
	fp.parent = st.fp

	for n--; n >= 0; n-- {
		fp.v[n] = st.pop()
	}

	st.fp = fp
	st.c = c
}

func (st *GCCState) getFrame(n int) *Frame {
	fp := st.fp
	for i := 0; i < n; i++ {
		fp = fp.parent
	}
	if fp.tag == TAG_DUM {
		st.error("Frame mismatch")
	}
	return fp
}

func (st *GCCState) runInst(inst *GCCInst) bool {
	//fmt.Printf("GCC inst: pc=%d %s\n", st.c, OP_STRS[inst.op])

	switch inst.op {
	case LDC:
		st.push(MakeIntValue(inst.args[0]))

	case LD:
		fp := st.getFrame(inst.args[0])
		v := fp.v[inst.args[1]]
		st.push(v)

	case ADD, SUB, MUL, DIV, CEQ, CGT, CGTE:
		y := st.pop()
		x := st.pop()
		st.checkType(x, TAG_INT)
		st.checkType(y, TAG_INT)
		z := MakeIntValue(0)
		switch inst.op {
		case ADD:
			z = MakeIntValue(x.v + y.v)
		case SUB:
			z = MakeIntValue(x.v - y.v)
		case MUL:
			z = MakeIntValue(x.v * y.v)
		case DIV:
			z = MakeIntValue(x.v / y.v)
		case CEQ:
			if (x.v == y.v) { z = MakeIntValue(1) }
		case CGT:
			if (x.v > y.v) { z = MakeIntValue(1) }
		case CGTE:
			if (x.v >= y.v) { z = MakeIntValue(1) }
		}
		st.push(z)

	case ATOM:
		x := st.pop()
		v := 0
		if x.tag == TAG_INT { v = 1 }
		y := MakeIntValue(v)
		st.push(y)

	case CONS:
		y := st.pop()
		x := st.pop()
		z := MakeCons(x, y)
		st.push(z)

	case CAR:
		x := st.pop()
		st.checkType(x, TAG_CONS)
		y := x.c.car
		st.push(y)

	case CDR:
		x := st.pop()
		st.checkType(x, TAG_CONS)
		y := x.c.cdr
		st.push(y)

	// SEL
	// JOIN

	case LDF:
		st.push(MakeValue(TAG_CLOSURE, inst.args[0]))

	case AP:
		x := st.pop()
		st.checkType(x, TAG_CLOSURE)
		f := x.v
		st.pushCall(st.c)
		st.call(inst.args[0], f)
		st.c--

	case RTN:
		if st.d == 0 {
			return false
		}
		st.c = st.popCall()
		st.fp = st.fp.parent

	case DUM:
		fp := new(Frame)
		fp.tag = TAG_DUM
		fp.v = make([]Value, inst.args[0])
		fp.parent = st.fp
		st.fp = fp

	// RAP
	// STOP
	case TSEL:
		x := st.pop()
		st.checkType(x, TAG_INT)
		if x.v == 0 {
			st.c = inst.args[1]
		} else {
			st.c = inst.args[0]
		}
		st.c--

	// TAP
	// TRAP
	case ST:
		fp := st.getFrame(inst.args[0])
		fp.v[inst.args[1]] = st.pop()

	case DBUG:
		x := st.pop()
		fmt.Printf("trace lambdaman: %s\n", x.str())

	// BRK

	default:
		st.error(fmt.Sprintf("Not implemented: %s", OP_STRS[inst.op]))
	}
	return true
}

func (st *GCCState) MakeMapState() Value {
	mp := st.mp
	var st_v []Value

	var map_v []Value
	for y := 0; y < mp.height; y++ {
		var row []Value
		for x := 0; x < mp.width; x++ {
			v := MakeIntValue(int(mp.get(x, y)))
			row = append(row, v)
		}
		map_v = append(map_v, MakeList(row))
	}
	st_v = append(st_v, MakeList(map_v))

	lman := mp.lman
	var lman_v []Value
	lman_v = append(lman_v, MakeIntValue(lman.vit))
	pos_v := MakeCons(MakeIntValue(lman.pos.x), MakeIntValue(lman.pos.y))
	lman_v = append(lman_v, pos_v)
	lman_v = append(lman_v, MakeIntValue(lman.plan))
	lman_v = append(lman_v, MakeIntValue(lman.life))
	lman_v = append(lman_v, MakeIntValue(mp.score))
	st_v = append(st_v, MakeTuple(lman_v))

	var ghosts_v []Value
	for _, ghost := range(mp.ghosts) {
		var ghost_v []Value
		ghost_v = append(ghost_v, MakeIntValue(ghost.vit))
		pos_v := MakeCons(MakeIntValue(ghost.pos.x), MakeIntValue(ghost.pos.y))
		ghost_v = append(ghost_v, pos_v)
		ghost_v = append(ghost_v, MakeIntValue(ghost.plan))
		ghosts_v = append(ghosts_v, MakeTuple(ghost_v))
	}
	st_v = append(st_v, MakeList(ghosts_v))

	st_v = append(st_v, MakeIntValue(mp.fruit))

	return MakeTuple(st_v)
}

func (st *GCCState) run(limit int) {
	for st.cycles = 0; st.cycles < limit; st.cycles++ {
		st.pc_stat[st.c]++

		//fmt.Printf("pc=%d %d\n", st.c, st.cycles)
		inst := st.gcc[st.c]
		if !st.runInst(inst) {
			return
		}
		st.c++
	}
	st.error("Cycle limit exceeded")
}

func (gcc GCC) init(mp *Map) {
	st := MakeGCCState(mp, gcc)

	map_state := st.MakeMapState()
	// TODO: Implement
	ghost_ai := MakeValue(TAG_INT, 0)
	st.push(map_state)
	st.push(ghost_ai)
	st.call(2, 0)

	st.run(3072000 * 60)

	v := st.pop()
	st.checkType(v, TAG_CONS)
	mp.lman.ai_state = v.c.car
	st.checkType(v.c.cdr, TAG_CLOSURE)
	mp.lman.entry = v.c.cdr.v
}

func (gcc GCC) run(mp *Map) int {
	st := MakeGCCState(mp, gcc)

	map_state := st.MakeMapState()
	st.push(mp.lman.ai_state)
	st.push(map_state)
	st.call(2, mp.lman.entry)

	st.run(3072000)

	v := st.pop()
	st.checkType(v, TAG_CONS)
	mp.lman.ai_state = v.c.car
	st.checkType(v.c.cdr, TAG_INT)

	plan := v.c.cdr.v
	fmt.Printf("lman plan (%d cycles) (%d,%d): %d\n",
		st.cycles, st.mp.lman.pos.x, st.mp.lman.pos.y, plan)

	if *flag_call_stat {
		fmt.Println(st.call_stat)
	}
	if *flag_pc_stat {
		fmt.Println(st.pc_stat)
	}

	return plan
}

// Simulator

const (
	WALL = iota
	EMPTY
	PILL
	PPILL
	FRUIT
	LMAN
	GHOST
)

type Pos struct {
	x int
	y int
}

type Lman struct {
	pos Pos
	opos Pos
	life int
	tick int
	plan int
	prog *GCC
	vit int
	eating int
	chain int

	ai_state Value
	entry int
}

type Ghost struct {
	pos Pos
	opos Pos
	tick int
	plan int
	prog *GHC
	id int
	vit int
	mem [256]uint8
}

type Map struct {
	lines [][]uint8
	width int
	height int
	lman *Lman
	ghosts []*Ghost
	fruit int
	score int
	tick int
	elapsed int
}

var ghost_ticks = [4]int{130, 132, 134, 136}
var ghost_frighten_ticks = [4]int{195, 198, 201, 204}

func ParseMap(map_name string) *Map {
	fmt.Printf("Parsing %s...\n", map_name)
	fp := OpenFile(map_name)
	var lines [][]uint8

	lman := new(Lman)
	lman.life = 3
	lman.tick = 0
	lman.plan = 2

	var ghosts []*Ghost

	for true {
		line, err := fp.ReadString('\n')
		if err == io.EOF { break }
		if len(line) < 2 { break }

		var row []uint8
		for x, c := range(line) {
			if c == '\n' {
				break
			}

			if c == '\\' {
				lman.pos = Pos{x, len(lines)}
				lman.opos = Pos{x, len(lines)}
				line = strings.Replace(line, "=", " ", -1)
			} else if c == '=' {
				ghost := new(Ghost)
				ghost.pos = Pos{x, len(lines)}
				ghost.opos = Pos{x, len(lines)}
				ghost.tick = 0
				ghost.plan = 2
				ghost.id = len(ghosts)
				ghosts = append(ghosts, ghost)
			}
			row = append(row, ByteToCell(c))
		}

		lines = append(lines, row)
	}

	mp := new(Map)
	mp.lines = lines
	mp.width = len(lines[0])
	mp.height = len(lines)
	mp.lman = lman
	mp.ghosts = ghosts
	return mp
}

func movePos(pos Pos, plan int) Pos {
	nx := pos.x
	ny := pos.y
	if plan == 0 {
		ny = ny - 1
	} else if plan == 1 {
		nx = nx + 1
	} else if plan == 2 {
		ny = ny + 1
	} else if plan == 3 {
		nx = nx - 1
	}
	return Pos{nx, ny}
}

func ByteToCell(c rune) uint8 {
	switch c {
	case '#':
		return WALL
	case ' ':
		return EMPTY
	case '.':
		return PILL
	case 'o':
		return PPILL
	case '%':
		return FRUIT
	case '\\':
		return LMAN
	case '=':
		return GHOST
	default:
		panic(fmt.Sprintf("Invalid character '%c'", c))
	}
}

func CellToByte(c uint8) uint8 {
	return "# .o%\\="[c]
}

func (mp* Map) get(x int, y int) uint8 {
	return mp.lines[y][x]
}

func (mp* Map) movePos(pos Pos, plan int) Pos {
	npos := movePos(pos, plan)
	nx := npos.x
	ny := npos.y
	if mp.lines[ny][nx] == '#' {
		return pos
	}
	return Pos{nx, ny}
}

func (mp* Map) isValidMove(pos Pos, plan int) bool {
	npos := movePos(pos, plan)
	nx := npos.x
	ny := npos.y
	return mp.lines[ny][nx] != WALL
}

func (mp* Map) updateTimer(t *int) {
	*t -= mp.elapsed
	if *t < 0 { *t = 0 }
}

func (mp* Map) tickStep1() {
	if mp.tick > 2 && mp.lman.tick == 0 {
		mp.lman.plan = mp.lman.prog.run(mp)
		if mp.isValidMove(mp.lman.pos, mp.lman.plan) {
			mp.lman.pos = mp.movePos(mp.lman.pos, mp.lman.plan)
		}
	}

	for _, ghost := range(mp.ghosts) {
		if mp.tick > 2 && ghost.tick == 0 {
			invalid_plan := (ghost.plan + 2) % 4
			plan := -1
			if ghost.prog != nil {
				plan = ghost.prog.run(mp, ghost)
				if plan == invalid_plan || !mp.isValidMove(ghost.pos, plan) {
					plan = -1
				}
			}
			if plan == -1 {
				plan = ghost.plan
			}

			ghost.plan = -1

			if plan != invalid_plan && mp.isValidMove(ghost.pos, plan) {
				ghost.plan = plan
			} else {
				for i := 0; i < 4; i++ {
					if invalid_plan == i {
						continue
					}
					if mp.isValidMove(ghost.pos, i) {
						ghost.plan = i
						break
					}
				}
				if ghost.plan == -1 {
					if mp.isValidMove(ghost.pos, invalid_plan) {
						ghost.plan = invalid_plan
					}
				}
			}

			ghost.pos = mp.movePos(ghost.pos, ghost.plan)
		}
	}
}

func (mp* Map) tickStep2() {
	if mp.lman.vit == 0 {
		mp.lman.chain = 0

		for _, ghost := range(mp.ghosts) {
			if ghost.tick == 0 && ghost.vit > 0 {
				ghost.vit = 0
			}
		}
	}
	// TODO: why this is the right thing...
	mp.updateTimer(&mp.lman.vit)

	mp.updateTimer(&mp.fruit)
	if (mp.tick >= 127 * 200 && mp.tick - mp.elapsed < 127 * 200 ||
		mp.tick >= 127 * 400 && mp.tick - mp.elapsed < 127 * 400) {
		mp.fruit = 127 * 80 - mp.tick % (127 * 200)
	}
}

func (mp* Map) tickStep3() {
	x := mp.lman.pos.x
	y := mp.lman.pos.y

	cell := mp.get(x, y)

	switch cell {
	case PILL:
		mp.lines[y][x] = EMPTY
		//fmt.Printf("eat pill\n");
		mp.lman.eating = 1
		mp.score += 10
	case PPILL:
		mp.lines[y][x] = EMPTY
		mp.lman.eating = 1
		fmt.Printf("eat ppill!\n");
		// TODO: check if vit is zero?
		mp.lman.vit = 127 * 20
		mp.score += 50
		for _, ghost := range(mp.ghosts) {
			if ghost.vit != 2 {
				ghost.vit = 1
			}
			ghost.plan = (ghost.plan + 2) % 4
		}
	case FRUIT:
		if mp.fruit > 0 {
		fmt.Printf("eat fruit\n");
			mp.lman.eating = 1
			level := (mp.width * mp.height + 99) / 100
			if level > 12 { level = 13 }
			fruit_scores := []int{
				100, 300, 500, 500, 700, 700, 1000,
				1000, 2000, 2000, 3000, 3000, 5000,
			}
			mp.fruit = 0
			mp.score += fruit_scores[level]
		}
	}
}

func (mp* Map) tickStep4() {
	for _, ghost := range(mp.ghosts) {
		if ghost.pos != mp.lman.pos || ghost.vit == 2 {
			continue
		}

		if mp.lman.vit > 0 {
			ghost_scores := []int{200, 400, 800, 1600}
			mp.score += ghost_scores[mp.lman.chain]
			mp.lman.chain++
			if mp.lman.chain > 3 { mp.lman.chain = 3 }
			ghost.pos = ghost.opos
			ghost.plan = 2
			ghost.vit = 2
			//ghost.tick = ghost_ticks[ghost.id]
		} else {
			fmt.Printf("died!\n")
			mp.lman.life--
			mp.lman.pos = mp.lman.opos
			mp.lman.plan = 2
			for _, ghost := range(mp.ghosts) {
				ghost.pos = ghost.opos
				ghost.plan = 2
			}
			break
		}
	}
}

func (mp* Map) tickStep5() bool {
	win := true
	for _, row := range(mp.lines) {
		for _, cell := range(row) {
			if cell == PILL {
				win = false
				break
			}
		}
	}
	return win
}

func (mp* Map) tickStep6() bool {
	return mp.lman.life == 0
}

func (mp* Map) tickStep7() {
	if mp.lman.tick == 0 {
		lman_ticks := [2]int{127, 137}
		//eating := mp.lman.eating
		//if mp.lman.vit > 0 { eating = 0 }
		//fmt.Printf("lman eating? %d\n", mp.lman.eating)
		mp.lman.tick = lman_ticks[mp.lman.eating]
		mp.lman.eating = 0
	}

	for i, ghost := range(mp.ghosts) {
		if ghost.tick == 0 {
			if ghost.vit > 0 {
				//fmt.Printf("frightened!\n")
				ghost.tick = ghost_frighten_ticks[i]
			} else {
				//fmt.Printf("not frightened\n")
				ghost.tick = ghost_ticks[i]
			}
		}
	}

	mp.elapsed = mp.lman.tick
	for _, ghost := range(mp.ghosts) {
		if mp.elapsed > ghost.tick {
			mp.elapsed = ghost.tick
		}
	}

	mp.lman.tick -= mp.elapsed
	for _, ghost := range(mp.ghosts) {
		ghost.tick -= mp.elapsed
	}
	//fmt.Printf("e %d\n", mp.elapsed)
	mp.tick += mp.elapsed
}

func (mp* Map) show() {
	var buf bytes.Buffer
	for y := 0; y < mp.height; y++ {
		for x := 0; x < mp.width; x++ {
			c := CellToByte(mp.lines[y][x])

			if c == '%' && mp.fruit > 0 {
				c = '$'
			}

			for i, ghost := range(mp.ghosts) {
				if ghost.pos.x == x && ghost.pos.y == y {
					c = byte('0' + i)
				}
			}
			if mp.lman.pos.x == x && mp.lman.pos.y == y {
				c = byte('/')
			}

			buf.WriteByte(c)
		}
		buf.WriteByte('\n')
	}
	buf.WriteString("Score: ")
	buf.WriteString(strconv.Itoa(mp.score))
	buf.WriteString(" Lives: ")
	buf.WriteString(strconv.Itoa(mp.lman.life))
	buf.WriteString(" Ticks: ")
	buf.WriteString(strconv.Itoa(mp.tick))
	buf.WriteString("\n")
	fmt.Println(buf.String())
}

func main() {
	flag.Parse()

	if flag.NArg() < 3 {
		Error("Usage: go run sim.go MAP GCC GHC GHC...")
	}

	map_name := flag.Arg(0)
	mp := ParseMap(map_name)

	mp.lman.prog = ParseGCC(flag.Arg(1))

	var ghcs []*GHC
	for i := 2; i < flag.NArg(); i++ {
		ghcs = append(ghcs, ParseGHC(flag.Arg(i)))
	}
	for i, ghost := range(mp.ghosts) {
		ghost.prog = ghcs[i % len(ghcs)]
	}

	fmt.Printf("Running init...\n")
	mp.lman.prog.init(mp)

	fmt.Printf("Running game...\n")

	result := 0

	mp.tick = 1
	eol := 127 * mp.width * mp.height * 16
	for mp.tick < eol {
		mp.tickStep1()
		mp.tickStep2()
		mp.tickStep3()
		mp.tickStep4()
		if mp.tickStep5() {
			result = 1
			break
		}
		if mp.tickStep6() {
			result = 2
			break
		}

		if !*flag_quiet || mp.tick % 100 == 0 {
			mp.show()
		}

		mp.tickStep7()
	}

	mp.show()
	if result == 0 {
		fmt.Println("Timeout")
	} else if result == 1 {
		fmt.Println("You win")
	} else if result == 2 {
		fmt.Println("You lose")
	}
}
