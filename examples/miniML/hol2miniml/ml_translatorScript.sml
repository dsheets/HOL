open HolKernel Parse boolLib bossLib; val _ = new_theory "ml_translator";

open MiniMLTheory MiniMLTerminationTheory Print_astTerminationTheory
(* open determTheory; *)
open arithmeticTheory listTheory combinTheory pairTheory;
open integerTheory;
open lcsymtacs;

infix \\ val op \\ = op THEN;


(* Definitions *)

val Eval_def = Define `
  Eval env exp P =
    ?res. evaluate' env exp (Rval res) /\ P res`;

val evaluate_closure_def = Define `
  evaluate_closure input cl output =
    ?env exp. (do_app ARB Opapp cl input = SOME (env,exp)) /\
              evaluate' env exp (Rval output)`;

val AppReturns_def = Define ` (* think of this as a Hoare triple {P} cl {Q} *)
  AppReturns P cl Q =
    !v. P v ==> ?u. evaluate_closure v cl u /\ Q u`;

val Arrow_def = Define `
  Arrow a b f =
    \v. !x. AppReturns (a x) v (b (f x))`;

val _ = add_infix("-->",400,HOLgrammars.RIGHT)
val _ = overload_on ("-->",``Arrow``)

val Eq_def = Define `
  Eq (abs:'a->v->bool) x =
    (\y v. (x = y) /\ abs y v)`;

val INT_def = Define `
  INT i = \v. (v = Litv (IntLit i))`;

val NUM_def = Define `
  NUM n = INT (& n)`;

val BOOL_def = Define `
  BOOL b = \v. (v = Litv (Bool b))`;

val CONTAINER_def = Define `CONTAINER x = x`;

val TAG_def = Define `TAG n x = x`;

val PRECONDITION_def = Define `PRECONDITION b = (b:bool)`;

val PreImp_def = Define `
  PreImp b1 b2 = (PRECONDITION b1 ==> b2)`;


(* Theorems *)

val big_exp_determ' = store_thm("big_exp_determ'",
 ``(!env e r1.
      evaluate' env e r1 ==>
     !r2. evaluate' env e r2 ==> (r1 = r2)) /\
   (!env es r1.
      evaluate_list' env es r1 ==>
      !r2. evaluate_list' env es r2 ==> (r1 = r2)) /\
   (!env v pes r1.
      evaluate_match' env v pes r1 ==>
      !r2. evaluate_match' env v pes r2 ==> (r1 = r2))``,
  HO_MATCH_MP_TAC evaluate'_ind >> rw [] >>
  pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss ()) [Once evaluate'_cases]) >>
  fs [] >> rw [] >> fs [] >> res_tac >> fs [] >> rw []);

val evaluate_cases = evaluate'_cases;

val evaluate_11_Rval = prove(
  ``evaluate' env exp (Rval res1) ==>
    evaluate' env exp (Rval res2) ==> (res1 = res2)``,
  REPEAT STRIP_TAC \\ IMP_RES_TAC big_exp_determ'
  \\ FULL_SIMP_TAC (srw_ss()) []);

val Eval_Arrow = store_thm("Eval_Arrow",
  ``Eval env x1 ((a --> b) f) ==>
    Eval env x2 (a x) ==>
    Eval env (App Opapp x1 x2) (b (f x))``,
  SIMP_TAC std_ss [Eval_def,Arrow_def] \\ REPEAT STRIP_TAC
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ FULL_SIMP_TAC std_ss [AppReturns_def] \\ RES_TAC
  \\ FULL_SIMP_TAC std_ss [evaluate_closure_def]
  \\ Q.EXISTS_TAC `u` \\ FULL_SIMP_TAC std_ss []
  \\ Q.LIST_EXISTS_TAC [`res`,`res'`,`env'`]
  \\ FULL_SIMP_TAC (srw_ss()) [do_app_def]);

val Eval_Fun = store_thm("Eval_Fun",
  ``(!v x. a x v ==> Eval ((name,v)::env) body (b (f x))) ==>
    Eval env (Fun name body) ((a --> b) f)``,
  SIMP_TAC std_ss [Eval_def,Arrow_def] \\ REPEAT STRIP_TAC
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ ASM_SIMP_TAC (srw_ss()) [AppReturns_def,Eval_def,do_app_def,
       bind_def,evaluate_closure_def]);

val Eval_Fun_Eq = store_thm("Eval_Fun_Eq",
  ``(!v. a x v ==> Eval ((name,v)::env) body (b (f x))) ==>
    Eval env (Fun name body) ((Eq a x --> b) f)``,
  SIMP_TAC std_ss [Eval_def,Arrow_def] \\ REPEAT STRIP_TAC
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ ASM_SIMP_TAC (srw_ss()) [AppReturns_def,evaluate_closure_def,
       do_app_def,bind_def,Eq_def]);

val Eval_Let = store_thm("Eval_Let",
  ``Eval env exp (a res) /\
    (!v. a res v ==> Eval ((name,v)::env) body (b (f res))) ==>
    Eval env (Let name exp body) (b (LET f res))``,
  SIMP_TAC std_ss [Eval_def,Arrow_def] \\ REPEAT STRIP_TAC
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ RES_TAC \\ Q.EXISTS_TAC `res''` \\ FULL_SIMP_TAC std_ss [LET_DEF,bind_def]
  \\ Q.EXISTS_TAC `res'` \\ FULL_SIMP_TAC std_ss []);

(*
val Eval_Val = store_thm("Eval_Val",
  ``!x. Eval env (Val x) (\v. v = x)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,Eval_def]);
*)

val Eval_Var = store_thm("Eval_Var",
  ``!name x. Eval env (Var name) (\v. v = x) = (lookup name env = SOME x)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,Eval_def]);

val Eval_Var_SWAP_ENV = store_thm("Eval_Var_SWAP_ENV",
  ``!env1.
      Eval env1 (Var name) P /\ (lookup name env = lookup name env1) ==>
      Eval env (Var name) P``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,Eval_def]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases,Eval_def]);

val Eval_Var_EQ = store_thm("Eval_Var_EQ",
  ``Eval env (Var name) ($= x) = (lookup name env = SOME x)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,Eval_def]);

val Eval_Val_INT = store_thm("Eval_Val_INT",
  ``!n. Eval env (Lit (IntLit n)) (INT n)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,NUM_def,INT_def,Eval_def]);

val Eval_Val_NUM = store_thm("Eval_Val_NUM",
  ``!n. Eval env (Lit (IntLit (&n))) (NUM n)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,NUM_def,INT_def,Eval_def]);

val Eval_Val_BOOL = store_thm("Eval_Val_BOOL",
  ``!n. Eval env (Lit (Bool n)) (BOOL n)``,
  SIMP_TAC (srw_ss()) [Once evaluate_cases,BOOL_def,Eval_def]);

val Eval_Or = store_thm("Eval_Or",
  ``Eval env x1 (BOOL b1) ==>
    Eval env x2 (BOOL b2) ==>
    Eval env (Log Or x1 x2) (BOOL (b1 \/ b2))``,
  SIMP_TAC std_ss [Eval_def,NUM_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.EXISTS_TAC `(Litv (Bool b1))` \\ Cases_on `b1`
  \\ FULL_SIMP_TAC (srw_ss()) [do_log_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

val Eval_And = store_thm("Eval_And",
  ``Eval env x1 (BOOL b1) ==>
    Eval env x2 (BOOL b2) ==>
    Eval env (Log And x1 x2) (BOOL (b1 /\ b2))``,
  SIMP_TAC std_ss [Eval_def,NUM_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.EXISTS_TAC `(Litv (Bool b1))` \\ Cases_on `b1`
  \\ FULL_SIMP_TAC (srw_ss()) [do_log_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

val Eval_If = store_thm("Eval_If",
  ``(a1 ==> Eval env x1 (BOOL b1)) /\
    (a2 ==> Eval env x2 (a b2)) /\
    (a3 ==> Eval env x3 (a b3)) ==>
    (a1 /\ (CONTAINER b1 ==> a2) /\ (~CONTAINER b1 ==> a3) ==>
     Eval env (If x1 x2 x3) (a (if b1 then b2 else b3)))``,
  SIMP_TAC std_ss [Eval_def,NUM_def,BOOL_def] \\ SIMP_TAC std_ss [CONTAINER_def]
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Cases_on `b1` \\ FULL_SIMP_TAC std_ss []
  THEN1 (Q.EXISTS_TAC `res` \\ ASM_SIMP_TAC std_ss []
    \\ Q.EXISTS_TAC `Litv (Bool T)` \\ ASM_SIMP_TAC (srw_ss()) [do_if_def])
  THEN1 (Q.EXISTS_TAC `res` \\ ASM_SIMP_TAC std_ss []
    \\ Q.EXISTS_TAC `Litv (Bool F)` \\ ASM_SIMP_TAC (srw_ss()) [do_if_def]));

val Eval_Bool_Not = store_thm("Eval_Bool_Not",
  ``Eval env x1 (BOOL b1) ==>
    Eval env (App Equality x1 (Lit (Bool F))) (BOOL (~b1))``,
  SIMP_TAC std_ss [Eval_def,NUM_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.EXISTS_TAC `(Litv (Bool b1))`
  \\ FULL_SIMP_TAC (srw_ss()) [do_app_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

val Eval_Implies = store_thm("Eval_Implies",
  ``Eval env x1 (BOOL b1) ==>
    Eval env x2 (BOOL b2) ==>
    Eval env (If x1 x2 (Lit (Bool T))) (BOOL (b1 ==> b2))``,
  SIMP_TAC std_ss [Eval_def,NUM_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.EXISTS_TAC `(Litv (Bool b1))` \\ Cases_on `b1`
  \\ FULL_SIMP_TAC (srw_ss()) [do_if_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

val Eval_Var_SIMP = store_thm("Eval_Var_SIMP",
  ``Eval ((x,v)::env) (Var y) p =
      if x = y then p v else Eval env (Var y) p``,
  SIMP_TAC (srw_ss()) [Eval_def,Once evaluate_cases,lookup_def]
  \\ SRW_TAC [] [] \\ SIMP_TAC (srw_ss()) [Eval_def,Once evaluate_cases,lookup_def]);

val Eval_Eq = store_thm("Eval_Eq",
  ``Eval env exp (a x) ==> Eval env exp ((Eq a x) x)``,
  SIMP_TAC std_ss [Eval_def,Eq_def]);

val FUN_FORALL = new_binder_definition("FUN_FORALL",
  ``($FUN_FORALL) = \(abs:'a->'b->v->bool) a v. !y. abs y a v``);

val FUN_EXISTS = new_binder_definition("FUN_EXISTS",
  ``($FUN_EXISTS) = \(abs:'a->'b->v->bool) a v. ?y. abs y a v``);

val Eval_FUN_FORALL = store_thm("Eval_FUN_FORALL",
  ``(!x. Eval env exp ((p x) f)) ==>
    Eval env exp ((FUN_FORALL x. p x) f)``,
  SIMP_TAC std_ss [Eval_def,Arrow_def,Eq_def] \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [AppReturns_def,FUN_FORALL]
  \\ `?res. evaluate' env exp (Rval res)` by METIS_TAC []
  \\ Q.EXISTS_TAC `res` \\ FULL_SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ Q.PAT_ASSUM `!x.bbb` (STRIP_ASSUME_TAC o Q.SPEC `y`)
  \\ IMP_RES_TAC evaluate_11_Rval \\ FULL_SIMP_TAC (srw_ss()) []);

val Eval_FUN_FORALL_EQ = store_thm("Eval_FUN_FORALL_EQ",
  ``(!x. Eval env exp ((p x) f)) =
    Eval env exp ((FUN_FORALL x. p x) f)``,
  REPEAT STRIP_TAC \\ EQ_TAC \\ FULL_SIMP_TAC std_ss [Eval_FUN_FORALL]
  \\ EVAL_TAC \\ FULL_SIMP_TAC std_ss [FUN_FORALL] \\ METIS_TAC []);

val PULL_FORALL = save_thm("PULL_FORALL",
  METIS_PROVE [] ``((p ==> !x. q x) = (!x. p ==> q x)) /\
                   ((p /\ !x. q x) = (!x. p /\ q x))``)

val FUN_FORALL_PUSH1 = prove(
  ``(FUN_FORALL x. a --> (b x)) = (a --> FUN_FORALL x. b x)``,
  FULL_SIMP_TAC std_ss [Arrow_def,FUN_EQ_THM,AppReturns_def,FUN_FORALL,
    Eval_def,evaluate_closure_def] \\ REPEAT STRIP_TAC \\ REVERSE EQ_TAC
  THEN1 METIS_TAC [evaluate_11_Rval]
  \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [PULL_FORALL] \\ RES_TAC
  \\ POP_ASSUM (fn th => STRIP_ASSUME_TAC (Q.SPEC `ARB` th) THEN ASSUME_TAC th)
  \\ FULL_SIMP_TAC std_ss []
  \\ Q.EXISTS_TAC `u` \\ FULL_SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC
  \\ POP_ASSUM (MP_TAC o Q.SPEC `y`) \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [] \\ METIS_TAC [evaluate_11_Rval]) |> GEN_ALL;

val FUN_FORALL_PUSH2 = prove(
  ``(FUN_FORALL x. (a x) --> b) = ((FUN_EXISTS x. a x) --> b)``,
  FULL_SIMP_TAC std_ss [Arrow_def,FUN_EQ_THM,AppReturns_def,FUN_FORALL,FUN_EXISTS,
    Eval_def] \\ METIS_TAC []) |> GEN_ALL;

val FUN_EXISTS_Eq = prove(
  ``(FUN_EXISTS x. Eq a x) = a``,
  SIMP_TAC std_ss [FUN_EQ_THM,FUN_EXISTS,Eq_def]) |> GEN_ALL;

val FUN_QUANT_SIMP = save_thm("FUN_QUANT_SIMP",
  LIST_CONJ [FUN_EXISTS_Eq,FUN_FORALL_PUSH1,FUN_FORALL_PUSH2]);

val Eval_Recclosure = store_thm("Eval_Recclosure",
  ``(!v. a n v ==>
  Eval ((name,v)::(fname,Recclosure env2 [(fname,name,body)] fname)::env2) body (b (f n))) ==>
    Eval env (Var fname) ($= (Recclosure env2 [(fname,name,body)] fname)) ==>
    Eval env (Var fname) ((Eq a n --> b) f)``,
  FULL_SIMP_TAC std_ss [Eval_def,Arrow_def] \\ REPEAT STRIP_TAC
  \\ POP_ASSUM MP_TAC \\ ONCE_REWRITE_TAC [evaluate_cases]
  \\ FULL_SIMP_TAC (srw_ss()) [AppReturns_def,Eq_def,
       do_app_def,evaluate_closure_def]
  \\ SIMP_TAC (srw_ss()) [Once find_recfun_def,Eval_def]
  \\ FULL_SIMP_TAC std_ss [bind_def,build_rec_env_def,FOLDR]);

val SafeVar_def = Define `SafeVar = Var`;

val Eval_Eq_Recclosure = store_thm("Eval_Eq_Recclosure",
  ``Eval env (Var name) ($= (Recclosure x1 x2 x3)) ==>
    (P f (Recclosure x1 x2 x3) =
     Eval env (Var name) (P f))``,
  SIMP_TAC std_ss [Eval_Var_SIMP,Eval_def]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]);

val Eval_Eq_Fun = store_thm("Eval_Eq_Fun",
  ``Eval env (Fun v x) p ==>
    !env2. Eval env2 (Var name) ($= (Closure env v x)) ==>
           Eval env2 (Var name) p``,
  SIMP_TAC std_ss [Eval_Var_SIMP,Eval_def]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]);

val Eval_WEAKEN = store_thm("Eval_WEAKEN",
  ``Eval env exp P ==> (!v. P v ==> Q v) ==> Eval env exp Q``,
  SIMP_TAC std_ss [Eval_def] \\ METIS_TAC []);

val Eval_CONST = store_thm("Eval_CONST",
  ``(!v. P v = (v = x)) ==>
    Eval env (Var name) ($= x) ==> Eval env (Var name) P``,
  SIMP_TAC std_ss [Eval_def])


(* arithmetic for integers *)

val Eval_Opn = prove(
  ``!f n1 n2.
        Eval env x1 (INT n1) ==>
        Eval env x2 (INT n2) ==>
        PRECONDITION (((f = Divide) \/ (f = Modulo)) ==> ~(n2 = 0)) ==>
        Eval env (App (Opn f) x1 x2) (INT (opn_lookup f n1 n2))``,
  SIMP_TAC std_ss [Eval_def,INT_def] \\ SIMP_TAC std_ss [PRECONDITION_def]
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.LIST_EXISTS_TAC [`Litv (IntLit n1)`,`Litv (IntLit n2)`]
  \\ FULL_SIMP_TAC (srw_ss()) [do_app_def]
  \\ Cases_on `f` \\ FULL_SIMP_TAC (srw_ss()) []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

local
  fun f name q =
    save_thm("Eval_" ^ name,SIMP_RULE (srw_ss()) [opn_lookup_def,EVAL ``PRECONDITION T``]
                              (Q.SPEC q Eval_Opn))
in
  val Eval_INT_ADD  = f "INT_ADD" `Plus`
  val Eval_INT_SUB  = f "INT_SUB" `Minus`
  val Eval_INT_MULT = f "INT_MULT" `Times`
  val Eval_INT_DIV  = f "INT_DIV" `Divide`
  val Eval_INT_MOD  = f "INT_MOD" `Modulo`
end

val Eval_Opb = prove(
  ``!f n1 n2.
        Eval env x1 (INT n1) ==>
        Eval env x2 (INT n2) ==>
        Eval env (App (Opb f) x1 x2) (BOOL (opb_lookup f n1 n2))``,
  SIMP_TAC std_ss [Eval_def,INT_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.LIST_EXISTS_TAC [`Litv (IntLit n1)`,`Litv (IntLit n2)`]
  \\ FULL_SIMP_TAC (srw_ss()) [do_app_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []);

local
  fun f name q = let
    val th = SIMP_RULE (srw_ss()) [opb_lookup_def] (Q.SPEC q Eval_Opb)
    val _ = save_thm("Eval_" ^ name,SPEC_ALL th)
   in th end
in
  val Eval_INT_LESS = f "INT_LESS" `Lt`
  val Eval_INT_LESS_EQ = f "INT_LESS_EQ" `Leq`
  val Eval_INT_GREATER = f "INT_GREATER" `Gt`
  val Eval_INT_GREATER_EQ = f "INT_GREATER_EQ" `Geq`
end


(* arithmetic for num *)

val Eval_NUM_ADD = save_thm("Eval_NUM_ADD",
  Eval_INT_ADD |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_ADD]);

val Eval_NUM_MULT = save_thm("Eval_NUM_MULT",
  Eval_INT_MULT |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_MUL]);

val Eval_NUM_DIV = save_thm("Eval_NUM_DIV",
  Eval_INT_DIV |> Q.SPECL [`&n1`,`&n2`]
  |> UNDISCH_ALL |> DISCH ``PRECONDITION (&n2 <> 0)``
  |> SIMP_RULE std_ss [GSYM NUM_def,INT_DIV,PRECONDITION_def,INT_INJ]
  |> CONV_RULE ((RATOR_CONV o RAND_CONV) (ONCE_REWRITE_CONV [GSYM PRECONDITION_def]))
  |> DISCH ``Eval env x2 (INT (&n2))``
  |> DISCH ``Eval env x1 (INT (&n1))``
  |> SIMP_RULE std_ss [GSYM NUM_def,INT_DIV]);

val Eval_NUM_MOD = save_thm("Eval_NUM_MOD",
  Eval_INT_MOD |> Q.SPECL [`&n1`,`&n2`]
  |> UNDISCH_ALL |> DISCH ``PRECONDITION (&n2 <> 0)``
  |> SIMP_RULE std_ss [GSYM NUM_def,INT_MOD,PRECONDITION_def,INT_INJ]
  |> CONV_RULE ((RATOR_CONV o RAND_CONV) (ONCE_REWRITE_CONV [GSYM PRECONDITION_def]))
  |> DISCH ``Eval env x2 (INT (&n2))``
  |> DISCH ``Eval env x1 (INT (&n1))``
  |> SIMP_RULE std_ss [GSYM NUM_def,INT_MOD]);

val Eval_NUM_MULT =
  Eval_INT_MULT |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_MUL]

local

val th0 = Q.SPEC `0` Eval_Val_INT
val th1 = ASSUME ``Eval env (Var "k") (INT k)``
val th2 = Eval_INT_LESS  |> Q.SPECL [`k`,`0`]
          |> (fn th => MATCH_MP th th1) |> (fn th => MATCH_MP th th0)
val th = MATCH_MP Eval_If (LIST_CONJ (map (DISCH T) [th2,th0,th1]))
         |> REWRITE_RULE [CONTAINER_def]
val code =
  ``Let "k" (App (Opn Minus) x1 x2)
      (If (App (Opb Lt) (Var "k") (Lit (IntLit 0)))
          (Lit (IntLit 0)) (Var "k"))``

in

val Eval_NUM_SUB = store_thm("Eval_NUM_SUB",
  ``Eval env x1 (NUM m) ==>
    Eval env x2 (NUM n) ==>
    Eval env ^code (NUM (m - n))``,
  SIMP_TAC std_ss [NUM_def]
  \\ `&(m − n:num) = let k = &m - &n in if k < 0 then 0 else k:int` by
   (FULL_SIMP_TAC std_ss [LET_DEF,INT_LT_SUB_RADD,INT_ADD,INT_LT]
    \\ Cases_on `m<n` \\ FULL_SIMP_TAC std_ss []
    THEN1 (`m - n = 0` by DECIDE_TAC \\ ASM_REWRITE_TAC [])
    \\ FULL_SIMP_TAC std_ss [NOT_LESS,INT_SUB])
  \\ FULL_SIMP_TAC std_ss [] \\ REPEAT STRIP_TAC \\ MATCH_MP_TAC (GEN_ALL Eval_Let)
  \\ Q.EXISTS_TAC `INT` \\ FULL_SIMP_TAC std_ss [] \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [Eval_INT_SUB]
  \\ MATCH_MP_TAC (GEN_ALL (DISCH_ALL th))
  \\ FULL_SIMP_TAC std_ss [Eval_Var_SIMP]);

end;

val Eval_NUM_LESS = save_thm("Eval_NUM_LESS",
  Eval_INT_LESS |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_LT,INT_LE,int_ge,int_gt]);

val Eval_NUM_LESS_EQ = save_thm("Eval_NUM_LESS_EQ",
  Eval_INT_LESS_EQ |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_LT,INT_LE,int_ge,int_gt]);

val Eval_NUM_GREATER = save_thm("Eval_NUM_GREATER",
  Eval_INT_GREATER |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_LT,INT_LE,int_ge,int_gt]
  |> REWRITE_RULE [GSYM GREATER_DEF, GSYM GREATER_EQ]);

val Eval_NUM_GREATER_EQ = save_thm("Eval_NUM_GREATER_EQ",
  Eval_INT_GREATER_EQ |> Q.SPECL [`&n1`,`&n2`]
  |> REWRITE_RULE [GSYM NUM_def,INT_LT,INT_LE,int_ge,int_gt]
  |> REWRITE_RULE [GSYM GREATER_DEF, GSYM GREATER_EQ]);

val Eval_NUM_EQ_0 = store_thm("Eval_NUM_EQ_0",
  ``!n. Eval env x (NUM n) ==>
        Eval env (App (Opb Leq) x (Lit (IntLit 0))) (BOOL (n = 0))``,
  REPEAT STRIP_TAC \\ ASSUME_TAC (Q.SPEC `0` Eval_Val_NUM)
  \\ FULL_SIMP_TAC std_ss [NUM_def]
  \\ `(n = 0) = &n <= 0` by intLib.COOPER_TAC
  \\ FULL_SIMP_TAC std_ss [Eval_INT_LESS_EQ]);


(* Equality *)

val no_closures_def = tDefine "no_closures" `
  (no_closures (Litv l) = T) /\
  (no_closures (Conv name vs) = EVERY no_closures vs) /\
  (no_closures _ = F)`
 (WF_REL_TAC `measure v_size` \\ REPEAT STRIP_TAC
  \\ Induct_on `vs` \\ FULL_SIMP_TAC (srw_ss()) [MEM]
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC (srw_ss()) [MEM,v_size_def]
  \\ DECIDE_TAC)

val EqualityType_def = Define `
  EqualityType (abs:'a->v->bool) =
    (!x1 v1. abs x1 v1 ==> no_closures v1) /\
    (!x1 v1 x2 v2. abs x1 v1 /\ abs x2 v2 ==> ((v1 = v2) = (x1 = x2)))`;

val EqualityType_NUM_BOOL = store_thm("EqualityType_NUM_BOOL",
  ``EqualityType NUM /\ EqualityType INT /\ EqualityType BOOL``,
  EVAL_TAC \\ FULL_SIMP_TAC (srw_ss()) [no_closures_def]);

val Eval_Equality = store_thm("Eval_Equality",
  ``Eval env x1 (a y1) /\ Eval env x2 (a y2) ==>
    EqualityType a ==>
    Eval env (App Equality x1 x2) (BOOL (y1 = y2))``,
  SIMP_TAC std_ss [Eval_def,BOOL_def] \\ SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [evaluate_cases] \\ SIMP_TAC (srw_ss()) []
  \\ Q.LIST_EXISTS_TAC [`res`,`res'`]
  \\ FULL_SIMP_TAC (srw_ss()) [do_app_def]
  \\ ONCE_REWRITE_TAC [evaluate_cases]
  \\ FULL_SIMP_TAC (srw_ss()) [EqualityType_def]);


(* evaluation of declarations *)

val Decls_def = Define `
  Decls cenv1 env1 ds cenv2 env2 =
    evaluate_decs' cenv1 env1 ds (Rval (cenv2,env2))`;

val DeclAssum_def = Define `
  DeclAssum ds env = ?cenv1 env1 cenv2. Decls cenv1 env1 ds cenv2 env`;

val Decls_Dtype = prove(
  ``!cenv env tds cenv1 env1.
      Decls cenv env [Dtype tds] cenv1 env1 =
      check_dup_ctors tds cenv /\ (cenv1 = merge (build_tdefs tds) cenv) /\ (env1 = env)``,
  SIMP_TAC std_ss [Decls_def]
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []);

val Decls_Dlet = prove(
  ``!cenv env v e cenv1 env1.
      Decls cenv env [Dlet (Pvar v) e] cenv1 env1 =
      ?x. (cenv1 = cenv) /\ (env1 = bind v x env) /\ evaluate' env e (Rval x)``,
  SIMP_TAC std_ss [Decls_def]
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []
  \\ FULL_SIMP_TAC (srw_ss()) [pat_bindings_def,ALL_DISTINCT,MEM,pmatch_def,bind_def]
  \\ METIS_TAC []);

val Decls_Dletrec = prove(
  ``!cenv env funs cenv1 env1.
      Decls cenv env [Dletrec funs] cenv1 env1 =
      ALL_DISTINCT (MAP (\(x,y,z). x) funs) /\
      (cenv1 = cenv) /\ (env1 = build_rec_env funs env)``,
  SIMP_TAC std_ss [Decls_def]
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []
  \\ ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) []
  \\ FULL_SIMP_TAC (srw_ss()) [pat_bindings_def,ALL_DISTINCT,MEM,pmatch_def,bind_def]
  \\ METIS_TAC []);

val Decls_APPEND = prove(
  ``!cenv1 cenv3 ds1 ds2 env1 env3.
      Decls cenv1 env1 (ds1 ++ ds2) cenv3 env3 =
      ?cenv2 env2. Decls cenv1 env1 ds1 cenv2 env2 /\
                   Decls cenv2 env2 ds2 cenv3 env3``,
  Induct_on `ds1` \\ FULL_SIMP_TAC std_ss [APPEND,Decls_def]
  THEN1 (ONCE_REWRITE_TAC [evaluate_decs'_cases] \\ SIMP_TAC (srw_ss()) [])
  \\ Cases_on `h` \\ SIMP_TAC (srw_ss()) [Once evaluate_decs'_cases]
  \\ ONCE_REWRITE_TAC [EQ_SYM_EQ]
  \\ SIMP_TAC (srw_ss()) [Once evaluate_decs'_cases]
  \\ METIS_TAC []);

val DeclAssum_Dtype = store_thm("DeclAssum_Dtype",
  ``(!env. DeclAssum ds env ==> Eval env (Var n) P) ==>
    !tds. (!env. DeclAssum (SNOC (Dtype tds) ds) env ==> Eval env (Var n) P)``,
  SIMP_TAC std_ss [DeclAssum_def,SNOC_APPEND,Decls_APPEND,Decls_Dtype]
  \\ METIS_TAC []);

val DeclAssum_Dlet = store_thm("DeclAssum_Dlet",
  ``!ds n P.
      (!env. DeclAssum ds env ==> Eval env (Var n) P) ==>
      !v e. ~(v = n) ==> (!env. DeclAssum (SNOC (Dlet (Pvar v) e) ds) env ==> Eval env (Var n) P)``,
  SIMP_TAC std_ss [DeclAssum_def,SNOC_APPEND,Decls_APPEND,Decls_Dlet]
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss [bind_def,Eval_Var_SIMP]
  \\ METIS_TAC []);

val DeclAssum_Dletrec_LEMMA = prove(
  ``!funs.
      ¬MEM n (MAP FST funs) ==>
      (lookup n (FOLDR (\(f,x,e) env'. bind f (Recclosure env2 ff f) env') env2 funs) =
       lookup n env2)``,
  Induct \\ FULL_SIMP_TAC std_ss [FOLDR,FORALL_PROD,lookup_def,bind_def,MEM,MAP]);

val PULL_EXISTS = save_thm("PULL_EXISTS",
  METIS_PROVE [] ``(((?x. P x) ==> Q) = !x. P x ==> Q) /\
                   (((?x. P x) /\ Q) = ?x. P x /\ Q) /\
                   ((Q /\ (?x. P x)) = ?x. Q /\ P x)``);

val DeclAssum_Dletrec = store_thm("DeclAssum_Dletrec",
  ``!ds n P.
      (!env. DeclAssum ds env ==> Eval env (Var n) P) ==>
      !funs. ~(MEM n (MAP FST funs)) ==>
             (!env. DeclAssum (SNOC (Dletrec funs) ds) env ==> Eval env (Var n) P)``,
  SIMP_TAC std_ss [DeclAssum_def,SNOC_APPEND,Decls_APPEND,Decls_Dletrec]
  \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss [bind_def,Eval_Var_SIMP]
  \\ FULL_SIMP_TAC std_ss [PULL_EXISTS] \\ RES_TAC
  \\ MATCH_MP_TAC Eval_Var_SWAP_ENV
  \\ Q.EXISTS_TAC `env2` \\ FULL_SIMP_TAC std_ss []
  \\ FULL_SIMP_TAC std_ss [build_rec_env_def]
  \\ IMP_RES_TAC DeclAssum_Dletrec_LEMMA
  \\ FULL_SIMP_TAC std_ss []);

val DeclAssum_Dlet_INTRO = store_thm("DeclAssum_Dlet_INTRO",
  ``(!env. DeclAssum ds env ==> Eval env exp P) ==>
    (!v env. DeclAssum (SNOC (Dlet (Pvar v) exp) ds) env ==> Eval env (Var v) P)``,
  FULL_SIMP_TAC std_ss [DeclAssum_def,SNOC_APPEND,Decls_APPEND,Decls_Dlet,
    PULL_EXISTS,bind_def,Eval_Var_SIMP]
  \\ FULL_SIMP_TAC std_ss [Eval_def] \\ METIS_TAC [evaluate_11_Rval]);

val DeclAssum_Dletrec_INTRO = store_thm("DeclAssum_Dletrec_INTRO",
  ``(!env1 env.
      DeclAssum ds env /\ (lookup v env1 = SOME (Recclosure env [(v,xs,f)] v)) ==>
      Eval env1 (Var v) P) ==>
    !env. DeclAssum (SNOC (Dletrec [(v,xs,f)]) ds) env ==> Eval env (Var v) P``,
  FULL_SIMP_TAC std_ss [DeclAssum_def,SNOC_APPEND,Decls_APPEND,Decls_Dletrec,
    MAP,ALL_DISTINCT,MEM,PULL_EXISTS,build_rec_env_def,FOLDR,bind_def,Eval_Var_SIMP]
  \\ SIMP_TAC std_ss [Eval_def] \\ ONCE_REWRITE_TAC [evaluate'_cases]
  \\ SIMP_TAC (srw_ss()) [] \\ REPEAT STRIP_TAC
  \\ Q.PAT_ASSUM `!env1.bbb` (MP_TAC o Q.SPEC `bind v (Recclosure env2 [(v,xs,f)] v) env`)
  \\ FULL_SIMP_TAC (srw_ss()) [lookup_def,bind_def] \\ METIS_TAC []);

(* a few misc. lemmas that help the automation *)

val IMP_PreImp = store_thm("IMP_PreImp",
  ``!b1 b2 b3. (b1 /\ b2 ==> b3) ==> b1 ==> PreImp b2 b3``,
  REPEAT Cases \\ EVAL_TAC);

val evaluate_list_SIMP = store_thm("evaluate_list_SIMP",
  ``(evaluate_list' env [] (Rval []) = T) /\
    (evaluate_list' env (x::xs) (Rval (y::ys)) =
     evaluate' env x (Rval y) /\ evaluate_list' env xs (Rval ys))``,
  REPEAT STRIP_TAC \\ SIMP_TAC std_ss [Once evaluate_cases]
  \\ FULL_SIMP_TAC (srw_ss()) []);

val UNCURRY1 = prove(
  ``!f. UNCURRY f = \x. case x of (x,y) => f x y``,
  STRIP_TAC \\ FULL_SIMP_TAC std_ss [FUN_EQ_THM,pair_case_def]
  \\ Cases \\ FULL_SIMP_TAC std_ss [FUN_EQ_THM,pair_case_def]);

val UNCURRY2 = prove(
  ``!x y f. pair_CASE x f y = pair_CASE x (\z1 z2. f z1 z2 y)``,
  Cases \\ EVAL_TAC \\ SIMP_TAC std_ss []);

val UNCURRY3 = prove(
  ``pair_CASE (x,y) f = f x y``,
  EVAL_TAC) |> GEN_ALL;

val UNCURRY_SIMP = save_thm("UNCURRY_SIMP",
  LIST_CONJ [UNCURRY1,UNCURRY2,UNCURRY3]);

val num_case_thm = store_thm("num_case_thm",
  ``num_CASE = \n b f. if n = 0 then b else f (n-1)``,
  SIMP_TAC std_ss [FUN_EQ_THM,num_case_def] \\ Cases_on `n`
  \\ SIMP_TAC (srw_ss()) [FUN_EQ_THM,num_case_def]);

val PUSH_FORALL_INTO_IMP = save_thm("PUSH_FORALL_INTO_IMP",
  METIS_PROVE [] ``!P Q. (!x. P x ==> Q x) ==> (!x. P x) ==> (!x. Q x)``);

val FALSE_def = Define `FALSE = F`;
val TRUE_def = Define `TRUE = T`;

val _ = export_theory();
