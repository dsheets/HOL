(* ------------------------------------------------------------------------ *)
(*  Support running ARM model with a Patricia tree program memory           *)
(* ------------------------------------------------------------------------ *)

(* interactive use:
  app load ["arm_decoderTheory", "arm_opsemTheory", "wordsLib",
            "patriciaTheory", "parmonadsyntax"];
*)

open HolKernel boolLib bossLib Parse;

open patriciaTheory arm_coretypesTheory arm_astTheory arm_seq_monadTheory
     arm_decoderTheory arm_opsemTheory;

val _ = new_theory "arm_eval";

(* ------------------------------------------------------------------------ *)

val _ = numLib.prefer_num();
val _ = wordsLib.prefer_word();

infix \\ << >>

val op \\ = op THEN;
val op << = op THENL;
val op >> = op THEN1;

val _ = temp_overload_on (parmonadsyntax.monad_bind, ``seqT``);
val _ = temp_overload_on (parmonadsyntax.monad_par,  ``parT``);
val _ = temp_overload_on ("return", ``constT``);

(* ------------------------------------------------------------------------ *)

val ptree_fetch_instruction_def = Define`
  ptree_fetch_instruction arch cpsr pc (prog:word8 ptree)
    : (Encoding # word4 # ARMinstruction) option =
    let bytes = [prog ' pc; prog ' (pc + 1);
                 prog ' (pc + 2); prog ' (pc + 3)] in
    let check_bytes = EVERY IS_SOME
    and the_bytes = MAP THE
    in
      if cpsr.T /\ arch <> ARMv4 then (* Thumb *)
        let bytes1 = TAKE 2 bytes
        and bytes2 = DROP 2 bytes
        in
          if check_bytes bytes1 then
            let ireg1 = word16 (the_bytes bytes1) in
              if ((15 -- 13) ireg1 = 0b111w) /\ (12 -- 11) ireg1 <> 0b00w then
                if check_bytes bytes2 then
                  let ireg2 = word16 (the_bytes bytes2) in
                    SOME (Encoding_Thumb2, thumb2_decode cpsr.IT (ireg1,ireg2))
                else
                  NONE
              else (* 16-bit Thumb *)
                SOME (Encoding_Thumb, thumb_decode arch cpsr.IT ireg1)
          else
            NONE
      else if check_bytes bytes then
        SOME (Encoding_ARM,
              arm_decode (version_number arch < 5) (word32 (the_bytes bytes)))
      else
        NONE`;

val ptree_arm_next_def =
  with_flag (computeLib.auto_import_definitions,false) Define
    `ptree_arm_next ii x (pc:word32) (cycle:num) : unit M = arm_instr ii x`;

val ptree_arm_loop_def = Define`
  ptree_arm_loop ii cycle prog t =
    let done s = constT ("at cycle " ++ num_to_dec_string cycle ++ ": " ++ s) in
      if t = 0 then
        done "finished"
      else
       (read_arch ii ||| waiting_for_interrupt ii ||| read_cpsr ii |||
        read_pc ii ||| writeT (\s. s with accesses := [])) >>=
       (\(arch,wfi,cpsr,pc,u).
          if arch = ARMv7_M then
            errorT "ARMv7-M profile not supported"
          else if wfi then
            done "waiting for interrupt"
          else
            case ptree_fetch_instruction arch cpsr (w2n pc) prog
            of SOME x -> ptree_arm_next ii x pc cycle >>=
                         (\u. ptree_arm_loop ii (cycle + 1) prog (t - 1))
            || NONE -> done "couldn't fetch an instruction")`;

val ptree_arm_run_def = Define`
  ptree_arm_run prog s t =
    case ptree_arm_loop <| proc := 0 |> 0 prog t s
    of Error s -> (s, NONE)
    || ValueState v s -> (v, SOME s)`;

(* ------------------------------------------------------------------------ *)

val proc_def =
  with_flag (computeLib.auto_import_definitions,false) Define`
  proc (n:num) f = \(i,x). if i = n then f x else ARB`;

val mk_arm_state_def = Define`
  mk_arm_state arch regs psrs md mem =
    <| registers := proc 0 regs;
       psrs := proc 0 psrs;
       event_register := (K T);
       interrupt_wait := (K F);
       memory := (\a. case patricia$PEEK mem (w2n a)
                        of SOME d -> d
                        || NONE -> md);
       accesses := [];
       information := <| arch := arch;
                         unaligned_support := T;
                         extensions := {} |>;
       coprocessors updated_by
         (Coprocessors_state_fupd (CP15reg_SCTLR_fupd
            (\sctlr. sctlr with <| V := F; A := T; U := F;
                                   IE := T; TE := F; NMFI := T;
                                   EE := T; VE := F |>)));
       monitors := <| ClearExclusiveByAddress := (K (constE ())) |> |>`;

(* ------------------------------------------------------------------------ *)

local
  val tm1 = ``((n:num,r:RName) =+ d:word32)``

  val tm2 =
    ``proc n
        (RName_case r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13
                    r14 r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25
                    r26 r27 r28 r29 r30 r31 (r32:word32))``

  fun reg n = mk_var ("r" ^ Int.toString n, ``:word32``)

  fun reg_update (n,name) =
        mk_eq (mk_comb (Term.subst [``r:RName`` |-> name] tm1, tm2),
               Term.subst [reg n  |-> ``d:word32``] tm2)

  val thm = list_mk_conj (map reg_update (Lib.zip (List.tabulate(33,I))
           [``RName_0usr ``, ``RName_1usr ``, ``RName_2usr ``, ``RName_3usr``,
            ``RName_4usr ``, ``RName_5usr ``, ``RName_6usr ``, ``RName_7usr``,
            ``RName_8usr ``, ``RName_8fiq ``, ``RName_9usr ``, ``RName_9fiq``,
            ``RName_10usr``, ``RName_10fiq``, ``RName_11usr``, ``RName_11fiq``,
            ``RName_12usr``, ``RName_12fiq``,
            ``RName_SPusr``, ``RName_SPfiq``, ``RName_SPirq``, ``RName_SPsvc``,
            ``RName_SPabt``, ``RName_SPund``, ``RName_SPmon``,
            ``RName_LRusr``, ``RName_LRfiq``, ``RName_LRirq``, ``RName_LRsvc``,
            ``RName_LRabt``, ``RName_LRund``, ``RName_LRmon``, ``RName_PC``]))

  val register_update = Tactical.prove(thm,
    SRW_TAC [] [combinTheory.UPDATE_def, FUN_EQ_THM, proc_def]
      \\ Cases_on `x` \\ SRW_TAC [] [] \\ FULL_SIMP_TAC (srw_ss()) []
      \\ Cases_on `r` \\ FULL_SIMP_TAC (srw_ss()) [])
in
  val register_update = save_thm("register_update", GEN_ALL register_update)
end;

local
  val tm1 = ``((n:num,p:PSRName) =+ d:ARMpsr)``
  val tm2 = ``proc n (PSRName_case r0 r1 r2 r3 r4 r5 (r6:ARMpsr))``;

  fun psr n = mk_var ("r" ^ Int.toString n, ``:ARMpsr``)

  fun psr_update (n,name) =
        mk_eq (mk_comb (Term.subst [``p:PSRName`` |-> name] tm1, tm2),
               Term.subst [psr n  |-> ``d:ARMpsr``] tm2)

  val thm = list_mk_conj (map psr_update (Lib.zip (List.tabulate(7,I))
           [``CPSR ``, ``SPSR_fiq ``, ``SPSR_irq ``, ``SPSR_svc``,
            ``SPSR_mon``, ``SPSR_abt``, ``SPSR_und``]))

  val psr_update = Tactical.prove(thm,
    SRW_TAC [] [combinTheory.UPDATE_def, FUN_EQ_THM, proc_def]
      \\ Cases_on `x` \\ SRW_TAC [] [] \\ FULL_SIMP_TAC (srw_ss()) []
      \\ Cases_on `r` \\ FULL_SIMP_TAC (srw_ss()) [])
in
  val psr_update = save_thm("psr_update", GEN_ALL psr_update)
end;

val proc = Q.store_thm("proc", `proc n f (n,x) = f x`, SRW_TAC [] [proc_def]);

val _ = computeLib.add_persistent_funs
  [("combinTheory.o_THM", combinTheory.o_THM), ("proc", proc),
   ("register_update", register_update), ("psr_update", psr_update)];

(* ------------------------------------------------------------------------ *)

val _ = export_theory ();