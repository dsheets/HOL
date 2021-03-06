structure IR =
struct

open HolKernel Parse boolLib wordsTheory pairLib
     numSyntax

val w32 = Type `:word32`;
val n2w_tm = Term `n2w:num -> word32`;

exception undeclFuncIR;

val sizeHint = 128;
val hashtable : ((string, (Tree.stm list * Tree.exp * Tree.exp)) Polyhash.hash_table) ref =
			ref (Polyhash.mkTable(Polyhash.hash, op = ) (sizeHint, undeclFuncIR))

val inline_funcs = (ref []) : string list ref

fun is_binop op1 =
  if not (is_comb op1) then false
  else let val (uncur, oper) = dest_comb op1 in
       if not (is_const uncur andalso is_const oper) then false
       else let val (uncur_name, uncur_type) = dest_const uncur;
                val (oper_name, oper_type) = dest_const oper
            in
                if not (uncur_name = "UNCURRY") then false
                else if oper_name = "+" orelse
                        oper_name = "-" orelse
                        oper_name = "*" orelse
                        oper_name = "/" orelse
                        oper_name = "&&" orelse
                        oper_name = "!!" orelse
                        oper_name = "<<" orelse
                        oper_name = ">>" orelse
                        oper_name = ">>#" orelse
			oper_name = ">>>" orelse
			oper_name = "??" orelse
            oper_name = "word_or" orelse
            oper_name = "word_and" orelse
            oper_name = "word_xor" orelse
            oper_name = "word_add" orelse
      			oper_name = "word_sub" orelse
      			oper_name = "word_mul" orelse
      			oper_name = "bitwise_and" orelse
      			oper_name = "bitwise_or" orelse
      			oper_name = "word_lsl" orelse
      			oper_name = "word_lsr" orelse
      			oper_name = "word_asr" orelse
      			oper_name = "word_ror" orelse
      			oper_name = "bitwise_eor"
                        then true
                else false
            end
       end;

fun is_relop op1 =
  if not (is_comb op1) then false
  else let val (uncur, oper) = dest_comb op1 in
       if not (is_const uncur andalso is_const oper) then false
       else let val (uncur_name, uncur_type) = dest_const uncur;
      	        val (oper_name, oper_type) = dest_const oper
  	    in
      		if not (uncur_name = "UNCURRY") then false
      		else if oper_name = ">" orelse
     	      		oper_name = ">=" orelse
              		oper_name = "!=" orelse
              		oper_name = "<" orelse
              		oper_name = "<=" orelse
              		oper_name = "=" orelse
                        oper_name = "word_gt" orelse
                        oper_name = "word_lt" orelse
                        oper_name = "word_ge" orelse
                        oper_name = "word_le" orelse
                        oper_name = "word_hs" orelse
                        oper_name = "word_hi" orelse
                        oper_name = "word_lo" orelse
                        oper_name = "word_ls"
      	   		then true
      		else false
	    end
       end;


fun convert_binop bop =
  let val (uncur, oper) = dest_comb bop;
      val (oper_name, oper_type) = dest_const oper
  in
      if oper_name = "+" then Tree.PLUS
      else if oper_name = "-" then Tree.MINUS
      else if oper_name = "*" then Tree.MUL
      else if oper_name = "/" then Tree.DIV
      else if oper_name = "&&" then Tree.AND
      else if oper_name = "!!" then Tree.OR
      else if oper_name = "<<" then Tree.LSHIFT
      else if oper_name = ">>" then Tree.RSHIFT
      else if oper_name = ">>#" then Tree.ARSHIFT
      else if oper_name = ">>>" then Tree.ROR
      else if oper_name = "??" then Tree.XOR

      else if oper_name = "word_and" then Tree.AND
      else if oper_name = "word_or" then Tree.OR
      else if oper_name = "word_xor" then Tree.XOR
      else if oper_name = "word_add" then Tree.PLUS
      else if oper_name = "word_sub" then Tree.MINUS
      else if oper_name = "word_mul" then Tree.MUL
      else if oper_name = "bitwise_and" then Tree.AND
      else if oper_name = "bitwise_or" then Tree.OR
      else if oper_name = "word_lsl" then Tree.LSHIFT
      else if oper_name = "word_lsr" then Tree.RSHIFT
      else if oper_name = "word_asr" then Tree.ARSHIFT
      else if oper_name = "word_ror" then Tree.ROR
      else if oper_name = "bitwise_eor" then Tree.XOR

      else raise ERR "IR" ("invalid bi-operator : " ^ oper_name)
  end;

fun convert_relop rop =
  let val (uncur, oper) = dest_comb rop;
      val (oper_name, oper_type) = dest_const oper
  in
      if oper_name = "=" then Tree.EQ
      else if oper_name = "!=" then Tree.NE
      else if oper_name = "word_ge" then Tree.GE
      else if oper_name = "word_gt" then Tree.GT
      else if oper_name = "word_lt" then Tree.LT
      else if oper_name = "word_le" then Tree.LE
      else if oper_name = "word_hs" then Tree.CS
      else if oper_name = "word_hi" then Tree.HI
      else if oper_name = "word_lo" then Tree.CC
      else if oper_name = "word_ls" then Tree.LS
      else raise ERR "IR" ("invalid relation operator" ^ oper_name)
  end;

structure H = Polyhash
structure T = IntMapTable(type key = int  fun getInt n = n);


val tmpT : (string T.table) ref  = ref (T.empty);
fun getTmp i = T.look(!tmpT,i);


exception Symbol

val sizeHint = 128
val symbolT : ((string,int) H.hash_table) ref =
                ref (H.mkTable(H.hash, op = ) (sizeHint,Symbol));

 fun inspectVar str  =
  case H.peek (!symbolT) str of
     SOME d =>  d
   | NONE => let
        val i = T.numItems (!tmpT) in
	    tmpT := T.enter(!tmpT, i, str);
            H.insert (!symbolT) (str, i);
            i
        end


 fun flow [] exp = exp
  |  flow (h::t) exp = Tree.ESEQ(h, flow t exp);


fun mk_MOVE e1 (Tree.ESEQ(s1, Tree.ESEQ(s2,e2))) =
        Tree.SEQ(s1, mk_MOVE e1 (Tree.ESEQ(s2,e2)))
 |  mk_MOVE e1 (Tree.ESEQ(s1, e2)) =
	Tree.SEQ(s1, Tree.MOVE (e1,e2))
 |  mk_MOVE e1 s = Tree.MOVE (e1,s);


 fun mk_PAIR (Tree.ESEQ(s1,s2)) = mk_PAIR s2
  |  mk_PAIR (Tree.PAIR (e1,e2)) =
	Tree.PAIR(mk_PAIR e1, mk_PAIR e2)
  |  mk_PAIR exp =
	  Tree.TEMP (inspectVar(Temp.makestring(Temp.newtemp())));

 fun analyzeExp exp =

     if is_let exp then
        let val (var, rhs) = dest_let exp;
            val (lhs, rest) = dest_pabs var;
	    		val rt = analyzeExp rhs
        in
	    Tree.ESEQ(Tree.MOVE(analyzeExp lhs, analyzeExp rhs), analyzeExp rest)
        end

     else if is_numeral exp then
	Tree.NCONST (Arbint.fromNat (dest_numeral exp))

     else if not (is_comb exp) then
	if is_var exp then
            let val (v,ty) = dest_var exp in
      	        Tree.TEMP (inspectVar v)
            end
	else
	    Tree.NCONST Arbint.zero

     else if is_cond exp then
        let val (c,t,f) = dest_cond exp;
	    val (t_lab, r_lab) = (Temp.newlabel(), Temp.newlabel());
	    val new_exp = mk_PAIR (analyzeExp t);

	    val insts = flow [ Tree.CJUMP(analyzeExp c, t_lab),
			       mk_MOVE new_exp (analyzeExp f),
			       Tree.JUMP r_lab,
			       Tree.LABEL t_lab,
			       mk_MOVE new_exp (analyzeExp t),
			       Tree.LABEL r_lab]
			      new_exp
	in
	  insts
	end
     else if is_pair exp then
	let val (t1,t2) = dest_pair exp
        in  Tree.PAIR(analyzeExp t1, analyzeExp t2)
	end

     else if is_comb exp then

	let val (operator, operands) = dest_comb exp in

        if is_relop operator then
	    let val (t1, t2) = dest_pair operands
            in
	        Tree.RELOP(convert_relop operator, analyzeExp t1, analyzeExp t2)
	    end

        else if is_binop operator then
            if is_pair operands then 						(* BINOP of binop * exp * exp	*)
	          let val (t1, t2) = dest_pair operands in
	          Tree.BINOP (convert_binop operator, analyzeExp t1, analyzeExp t2)
                  end
	    else Tree.BINOP (convert_binop operator, analyzeExp operands, analyzeExp operands)    (* UNIOP of uniop * exp  *)

	else if same_const operator n2w_tm then				(* words		*)
		Tree.WCONST (Arbint.fromNat (dest_numeral operands))
        else 								(* function call		*)
	    let val (fun_name, fun_type) = dest_const operator in
	        Tree.CALL (Tree.NAME (Temp.namedlabel fun_name),
		           analyzeExp operands)
            end
        end

     else								(* 	0	*)
	    raise ERR "buildIR" "the expression is invalid"


(*
fun
	convert_ESEQ (Tree.ESEQ(Tree.MOVE(e1, e2), Tree.ESEQ(s2,e))) =
   convert_ESEQ (Tree.ESEQ (Tree.SEQ(
		Tree.MOVE(e1, convert_ESEQ e2), s2), convert_ESEQ e))
 |
	convert_ESEQ (Tree.ESEQ(s1, Tree.ESEQ(s2,e))) =
	convert_ESEQ (Tree.ESEQ (Tree.SEQ(s1, s2), convert_ESEQ e))
 |  convert_ESEQ s = s;

convert_ESEQ ir

fun linearize (stm:Tree.stm) : Tree.stm list =
  let
    fun linear (Tree.SEQ(a,b),l) = linear (a, linear(b,l))
     |  linear (s,l) = s::l

    fun discompose_move(Tree.MOVE(Tree.PAIR(e1,e2), Tree.PAIR(e3,e4))) =
	      discompose_move(Tree.MOVE(e1,e3)) @ discompose_move(Tree.MOVE(e2,e4))
     |   discompose_move exp = [exp]
     |   discompose_move exp = [exp]

  in
    List.foldl (fn (exp, L) => L @ discompose_move exp) [] (linear (stm, []))
  end

*)

val nextFreeTemp = ref 0


fun rename_temp_stm (Tree.SEQ (s1, s2)) offset =
		let
			val (s1', m1) = rename_temp_stm s1 offset;
			val (s2', m2) = rename_temp_stm s2 offset;
		in
			(Tree.SEQ (s1', s2'), Int.max (m1, m2))
		end
  | rename_temp_stm (Tree.CJUMP (e, l)) offset =
		let
			val (e', m) = rename_temp_exp e offset;
		in
			(Tree.CJUMP(e', l), m)
		end
  | rename_temp_stm (Tree.MOVE (e1, e2)) offset =
		let
			val (e1', m1) = rename_temp_exp e1 offset;
			val (e2', m2) = rename_temp_exp e2 offset;
		in
			(Tree.MOVE (e1', e2'), Int.max (m1, m2))
		end
  | rename_temp_stm (Tree.EXP e) offset =
		let
			val (e', m) = rename_temp_exp e offset;
		in
			(Tree.EXP e', m)
		end
  | rename_temp_stm X offset =
		(X, 0)
and
	 rename_temp_exp (Tree.BINOP (binop, e1, e2)) offset =
		let
			val (e1', m1) = rename_temp_exp e1 offset;
			val (e2', m2) = rename_temp_exp e2 offset;
		in
			(Tree.BINOP (binop, e1', e2'), Int.max (m1, m2))
		end
 | rename_temp_exp (Tree.MEM e) offset =
		let
			val (e', m) = rename_temp_exp e offset;
		in
			(Tree.MEM e', m)
		end
 | rename_temp_exp (Tree.TEMP t) offset =
		let
			val new_t = t + offset;
			val var_name = "v"^(Int.toString (new_t +1))
			val _ = tmpT := T.enter(!tmpT, new_t, var_name);
		in
			(Tree.TEMP new_t, t)
		end


 | rename_temp_exp (Tree.RELOP (relop, e1, e2)) offset =
		let
			val (e1', m1) = rename_temp_exp e1 offset;
			val (e2', m2) = rename_temp_exp e2 offset;
		in
			(Tree.RELOP (relop, e1', e2'), Int.max (m1, m2))
		end
 | rename_temp_exp (Tree.ESEQ (s, e)) offset =
		let
			val (s', m1) = rename_temp_stm s offset;
			val (e', m2) = rename_temp_exp e offset;
		in
			(Tree.ESEQ (s', e'), Int.max (m1, m2))
		end
 | rename_temp_exp (Tree.CALL (e1, e2)) offset =
		let
			val (e1', m1) = rename_temp_exp e1 offset;
			val (e2', m2) = rename_temp_exp e2 offset;
		in
			(Tree.CALL (e1', e2'), Int.max (m1, m2))
		end
 | rename_temp_exp (Tree.PAIR (e1, e2)) offset =
		let
			val (e1', m1) = rename_temp_exp e1 offset;
			val (e2', m2) = rename_temp_exp e2 offset;
		in
			(Tree.PAIR (e1', e2'), Int.max (m1, m2))
		end
 | rename_temp_exp X offset = (X, 0);



fun
  linerize_IR_stm (Tree.MOVE (e1, Tree.ESEQ (s, e2))) =
		(linerize_IR_stm s) @ linerize_IR_stm (Tree.MOVE (e1, e2)) |
  linerize_IR_stm (Tree.SEQ (s1, s2)) = (linerize_IR_stm s1) @ (linerize_IR_stm s2) |
  linerize_IR_stm (Tree.MOVE(Tree.PAIR(e1,e2), Tree.PAIR(e3,e4))) =
	  linerize_IR_stm (Tree.MOVE(e1,e3)) @ linerize_IR_stm (Tree.MOVE(e2,e4))
  |
  linerize_IR_stm (Tree.MOVE (e1, Tree.CALL (Tree.NAME s, e2))) =
	if (mem (Symbol.name s) (!inline_funcs)) then
		let
			val fun_name = (Symbol.name s);
			val (fun_ir, fun_in, fun_out) = Polyhash.find (!hashtable) fun_name
			val offset = !nextFreeTemp;
			val fun_ir' = map (fn stm => rename_temp_stm stm offset) fun_ir;
			val max = foldl (fn ((x, n1), n2) => Int.max (n1,n2)) 0 fun_ir';
			val fun_ir'' = map fst fun_ir'
			val (fun_in'', max_in) = rename_temp_exp fun_in offset;
			val max = Int.max (max, max_in);
			val (fun_out'', max_out) = rename_temp_exp fun_out offset;
			val max = Int.max (max, max_out);
			val _ = nextFreeTemp := !nextFreeTemp + max
		in
			(linerize_IR_stm (Tree.MOVE (fun_in'', e2)))@fun_ir''@(linerize_IR_stm (Tree.MOVE (e1, fun_out'')))
		end
	else [Tree.MOVE (e1, Tree.CALL (Tree.NAME s, e2))]
  |
  linerize_IR_stm stm = [stm]


fun linerize_IR (Tree.ESEQ (s, e)) =
		let
			val (stmL, e') = linerize_IR e
		in
			(((linerize_IR_stm s) @ stmL), e')
		end
	| linerize_IR (Tree.CALL (Tree.NAME s, e)) =
		let
			val exp = (Tree.CALL (Tree.NAME s, e));
		   val temp_exp = mk_PAIR exp;
			val new_exp = Tree.ESEQ (Tree.MOVE (temp_exp, exp), temp_exp);
		in
			linerize_IR (new_exp)
		end
   | linerize_IR e = ([], e)

fun convert_to_IR prog =
   let
       fun buildArgs args =
	   if is_pair args then
           	let val (arg1,arg2) = dest_pair args
        	in  Tree.PAIR(analyzeExp arg1, analyzeExp arg2) end
	   else analyzeExp args

       val (decl,body) =
           dest_eq(concl(SPEC_ALL prog))
           handle HOL_ERR _
           => (print "not an program in function format\n";
             raise ERR "buildCFG" "invalid program format");
       val (f, args) = dest_comb decl;
       val (f_name, f_type) = dest_const f;

       val _ = (tmpT := T.empty; Polyhash.filter (fn _ => false) (!symbolT));

       val start_lab = Temp.namedlabel (f_name);
       val end_lab = Temp.namedlabel ("end___"^f_name);
		 val body_exp = analyzeExp body; (*updates tempT*)

       val ir = linerize_IR (Tree.ESEQ(Tree.LABEL (start_lab), body_exp));
		 val ir_stmL = (#1 ir)@[Tree.LABEL (end_lab)];
		 val ir_exp = #2 ir
		 val args_exp = buildArgs args;
		 val _ = Polyhash.insert (!hashtable) (f_name, (ir_stmL, args_exp, ir_exp))
   in
       (f_name, f_type, args_exp, ir_stmL, ir_exp)
	handle HOL_ERR _
           => (print "the program body includes invalid expression\n";
             raise ERR "IR" "invalid expression in program body")
   end


fun print_stm ir =
  let val indent = "      ";
      val ((f_name,args,stms,outs):string * Tree.exp * Tree.stm list * Tree.exp) = ir

  fun print_bop Tree.PLUS = "ADD"
   |  print_bop Tree.MINUS = "SUB"
   |  print_bop Tree.MUL = "MUL"
   |  print_bop Tree.DIV = "DIV"
   |  print_bop Tree.AND = "AND"
   |  print_bop Tree.OR = "OR"
   |  print_bop Tree.LSHIFT = "LSL"
   |  print_bop Tree.RSHIFT = "LSR"
   |  print_bop Tree.ARSHIFT = "ASR"
   |  print_bop Tree.XOR = "EOR"
   |  print_bop Tree.ROR = "ROR"

   fun print_rop Tree.GT = ">"
   |  print_rop Tree.EQ = "="
   |  print_rop Tree.LT = "<"
   |  print_rop Tree.NE = "!="
   |  print_rop Tree.GE = ">="
   |  print_rop Tree.LE = "<="
   |  print_rop Tree.CS = ">=+"
   |  print_rop Tree.HI = ">+"
   |  print_rop Tree.CC = "<+"
   |  print_rop Tree.LS = "<=+"
   |  print_rop _ = raise ERR "IR" "invalid relational operator";


  fun one_exp (Tree.BINOP(bop,e1,e2)) =
        (print_bop bop) ^ " " ^ one_exp e1 ^ ", " ^ one_exp e2
   |  one_exp (Tree.RELOP(rop, e1,e2)) =
        (one_exp e1) ^ " " ^ (print_rop rop) ^ " " ^ one_exp e2
   |  one_exp (Tree.MEM e) =
        "MEM[" ^ one_exp e ^ "]"
   |  one_exp (Tree.TEMP e) =
        getTmp e
   |  one_exp (Tree.NAME e) =
        Symbol.name e
   |  one_exp (Tree.NCONST e) =
        Arbint.toString e
   |  one_exp (Tree.WCONST e) =
        (Arbint.toString e) ^ "w"
   |  one_exp (Tree.CALL(f, args)) =
        "CALL " ^ (one_exp f)
   |  one_exp (Tree.PAIR(e1,e2)) =
        "(" ^ one_exp e1 ^ "," ^ one_exp e2 ^ ")"
   |  one_exp _ =
        ""
   ;

  fun one_stm (Tree.MOVE(v1,v2)) =
	indent ^ "MOV " ^ (one_exp v1) ^ ", " ^ (one_exp v2)
   |  one_stm (Tree.LABEL lab) =
        (Symbol.name lab) ^ ":"
   |  one_stm (Tree.JUMP lab) =
        indent ^ "JMP " ^ Symbol.name lab
   |  one_stm (Tree.CJUMP(c,lab)) =
        indent ^ "JNE " ^ Symbol.name lab
   |  one_stm (Tree.EXP exp) =
        one_exp exp
   |  one_stm _ =
        ""
  in

    List.map (fn stm => print(one_stm stm ^ "\n")) stms
  end

end
