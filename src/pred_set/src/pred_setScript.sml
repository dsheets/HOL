(* =====================================================================*)
(* LIBRARY: pred_set							*)
(* FILE:    mk_pred_set.sml						*)
(* DESCRIPTION: a simple theory of predicates-as-sets			*)
(*									*)
(* AUTHOR:  T. Kalker							*)
(* DATE:    8 June 1989  			         		*)
(*									*)
(* REVISED: Tom Melham (extensively revised and extended)		*)
(* DATE:    January 1992						*)
(* =====================================================================*)

structure pred_setScript =
struct

(* interactive use
app load ["pairLib", "numLib", "PGspec", "PSet_ind"];
*)
open HolKernel Parse boolLib Prim_rec pairLib numLib
     numTheory prim_recTheory arithmeticTheory BasicProvers;

infix THEN THENL THENC ORELSE ORELSEC |->;
infix 8 by


(* ---------------------------------------------------------------------*)
(* Create the new theory.						*)
(* ---------------------------------------------------------------------*)

val _ = new_theory "pred_set";

val _ = type_abbrev ("set", Type`:'a -> bool`);


(* =====================================================================*)
(* Membership. 								*)
(* =====================================================================*)

(* ---------------------------------------------------------------------*)
(* The axiom of specification: x IN {y | P y} iff P x			*)
(* ---------------------------------------------------------------------*)

val SPECIFICATION = store_thm(
  "SPECIFICATION",
  --`!P x. $IN (x:'a) (P:'a set) = P x`--,
  REWRITE_TAC [IN_DEF] THEN BETA_TAC THEN REWRITE_TAC []);

(* --------------------------------------------------------------------- *)
(* Axiom of extension: (s = t) iff !x. x IN s = x in t			*)
(* --------------------------------------------------------------------- *)

val EXTENSION = store_thm
   ("EXTENSION",
    (--`!s t. (s=t) = (!x:'a. x IN s = x IN t)`--),
    REPEAT GEN_TAC THEN
    REWRITE_TAC [SPECIFICATION,SYM (FUN_EQ_CONV (--`f:'a->'b = g`--))]);

val NOT_EQUAL_SETS =
    store_thm
    ("NOT_EQUAL_SETS",
	     (--`!s:'a set. !t. ~(s = t) = ?x. x IN t = ~(x IN s)`--),
     PURE_ONCE_REWRITE_TAC [EXTENSION] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     REPEAT STRIP_TAC THEN EQ_TAC THENL
     [DISCH_THEN (STRIP_THM_THEN MP_TAC) THEN
      ASM_CASES_TAC (--`(x:'a) IN s`--) THEN ASM_REWRITE_TAC [] THEN
      REPEAT STRIP_TAC THEN EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC[],
      STRIP_TAC THEN EXISTS_TAC (--`x:'a`--) THEN
      ASM_CASES_TAC (--`(x:'a) IN s`--) THEN ASM_REWRITE_TAC []]);

(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)

val NUM_SET_WOP =
    store_thm
    ("NUM_SET_WOP",
     (--`!s. (?n. n IN s) = ?n. n IN s /\ (!m. m IN s ==> n <= m)`--),
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [let val th = BETA_RULE (ISPEC (--`\n:num. n IN s`--) WOP)
      in IMP_RES_THEN (X_CHOOSE_THEN (--`N:num`--) STRIP_ASSUME_TAC) th
      end THEN EXISTS_TAC (--`N:num`--) THEN CONJ_TAC THENL
      [FIRST_ASSUM ACCEPT_TAC,
       GEN_TAC THEN CONV_TAC CONTRAPOS_CONV THEN
       ASM_REWRITE_TAC [GSYM NOT_LESS]],
      EXISTS_TAC (--`n:num`--) THEN FIRST_ASSUM ACCEPT_TAC]);

(* ===================================================================== *)
(* Generalized set specification.					 *)
(* ===================================================================== *)
val GSPEC_DEF_LEMMA =
    TAC_PROOF
    (([], (--`?g:('b->('a#bool))-> 'a set.
           !f. !v:'a. v IN (g f) = ?x:'b. (v,T) = f x`--)),
     EXISTS_TAC (--`\f. \y:'a. ?x:'b. (y,T) = f x`--) THEN
     REPEAT GEN_TAC THEN
     PURE_ONCE_REWRITE_TAC [SPECIFICATION] THEN
     CONV_TAC (DEPTH_CONV BETA_CONV) THEN
     REFL_TAC);

(* --------------------------------------------------------------------- *)
(* generalized axiom of specification:					 *)
(*									 *)
(*   GSPECIFICATION = |- !f v. v IN (GSPEC f) = (?x. v,T = f x)		 *)
(* --------------------------------------------------------------------- *)

val GSPECIFICATION =
    new_specification
      {name = "GSPECIFICATION",
      sat_thm = GSPEC_DEF_LEMMA,
      consts = [{const_name = "GSPEC", fixity = Prefix}]};

(* --------------------------------------------------------------------- *)
(* load generalized specification code.					 *)
(* --------------------------------------------------------------------- *)

val SET_SPEC_CONV = PGspec.SET_SPEC_CONV GSPECIFICATION;

(* --------------------------------------------------------------------- *)
(* activate generalized specification parser/pretty-printer.		 *)
(* --------------------------------------------------------------------- *)
(* define_set_abstraction_syntax "GSPEC"; *)
(* set_flag("print_set",true); *)

val _ = add_rule{term_name = "gspec special", fixity = Closefix,
                 pp_elements = [TOK "{", TM, HardSpace 1, TOK "|",
                                BreakSpace(1,0),TM, TOK "}"],
                 paren_style = OnlyIfNecessary,
                 block_style = (AroundEachPhrase, (PP.CONSISTENT, 0))};

(* the phrase "gspec special" is dealt with in the translation from
   pre-pre-terms to terms *)

(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)

val lemma =
    TAC_PROOF
    (([], (--`!s x. x IN s ==>  !f:'a->'b. (f x) IN {f x | x IN s}`--)),
     REPEAT STRIP_TAC THEN CONV_TAC SET_SPEC_CONV THEN
     EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC[]);

val SET_MINIMUM =
    store_thm
    ("SET_MINIMUM",
     (--`!s:'a -> bool. !M.
      (?x. x IN s) = ?x. x IN s /\ !y. y IN s ==> M x <= M y`--),
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [IMP_RES_THEN (ASSUME_TAC o ISPEC (--`M:'a->num`--)) lemma THEN
      let val th = SET_SPEC_CONV (--`(n:num) IN {M x | (x:'a) IN s}`--)
      in IMP_RES_THEN (STRIP_ASSUME_TAC o REWRITE_RULE [th]) NUM_SET_WOP
      end THEN EXISTS_TAC (--`x':'a`--) THEN CONJ_TAC THENL
      [FIRST_ASSUM ACCEPT_TAC,
       FIRST_ASSUM (SUBST_ALL_TAC o SYM) THEN
       REPEAT STRIP_TAC THEN FIRST_ASSUM MATCH_MP_TAC THEN
       EXISTS_TAC (--`y:'a`--) THEN CONJ_TAC THENL
       [REFL_TAC, FIRST_ASSUM ACCEPT_TAC]],
      EXISTS_TAC (--`x:'a`--) THEN FIRST_ASSUM ACCEPT_TAC]);


(* ===================================================================== *)
(* The empty set							 *)
(* ===================================================================== *)

val EMPTY_DEF = new_definition
    ("EMPTY_DEF", (--`EMPTY = (\x:'a.F)`--));

val NOT_IN_EMPTY =
    store_thm
    ("NOT_IN_EMPTY",
     (--`!x:'a.~(x IN EMPTY)`--),
     PURE_REWRITE_TAC [EMPTY_DEF,SPECIFICATION] THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT STRIP_TAC);

val MEMBER_NOT_EMPTY =
    store_thm
    ("MEMBER_NOT_EMPTY",
     (--`!s:'a set. (?x. x IN s) = ~(s = EMPTY)`--),
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     REWRITE_TAC [NOT_CLAUSES]);

(* ===================================================================== *)
(* The set of everything						 *)
(* ===================================================================== *)

val UNIV_DEF = new_definition
    ("UNIV_DEF",(--`UNIV = (\x:'a.T)`--));

val IN_UNIV =
    store_thm
    ("IN_UNIV",
     (--`!x:'a. x IN UNIV`--),
     GEN_TAC THEN PURE_REWRITE_TAC [UNIV_DEF,SPECIFICATION] THEN
     CONV_TAC BETA_CONV THEN ACCEPT_TAC TRUTH);

val UNIV_NOT_EMPTY =
    store_thm
    ("UNIV_NOT_EMPTY",
     (--`~(UNIV:'a set = EMPTY)`--),
     REWRITE_TAC [EXTENSION,IN_UNIV,NOT_IN_EMPTY]);

val EMPTY_NOT_UNIV =
    store_thm
    ("EMPTY_NOT_UNIV",
     (--`~(EMPTY = (UNIV:'a set))`--),
     REWRITE_TAC [EXTENSION,IN_UNIV,NOT_IN_EMPTY]);

val EQ_UNIV =
    store_thm
    ("EQ_UNIV",
     (--`(!x:'a. x IN s) = (s = UNIV)`--),
     REWRITE_TAC [EXTENSION,IN_UNIV]);


(* ===================================================================== *)
(* Set inclusion.							 *)
(* ===================================================================== *)

val SUBSET_DEF = new_infixr_definition
    ("SUBSET_DEF", (--`SUBSET s t =  !x:'a. x IN s ==> x IN t`--),450);

val SUBSET_TRANS = store_thm
    ("SUBSET_TRANS",
     (--`!(s:'a set) t u. s SUBSET t /\ t SUBSET u ==> s SUBSET u`--),
     REWRITE_TAC [SUBSET_DEF] THEN
     REPEAT STRIP_TAC THEN
     REPEAT (FIRST_ASSUM MATCH_MP_TAC) THEN
     FIRST_ASSUM ACCEPT_TAC);

val SUBSET_REFL = store_thm
    ("SUBSET_REFL",
     (--`!(s:'a set). s SUBSET s`--),
     REWRITE_TAC[SUBSET_DEF]);

val SUBSET_ANTISYM = store_thm
    ("SUBSET_ANTISYM",
     (--`!(s:'a set) t. (s SUBSET t) /\ (t SUBSET s) ==> (s = t)`--),
     REWRITE_TAC [SUBSET_DEF, EXTENSION] THEN
     REPEAT STRIP_TAC THEN
     EQ_TAC THEN
     FIRST_ASSUM MATCH_ACCEPT_TAC);

val EMPTY_SUBSET =
    store_thm
    ("EMPTY_SUBSET",
     (--`!s:'a set. EMPTY SUBSET s`--),
     REWRITE_TAC [SUBSET_DEF,NOT_IN_EMPTY]);

val SUBSET_EMPTY =
    store_thm
    ("SUBSET_EMPTY",
     (--`!s:'a set. s SUBSET EMPTY = (s = EMPTY)`--),
     PURE_REWRITE_TAC [SUBSET_DEF,NOT_IN_EMPTY] THEN
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY]);

val SUBSET_UNIV =
    store_thm
    ("SUBSET_UNIV",
     (--`!s:'a set. s SUBSET UNIV`--),
     REWRITE_TAC [SUBSET_DEF,IN_UNIV]);

val UNIV_SUBSET =
    store_thm
    ("UNIV_SUBSET",
     (--`!s:'a set. UNIV SUBSET s = (s = UNIV)`--),
     REWRITE_TAC [SUBSET_DEF,IN_UNIV,EXTENSION]);

(* ===================================================================== *)
(* Proper subset.							 *)
(* ===================================================================== *)

val PSUBSET_DEF =  new_infixr_definition("PSUBSET_DEF",
(--`PSUBSET (s:'a set) t = (s SUBSET t /\ ~(s = t))`--), 450);

val PSUBSET_TRANS = store_thm ("PSUBSET_TRANS",
   (--`!s:'a set. !t u. (s PSUBSET t /\ t PSUBSET u) ==> (s PSUBSET u)`--),
     PURE_ONCE_REWRITE_TAC [PSUBSET_DEF] THEN
     REPEAT GEN_TAC THEN STRIP_TAC THEN CONJ_TAC THENL
     [IMP_RES_TAC SUBSET_TRANS,
      DISCH_THEN SUBST_ALL_TAC THEN
      IMP_RES_TAC SUBSET_ANTISYM THEN
      RES_TAC]);

val PSUBSET_IRREFL =
    store_thm
    ("PSUBSET_IRREFL",
     (--`!s:'a set. ~(s PSUBSET s)`--),
     REWRITE_TAC [PSUBSET_DEF,SUBSET_REFL]);

val NOT_PSUBSET_EMPTY =
    store_thm
    ("NOT_PSUBSET_EMPTY",
     (--`!s:'a set. ~(s PSUBSET EMPTY)`--),
     REWRITE_TAC [PSUBSET_DEF,SUBSET_EMPTY,NOT_AND]);

val NOT_UNIV_PSUBSET =
    store_thm
    ("NOT_UNIV_PSUBSET",
     (--`!s:'a set. ~(UNIV PSUBSET s)`--),
     REWRITE_TAC [PSUBSET_DEF,UNIV_SUBSET,DE_MORGAN_THM] THEN
     GEN_TAC THEN CONV_TAC (RAND_CONV SYM_CONV) THEN
     PURE_ONCE_REWRITE_TAC [DISJ_SYM] THEN
     MATCH_ACCEPT_TAC EXCLUDED_MIDDLE);

val PSUBSET_UNIV =
    store_thm
    ("PSUBSET_UNIV",
     (--`!s:'a set. (s PSUBSET UNIV) = ?x:'a. ~(x IN s)`--),
     REWRITE_TAC [PSUBSET_DEF,SUBSET_UNIV,EXTENSION,IN_UNIV] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN GEN_TAC THEN REFL_TAC);

(* ===================================================================== *)
(* Union								 *)
(* ===================================================================== *)

val UNION_DEF = new_infixl_definition
     ("UNION_DEF", (--`UNION s t = {x:'a | x IN s \/ x IN t}`--),500);

val IN_UNION = store_thm
     ("IN_UNION",
      (--`!s t (x:'a). x IN (s UNION t) = x IN s \/ x IN t`--),
      PURE_ONCE_REWRITE_TAC [UNION_DEF] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      REPEAT GEN_TAC THEN REFL_TAC);

val UNION_ASSOC = store_thm
    ("UNION_ASSOC",
     (--`!(s:'a set) t u. s UNION (t UNION u) = (s UNION t) UNION u`--),
     REWRITE_TAC [EXTENSION, IN_UNION] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     ASM_REWRITE_TAC[]);

val UNION_IDEMPOT = store_thm
    ("UNION_IDEMPOT",
     (--`!(s:'a set). s UNION s = s`--),
     REWRITE_TAC[EXTENSION, IN_UNION]);

val UNION_COMM = store_thm
    ("UNION_COMM",
     (--`!(s:'a set) t. s UNION t = t UNION s`--),
     REWRITE_TAC[EXTENSION, IN_UNION] THEN
     REPEAT GEN_TAC THEN MATCH_ACCEPT_TAC DISJ_SYM);

val SUBSET_UNION =
    store_thm
    ("SUBSET_UNION",
     (--`(!s:'a set. !t. s SUBSET (s UNION t)) /\
      (!s:'a set. !t. s SUBSET (t UNION s))`--),
     PURE_REWRITE_TAC [SUBSET_DEF,IN_UNION] THEN
     REPEAT STRIP_TAC THEN ASM_REWRITE_TAC[]);

val UNION_SUBSET = store_thm(
    "UNION_SUBSET",
  ``!s t u. (s UNION t) SUBSET u = s SUBSET u /\ t SUBSET u``,
  PROVE_TAC [IN_UNION, SUBSET_DEF]);

val SUBSET_UNION_ABSORPTION =
    store_thm
    ("SUBSET_UNION_ABSORPTION",
     (--`!s:'a set. !t. s SUBSET t = (s UNION t = t)`--),
     REWRITE_TAC [SUBSET_DEF,EXTENSION,IN_UNION] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [RES_TAC,ASM_REWRITE_TAC[],RES_TAC]);

val UNION_EMPTY =
    store_thm
    ("UNION_EMPTY",
     (--`(!s:'a set. EMPTY UNION s = s) /\
      (!s:'a set. s UNION EMPTY = s)`--),
     REWRITE_TAC [IN_UNION,EXTENSION,NOT_IN_EMPTY]);

val UNION_UNIV =
    store_thm
    ("UNION_UNIV",
     (--`(!s:'a set. UNIV UNION s = UNIV) /\
      (!s:'a set. s UNION UNIV = UNIV)`--),
     REWRITE_TAC [IN_UNION,EXTENSION,IN_UNIV]);

val EMPTY_UNION = store_thm("EMPTY_UNION",
(--`!s:'a set. !t. (s UNION t = EMPTY) = ((s = EMPTY) /\ (t = EMPTY))`--),
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY,IN_UNION,DE_MORGAN_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN RES_TAC);



(* ===================================================================== *)
(* Intersection								 *)
(* ===================================================================== *)

val INTER_DEF = new_infixl_definition
     ("INTER_DEF",
      (--`INTER s t = {x:'a | x IN s /\ x IN t}`--), 600);

val IN_INTER = store_thm
     ("IN_INTER",
      (--`!s t (x:'a). x IN (s INTER t) = x IN s /\ x IN t`--),
      PURE_ONCE_REWRITE_TAC [INTER_DEF] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      REPEAT GEN_TAC THEN REFL_TAC);

val INTER_ASSOC = store_thm
    ("INTER_ASSOC",
     (--`!(s:'a set) t u. s INTER (t INTER u) = (s INTER t) INTER u`--),
     REWRITE_TAC [EXTENSION, IN_INTER, CONJ_ASSOC]);

val INTER_IDEMPOT = store_thm
    ("INTER_IDEMPOT",
     (--`!(s:'a set). s INTER s = s`--),
     REWRITE_TAC[EXTENSION, IN_INTER]);

val INTER_COMM = store_thm
    ("INTER_COMM",
     (--`!(s:'a set) t. s INTER t = t INTER s`--),
     REWRITE_TAC[EXTENSION, IN_INTER] THEN
     REPEAT GEN_TAC THEN
     MATCH_ACCEPT_TAC CONJ_SYM);

val INTER_SUBSET =
    store_thm
    ("INTER_SUBSET",
     (--`(!s:'a set. !t. (s INTER t) SUBSET s) /\
      (!s:'a set. !t. (t INTER s) SUBSET s)`--),
     PURE_REWRITE_TAC [SUBSET_DEF,IN_INTER] THEN
     REPEAT STRIP_TAC);

val SUBSET_INTER = store_thm(
  "SUBSET_INTER",
  ``!s t u. s SUBSET (t INTER u) = s SUBSET t /\ s SUBSET u``,
  PROVE_TAC [IN_INTER, SUBSET_DEF]);

val SUBSET_INTER_ABSORPTION =
    store_thm
    ("SUBSET_INTER_ABSORPTION",
     (--`!s:'a set. !t. s SUBSET t = (s INTER t = s)`--),
     REWRITE_TAC [SUBSET_DEF,EXTENSION,IN_INTER] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [FIRST_ASSUM ACCEPT_TAC, RES_TAC, RES_TAC]);

val INTER_EMPTY =
    store_thm
    ("INTER_EMPTY",
     (--`(!s:'a set. EMPTY INTER s = EMPTY) /\
      (!s:'a set. s INTER EMPTY = EMPTY)`--),
     REWRITE_TAC [IN_INTER,EXTENSION,NOT_IN_EMPTY]);

val INTER_UNIV =
    store_thm
    ("INTER_UNIV",
     (--`(!s:'a set. UNIV INTER s = s) /\
      (!s:'a set. s INTER UNIV = s)`--),
     REWRITE_TAC [IN_INTER,EXTENSION,IN_UNIV]);


(* ===================================================================== *)
(* Distributivity							 *)
(* ===================================================================== *)

val UNION_OVER_INTER = store_thm
   ("UNION_OVER_INTER",
    (--`!s:'a set. !t u.
      s INTER (t UNION u) = (s INTER t) UNION (s INTER u)`--),
    REWRITE_TAC [EXTENSION,IN_INTER,IN_UNION] THEN
    REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
    ASM_REWRITE_TAC[]);

val INTER_OVER_UNION = store_thm
   ("INTER_OVER_UNION",
    (--`!s:'a set. !t u.
      s UNION (t INTER u) = (s UNION t) INTER (s UNION u)`--),
    REWRITE_TAC [EXTENSION,IN_INTER,IN_UNION] THEN
    REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
    ASM_REWRITE_TAC[]);

(* ===================================================================== *)
(* Disjoint sets.							 *)
(* ===================================================================== *)

val DISJOINT_DEF = new_definition ("DISJOINT_DEF",
(--`DISJOINT (s:'a set) t = ((s INTER t) = EMPTY)`--));

val IN_DISJOINT =
    store_thm
    ("IN_DISJOINT",
     (--`!s:'a set. !t. DISJOINT s t = ~(?x. x IN s /\ x IN t)`--),
     REWRITE_TAC [DISJOINT_DEF,EXTENSION,IN_INTER,NOT_IN_EMPTY] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
     REPEAT GEN_TAC THEN REFL_TAC);

val DISJOINT_SYM =
    store_thm
    ("DISJOINT_SYM",
     (--`!s:'a set. !t. DISJOINT s t = DISJOINT t s`--),
     PURE_ONCE_REWRITE_TAC [DISJOINT_DEF] THEN REPEAT GEN_TAC THEN
     SUBST1_TAC (SPECL [--`s:'a set`--, --`t:'a set`--] INTER_COMM) THEN
     REFL_TAC);

(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)
val DISJOINT_EMPTY =
    store_thm
    ("DISJOINT_EMPTY",
     (--`!s:'a set. DISJOINT EMPTY s /\ DISJOINT s EMPTY`--),
     REWRITE_TAC [DISJOINT_DEF,INTER_EMPTY]);

val DISJOINT_EMPTY_REFL =
    store_thm
    ("DISJOINT_EMPTY_REFL",
     (--`!s:'a set. (s = EMPTY) = (DISJOINT s s)`--),
     REWRITE_TAC [DISJOINT_DEF,INTER_IDEMPOT]);

(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)
val DISJOINT_UNION = store_thm ("DISJOINT_UNION",
--`!(s:'a set) t u. DISJOINT (s UNION t) u = DISJOINT s u /\ DISJOINT t u`--,
     REWRITE_TAC [IN_DISJOINT,IN_UNION] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
     CONV_TAC (ONCE_DEPTH_CONV AND_FORALL_CONV) THEN
     REWRITE_TAC [DE_MORGAN_THM,RIGHT_AND_OVER_OR] THEN
     REPEAT GEN_TAC THEN EQ_TAC THEN
     DISCH_THEN(fn th => GEN_TAC THEN
                         STRIP_ASSUME_TAC (SPEC (--`x:'a`--) th)) THEN
     ASM_REWRITE_TAC []);

val DISJOINT_UNION_BOTH = store_thm(
  "DISJOINT_UNION_BOTH",
  ``!s t u:'a set.
        (DISJOINT (s UNION t) u = DISJOINT s u /\ DISJOINT t u) /\
        (DISJOINT u (s UNION t) = DISJOINT s u /\ DISJOINT t u)``,
  PROVE_TAC [DISJOINT_UNION, DISJOINT_SYM]);

(* ===================================================================== *)
(* Set difference							 *)
(* ===================================================================== *)

val DIFF_DEF = new_infixl_definition
    ("DIFF_DEF",
     (--`DIFF s t = {x:'a | x IN s /\ ~ (x IN t)}`--),500);

val IN_DIFF = store_thm
    ("IN_DIFF",
     (--`!(s:'a set) t x. x IN (s DIFF t) = x IN s /\ ~(x IN t)`--),
     REPEAT GEN_TAC THEN
     PURE_ONCE_REWRITE_TAC [DIFF_DEF] THEN
     CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
     REFL_TAC);

val DIFF_EMPTY =
    store_thm
    ("DIFF_EMPTY",
     (--`!s:'a set. s DIFF EMPTY = s`--),
     GEN_TAC THEN
     REWRITE_TAC [NOT_IN_EMPTY,IN_DIFF,EXTENSION]);

val EMPTY_DIFF =
    store_thm
    ("EMPTY_DIFF",
     (--`!s:'a set. EMPTY DIFF s = EMPTY`--),
     GEN_TAC THEN
     REWRITE_TAC [NOT_IN_EMPTY,IN_DIFF,EXTENSION]);

val DIFF_UNIV =
    store_thm
    ("DIFF_UNIV",
     (--`!s:'a set. s DIFF UNIV = EMPTY`--),
     GEN_TAC THEN
     REWRITE_TAC [NOT_IN_EMPTY,IN_DIFF,IN_UNIV,EXTENSION]);

val DIFF_DIFF =
    store_thm
    ("DIFF_DIFF",
     (--`!s:'a set. !t. (s DIFF t) DIFF t = s DIFF t`--),
     REWRITE_TAC [EXTENSION,IN_DIFF,SYM(SPEC_ALL CONJ_ASSOC)]);

val DIFF_EQ_EMPTY =
    store_thm
    ("DIFF_EQ_EMPTY",
     (--`!s:'a set. s DIFF s = EMPTY`--),
     REWRITE_TAC [EXTENSION,IN_DIFF,NOT_IN_EMPTY,DE_MORGAN_THM] THEN
     PURE_ONCE_REWRITE_TAC [DISJ_SYM] THEN
     REWRITE_TAC [EXCLUDED_MIDDLE]);


(* ===================================================================== *)
(* The insertion function.					         *)
(* ===================================================================== *)

val INSERT_DEF =
    new_infixr_definition
    ("INSERT_DEF", (--`INSERT (x:'a) s = {y | (y = x) \/ y IN s}`--),490);

(* --------------------------------------------------------------------- *)
(* set up sets as a list-form  the {x1;...;xn} notation                  *)
(* --------------------------------------------------------------------- *)

val _ = add_listform {leftdelim = "{", rightdelim = "}", separator = ";",
                      cons = "INSERT", nilstr = "EMPTY"};

(* --------------------------------------------------------------------- *)
(* Theorems about INSERT.						 *)
(* --------------------------------------------------------------------- *)

val IN_INSERT =
     store_thm
     ("IN_INSERT",
      (--`!x:'a. !y s. x IN (y INSERT s) = ((x=y) \/ x IN s)`--),
      PURE_ONCE_REWRITE_TAC [INSERT_DEF] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      REPEAT GEN_TAC THEN REFL_TAC);

val COMPONENT =
     store_thm
     ("COMPONENT",
      (--`!x:'a. !s. x IN (x INSERT s)`--),
      REWRITE_TAC [IN_INSERT]);

val SET_CASES = store_thm("SET_CASES",
(--`!s:'a set.
       (s = EMPTY) \/
       ?x:'a. ?t. ((s = x INSERT t) /\ ~(x IN t))`--),
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY] THEN GEN_TAC THEN
     DISJ_CASES_THEN MP_TAC (SPEC (--`?x:'a. x IN s`--) EXCLUDED_MIDDLE) THENL
     [STRIP_TAC THEN DISJ2_TAC THEN
      MAP_EVERY EXISTS_TAC [--`x:'a`--, --`{y:'a | y IN s /\ ~(y = x)}`--] THEN
      REWRITE_TAC [IN_INSERT] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      ASM_REWRITE_TAC [] THEN
      REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
      ASM_REWRITE_TAC[EXCLUDED_MIDDLE],
      CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
      STRIP_TAC THEN DISJ1_TAC THEN FIRST_ASSUM ACCEPT_TAC]);

val DECOMPOSITION =
    store_thm
    ("DECOMPOSITION",
     (--`!s:'a set. !x. x IN s = ?t. (s = x INSERT t) /\ ~(x IN t)`--),
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [DISCH_TAC THEN EXISTS_TAC (--`{y:'a | y IN s /\ ~(y = x)}`--) THEN
      ASM_REWRITE_TAC [EXTENSION,IN_INSERT] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      REWRITE_TAC [] THEN
      REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
      ASM_REWRITE_TAC [EXCLUDED_MIDDLE],
      STRIP_TAC THEN ASM_REWRITE_TAC [IN_INSERT]]);

val ABSORPTION =
    store_thm
    ("ABSORPTION",
     (--`!x:'a. !s. (x IN s) = (x INSERT s = s)`--),
     REWRITE_TAC [EXTENSION,IN_INSERT] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     ASM_REWRITE_TAC [] THEN
     FIRST_ASSUM (fn th => fn g => PURE_ONCE_REWRITE_TAC [SYM(SPEC_ALL th)] g)
     THEN DISJ1_TAC THEN REFL_TAC);

val INSERT_INSERT =
    store_thm
    ("INSERT_INSERT",
     (--`!x:'a. !s. x INSERT (x INSERT s) = x INSERT s`--),
     REWRITE_TAC [IN_INSERT,EXTENSION] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     ASM_REWRITE_TAC[]);

val INSERT_COMM =
    store_thm
    ("INSERT_COMM",
     (--`!x:'a. !y s. x INSERT (y INSERT s) = y INSERT (x INSERT s)`--),
     REWRITE_TAC [IN_INSERT,EXTENSION] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     ASM_REWRITE_TAC[]);

val INSERT_UNIV =
    store_thm
    ("INSERT_UNIV",
     (--`!x:'a. x INSERT UNIV = UNIV`--),
     REWRITE_TAC [EXTENSION,IN_INSERT,IN_UNIV]);

val NOT_INSERT_EMPTY =
    store_thm
    ("NOT_INSERT_EMPTY",
     (--`!x:'a. !s. ~(x INSERT s = EMPTY)`--),
     REWRITE_TAC [EXTENSION,IN_INSERT,NOT_IN_EMPTY,IN_UNION] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     REPEAT GEN_TAC THEN EXISTS_TAC (--`x:'a`--) THEN
     REWRITE_TAC []);

val NOT_EMPTY_INSERT =
    store_thm
    ("NOT_EMPTY_INSERT",
     (--`!x:'a. !s. ~(EMPTY = x INSERT s)`--),
     REWRITE_TAC [EXTENSION,IN_INSERT,NOT_IN_EMPTY,IN_UNION] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     REPEAT GEN_TAC THEN EXISTS_TAC (--`x:'a`--) THEN
     REWRITE_TAC []);

val INSERT_UNION = store_thm (
  "INSERT_UNION",
  (--`!(x:'a) s t.
        (x INSERT s) UNION t =
        (if x IN t then s UNION t else x INSERT (s UNION t))`--),
  REPEAT GEN_TAC THEN COND_CASES_TAC THEN
  ASM_REWRITE_TAC [EXTENSION,IN_UNION,IN_INSERT] THEN
  REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN ASM_REWRITE_TAC []);

val INSERT_UNION_EQ =
    store_thm
    ("INSERT_UNION_EQ",
     (--`!x:'a. !s t. (x INSERT s) UNION t = x INSERT (s UNION t)`--),
     REPEAT GEN_TAC THEN
     REWRITE_TAC [EXTENSION,IN_UNION,IN_INSERT,DISJ_ASSOC]);

val INSERT_INTER =
    store_thm
    ("INSERT_INTER",
     (--`!x:'a. !s t.
      (x INSERT s) INTER t =
      (if x IN t then x INSERT (s INTER t) else s INTER t)`--),
     REPEAT GEN_TAC THEN COND_CASES_TAC THEN
     ASM_REWRITE_TAC [EXTENSION,IN_INTER,IN_INSERT] THEN
     GEN_TAC THEN EQ_TAC THENL
     [STRIP_TAC THEN ASM_REWRITE_TAC [],
      STRIP_TAC THEN ASM_REWRITE_TAC [],
      PURE_ONCE_REWRITE_TAC [CONJ_SYM] THEN
      DISCH_THEN (CONJUNCTS_THEN MP_TAC) THEN
      STRIP_TAC THEN ASM_REWRITE_TAC [],
      STRIP_TAC THEN ASM_REWRITE_TAC []]);

val DISJOINT_INSERT = store_thm("DISJOINT_INSERT",
(--`!(x:'a) s t. DISJOINT (x INSERT s) t = (DISJOINT s t) /\ ~(x IN t)`--),
     REWRITE_TAC [IN_DISJOINT,IN_INSERT] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
     REWRITE_TAC [DE_MORGAN_THM] THEN
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [let val v = genvar (==`:'a`==)
          val GTAC = X_GEN_TAC v
      in DISCH_THEN (fn th => CONJ_TAC THENL [GTAC,ALL_TAC] THEN MP_TAC th)
         THENL [DISCH_THEN (STRIP_ASSUME_TAC o SPEC v) THEN ASM_REWRITE_TAC [],
                DISCH_THEN (MP_TAC o SPEC (--`x:'a`--)) THEN REWRITE_TAC[]]
      end,
      REPEAT STRIP_TAC THEN ASM_CASES_TAC (--`x':'a = x`--) THENL
      [ASM_REWRITE_TAC[], ASM_REWRITE_TAC[]]]);

val INSERT_SUBSET =
    store_thm
    ("INSERT_SUBSET",
     (--`!x:'a. !s t. (x INSERT s) SUBSET t = (x IN t /\ s SUBSET t)`--),
     REWRITE_TAC [IN_INSERT,SUBSET_DEF] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [FIRST_ASSUM MATCH_MP_TAC THEN DISJ1_TAC THEN REFL_TAC,
      FIRST_ASSUM MATCH_MP_TAC THEN DISJ2_TAC THEN FIRST_ASSUM ACCEPT_TAC,
      ASM_REWRITE_TAC [],
      RES_TAC]);

val SUBSET_INSERT =
    store_thm
    ("SUBSET_INSERT",
     (--`!x:'a. !s. ~(x IN s) ==> !t. s SUBSET (x INSERT t) = s SUBSET t`--),
     PURE_REWRITE_TAC [SUBSET_DEF,IN_INSERT] THEN
     REPEAT STRIP_TAC THEN EQ_TAC THENL
     [REPEAT STRIP_TAC THEN
      let fun tac th g = SUBST_ALL_TAC th g
                         handle  _ => STRIP_ASSUME_TAC th g
      in RES_THEN (STRIP_THM_THEN tac) THEN RES_TAC
      end,
      REPEAT STRIP_TAC THEN DISJ2_TAC THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      FIRST_ASSUM ACCEPT_TAC]);

val INSERT_DIFF =
    store_thm
    ("INSERT_DIFF",
     (--`!s t. !x:'a. (x INSERT s) DIFF t =
     		  (if x IN t then s DIFF t else (x INSERT (s DIFF t)))`--),
     REPEAT GEN_TAC THEN COND_CASES_TAC THENL
     [ASM_REWRITE_TAC [EXTENSION,IN_DIFF,IN_INSERT] THEN
      GEN_TAC THEN EQ_TAC THENL
      [STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
       FIRST_ASSUM (fn th => fn g => SUBST_ALL_TAC th g) THEN RES_TAC,
       STRIP_TAC THEN ASM_REWRITE_TAC[]],
      ASM_REWRITE_TAC [EXTENSION,IN_DIFF,IN_INSERT] THEN
      REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN ASM_REWRITE_TAC [] THENL
      [FIRST_ASSUM (fn th => fn g => SUBST_ALL_TAC th g) THEN RES_TAC,
       RES_TAC]]);

(* ===================================================================== *)
(* Removal of an element						 *)
(* ===================================================================== *)

val DELETE_DEF =
    new_infixl_definition
    ("DELETE_DEF", (--`DELETE s (x:'a) = s DIFF {x}`--),500);

val IN_DELETE =
    store_thm
    ("IN_DELETE",
     (--`!s. !x:'a. !y. x IN (s DELETE y) = (x IN s /\ ~(x = y))`--),
     PURE_ONCE_REWRITE_TAC [DELETE_DEF] THEN
     REWRITE_TAC [IN_DIFF,IN_INSERT,NOT_IN_EMPTY]);

val DELETE_NON_ELEMENT =
    store_thm
    ("DELETE_NON_ELEMENT",
     (--`!x:'a. !s. ~(x IN s) = (s DELETE x = s)`--),
     PURE_REWRITE_TAC [EXTENSION,IN_DELETE] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [FIRST_ASSUM ACCEPT_TAC,
      FIRST_ASSUM (fn th => fn g => SUBST_ALL_TAC th g handle _ => NO_TAC g)
      THEN RES_TAC,
      RES_TAC THEN FIRST_ASSUM MATCH_MP_TAC THEN REFL_TAC]);

val IN_DELETE_EQ =
    store_thm
    ("IN_DELETE_EQ",
     (--`!s x. !x':'a.
      (x IN s = x' IN s) = (x IN (s DELETE x') = x' IN (s DELETE x))`--),
     REPEAT GEN_TAC THEN ASM_CASES_TAC (--`x:'a = x'`--) THENL
     [ASM_REWRITE_TAC [],
      FIRST_ASSUM (ASSUME_TAC o NOT_EQ_SYM) THEN
      ASM_REWRITE_TAC [IN_DELETE]]);

val EMPTY_DELETE =
    store_thm
    ("EMPTY_DELETE",
     (--`!x:'a. EMPTY DELETE x = EMPTY`--),
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY,IN_DELETE]);

val DELETE_DELETE =
    store_thm
    ("DELETE_DELETE",
     (--`!x:'a. !s. (s DELETE x) DELETE x = s DELETE x`--),
     REWRITE_TAC [EXTENSION,IN_DELETE,SYM(SPEC_ALL CONJ_ASSOC)]);

val DELETE_COMM =
    store_thm
    ("DELETE_COMM",
     (--`!x:'a. !y. !s. (s DELETE x) DELETE y = (s DELETE y) DELETE x`--),
     PURE_REWRITE_TAC [EXTENSION,IN_DELETE,CONJ_ASSOC] THEN
     REPEAT GEN_TAC THEN EQ_TAC THEN STRIP_TAC THEN
     REPEAT CONJ_TAC THEN FIRST_ASSUM ACCEPT_TAC);

val DELETE_SUBSET =
    store_thm
    ("DELETE_SUBSET",
     (--`!x:'a. !s. (s DELETE x) SUBSET s`--),
     PURE_REWRITE_TAC [SUBSET_DEF,IN_DELETE] THEN
     REPEAT STRIP_TAC);

val SUBSET_DELETE =
    store_thm
    ("SUBSET_DELETE",
     (--`!x:'a. !s t. s SUBSET (t DELETE x) = (~(x IN s) /\ (s SUBSET t))`--),
     REWRITE_TAC [SUBSET_DEF,IN_DELETE,EXTENSION] THEN
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [REPEAT STRIP_TAC THENL
      [ASSUME_TAC (REFL (--`x:'a`--)) THEN RES_TAC, RES_TAC],
      REPEAT STRIP_TAC THENL
      [RES_TAC, FIRST_ASSUM (fn th => fn g => SUBST_ALL_TAC th g) THEN
       RES_TAC]]);

val SUBSET_INSERT_DELETE =
    store_thm
    ("SUBSET_INSERT_DELETE",
     (--`!x:'a. !s t. s SUBSET (x INSERT t) = ((s DELETE x) SUBSET t)`--),
     REPEAT GEN_TAC THEN
     REWRITE_TAC [SUBSET_DEF,IN_INSERT,IN_DELETE] THEN
     EQ_TAC THEN REPEAT STRIP_TAC THENL
     [RES_TAC THEN RES_TAC,
      ASM_CASES_TAC (--`x':'a = x`--) THEN
      ASM_REWRITE_TAC[] THEN RES_TAC]);

val DIFF_INSERT =
    store_thm
    ("DIFF_INSERT",
     (--`!s t. !x:'a. s DIFF (x INSERT t) = (s DELETE x) DIFF t`--),
     PURE_REWRITE_TAC [EXTENSION,IN_DIFF,IN_INSERT,IN_DELETE] THEN
     REWRITE_TAC [DE_MORGAN_THM,CONJ_ASSOC]);

val PSUBSET_INSERT_SUBSET =
    store_thm
    ("PSUBSET_INSERT_SUBSET",
     (--`!s t. s PSUBSET t = ?x:'a. ~(x IN s) /\ (x INSERT s) SUBSET t`--),
     PURE_REWRITE_TAC [PSUBSET_DEF,NOT_EQUAL_SETS] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [ASM_CASES_TAC (--`(x:'a) IN s`--) THENL
      [ASM_CASES_TAC (--`(x:'a) IN t`--) THENL
       [RES_TAC, IMP_RES_TAC SUBSET_DEF THEN RES_TAC],
       EXISTS_TAC (--`x:'a`--) THEN RES_TAC THEN
       ASM_REWRITE_TAC [INSERT_SUBSET]],
      IMP_RES_TAC INSERT_SUBSET,
      IMP_RES_TAC INSERT_SUBSET THEN
      EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC[]]);

val lemma =
    TAC_PROOF(([], (--`~(a:bool = b) = (b = ~a)`--)),
    BOOL_CASES_TAC (--`b:bool`--) THEN REWRITE_TAC[]);

val PSUBSET_MEMBER = store_thm("PSUBSET_MEMBER",
(--`!s:'a set.
    !t. s PSUBSET t = (s SUBSET t /\ ?y. y IN t /\ ~(y IN s))`--),
     REPEAT GEN_TAC THEN PURE_ONCE_REWRITE_TAC [PSUBSET_DEF] THEN
     PURE_ONCE_REWRITE_TAC [EXTENSION,SUBSET_DEF] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     PURE_ONCE_REWRITE_TAC [lemma] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [RES_TAC,
      EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC [] THEN
      ASM_CASES_TAC (--`(x:'a) IN s`--) THENL
       [RES_TAC THEN RES_TAC,FIRST_ASSUM ACCEPT_TAC],
      RES_TAC,
      EXISTS_TAC (--`y:'a`--) THEN ASM_REWRITE_TAC[]]);

val DELETE_INSERT = store_thm("DELETE_INSERT",
(--`!(x:'a) y s.
    (x INSERT s) DELETE y = (if (x=y) then s DELETE y
                             else x INSERT (s DELETE y))`--),
     REWRITE_TAC [EXTENSION,IN_DELETE,IN_INSERT] THEN
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [DISCH_THEN (STRIP_THM_THEN MP_TAC) THEN DISCH_TAC THEN
      let fun tac th g = SUBST_ALL_TAC th g handle _ => ASSUME_TAC th g
      in DISCH_THEN (STRIP_THM_THEN tac) THENL
         [ASM_REWRITE_TAC [IN_INSERT],
         COND_CASES_TAC THEN ASM_REWRITE_TAC [IN_DELETE,IN_INSERT]]
      end,
      COND_CASES_TAC THEN ASM_REWRITE_TAC [IN_DELETE,IN_INSERT] THENL
      [STRIP_TAC THEN ASM_REWRITE_TAC [],
       STRIP_TAC THEN ASM_REWRITE_TAC []]]);

val INSERT_DELETE =
    store_thm
    ("INSERT_DELETE",
     (--`!x:'a. !s. x IN s ==> (x INSERT (s DELETE x) = s)`--),
     PURE_REWRITE_TAC [EXTENSION,IN_INSERT,IN_DELETE] THEN
     REPEAT GEN_TAC THEN DISCH_THEN (fn th => GEN_TAC THEN MP_TAC th) THEN
     ASM_CASES_TAC (--`x':'a = x`--) THEN ASM_REWRITE_TAC[]);

(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)
val DELETE_INTER =
    store_thm
    ("DELETE_INTER",
     (--`!s t. !x:'a. (s DELETE x) INTER t = (s INTER t) DELETE x`--),
     PURE_ONCE_REWRITE_TAC [EXTENSION] THEN REPEAT GEN_TAC THEN
     REWRITE_TAC [IN_INTER,IN_DELETE] THEN
     EQ_TAC THEN REPEAT STRIP_TAC THEN
     FIRST [FIRST_ASSUM ACCEPT_TAC,RES_TAC]);


(* --------------------------------------------------------------------- *)
(* A theorem from homeier@org.aero.uniblab (Peter Homeier)		 *)
(* --------------------------------------------------------------------- *)
val DISJOINT_DELETE_SYM =
    store_thm
    ("DISJOINT_DELETE_SYM",
     (--`!s t. !x:'a. DISJOINT (s DELETE x) t = DISJOINT (t DELETE x) s`--),
     REWRITE_TAC [DISJOINT_DEF,EXTENSION,NOT_IN_EMPTY] THEN
     REWRITE_TAC [IN_INTER,IN_DELETE,DE_MORGAN_THM] THEN
     REPEAT GEN_TAC THEN EQ_TAC THEN
     let val X = (--`X:'a`--)
     in DISCH_THEN (fn th => X_GEN_TAC X THEN STRIP_ASSUME_TAC (SPEC X th))
        THEN ASM_REWRITE_TAC []
     end);

(* ===================================================================== *)
(* Choice								 *)
(* ===================================================================== *)

val CHOICE_EXISTS =
    TAC_PROOF
    (([], (--`?CHOICE. !s:'a set. ~(s = EMPTY) ==> (CHOICE s) IN s`--)),
     REWRITE_TAC [EXTENSION,NOT_IN_EMPTY] THEN
     EXISTS_TAC (--`\s. @x:'a. x IN s`--) THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     CONV_TAC (ONCE_DEPTH_CONV SELECT_CONV) THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     REWRITE_TAC []);

val CHOICE_DEF = new_specification
                   {name= "CHOICE_DEF",sat_thm=CHOICE_EXISTS,
                    consts=[{const_name="CHOICE",fixity=Prefix}]};

(* ===================================================================== *)
(* The REST of a set after removing a chosen element.			 *)
(* ===================================================================== *)

val REST_DEF =
    new_definition
    ("REST_DEF", (--`REST (s:'a set) = s DELETE (CHOICE s)`--));

val CHOICE_NOT_IN_REST =
    store_thm
    ("CHOICE_NOT_IN_REST",
     (--`!s:'a set. ~(CHOICE s IN REST s)`--),
     REWRITE_TAC [IN_DELETE,REST_DEF]);

val CHOICE_INSERT_REST = store_thm("CHOICE_INSERT_REST",
(--`!s:'a set. ~(s = EMPTY) ==> ((CHOICE s) INSERT (REST s) = s)`--),
     REPEAT GEN_TAC THEN STRIP_TAC THEN
     REWRITE_TAC [EXTENSION,IN_INSERT,REST_DEF,IN_DELETE] THEN
     GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL
     [IMP_RES_TAC CHOICE_DEF THEN ASM_REWRITE_TAC [],
      ASM_REWRITE_TAC [EXCLUDED_MIDDLE]]);

val REST_SUBSET =
    store_thm
    ("REST_SUBSET",
     (--`!s:'a set. (REST s) SUBSET s`--),
     REWRITE_TAC [SUBSET_DEF,REST_DEF,IN_DELETE] THEN REPEAT STRIP_TAC);

val lemma =
    TAC_PROOF(([], (--`(P /\ Q = P) = (P ==> Q)`--)),
    	      BOOL_CASES_TAC (--`P:bool`--) THEN REWRITE_TAC[]);

val REST_PSUBSET =
    store_thm
    ("REST_PSUBSET",
     (--`!s:'a set. ~(s = EMPTY) ==> (REST s) PSUBSET s`--),
     REWRITE_TAC [PSUBSET_DEF,REST_SUBSET] THEN
     GEN_TAC THEN STRIP_TAC THEN
     REWRITE_TAC [EXTENSION,REST_DEF,IN_DELETE] THEN
     CONV_TAC NOT_FORALL_CONV THEN
     REWRITE_TAC [DE_MORGAN_THM,lemma,NOT_IMP] THEN
     EXISTS_TAC (--`CHOICE (s:'a set)`--) THEN
     IMP_RES_TAC CHOICE_DEF THEN
     ASM_REWRITE_TAC []);


(* ===================================================================== *)
(* Singleton set.							 *)
(* ===================================================================== *)

val SING_DEF =
    new_definition
    ("SING_DEF", (--`SING s = ?x:'a. s = {x}`--));

val SING =
    store_thm
    ("SING",
     (--`!x:'a. SING {x}`--),
     PURE_ONCE_REWRITE_TAC [SING_DEF] THEN
     GEN_TAC THEN EXISTS_TAC (--`x:'a`--) THEN REFL_TAC);

val IN_SING =
    store_thm
    ("IN_SING",
     (--`!x y. x IN {y:'a} = (x = y)`--),
     REWRITE_TAC [IN_INSERT,NOT_IN_EMPTY]);

val NOT_SING_EMPTY =
    store_thm
    ("NOT_SING_EMPTY",
     (--`!x:'a. ~({x} = EMPTY)`--),
     REWRITE_TAC [EXTENSION,IN_SING,NOT_IN_EMPTY] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     GEN_TAC THEN EXISTS_TAC (--`x:'a`--) THEN REWRITE_TAC[]);

val NOT_EMPTY_SING =
    store_thm
    ("NOT_EMPTY_SING",
     (--`!x:'a. ~(EMPTY = {x})`--),
     REWRITE_TAC [EXTENSION,IN_SING,NOT_IN_EMPTY] THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
     GEN_TAC THEN EXISTS_TAC (--`x:'a`--) THEN REWRITE_TAC[]);

val EQUAL_SING =
    store_thm
    ("EQUAL_SING",
     (--`!x:'a. !y. ({x} = {y}) = (x = y)`--),
     REWRITE_TAC [EXTENSION,IN_SING] THEN
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [DISCH_THEN (fn th => REWRITE_TAC [SYM(SPEC_ALL th)]),
      DISCH_THEN SUBST1_TAC THEN GEN_TAC THEN REFL_TAC]);

val DISJOINT_SING_EMPTY =
    store_thm
    ("DISJOINT_SING_EMPTY",
     (--`!x:'a. DISJOINT {x} EMPTY`--),
     REWRITE_TAC [DISJOINT_DEF,INTER_EMPTY]);

val INSERT_SING_UNION =
    store_thm
    ("INSERT_SING_UNION",
     (--`!s. !x:'a. x INSERT s = {x} UNION s`--),
     REWRITE_TAC [EXTENSION,IN_INSERT,IN_UNION,NOT_IN_EMPTY]);

val SING_DELETE =
    store_thm
    ("SING_DELETE",
    (--`!x:'a. {x} DELETE x = EMPTY`--),
    REWRITE_TAC [EXTENSION,NOT_IN_EMPTY,IN_DELETE,IN_INSERT] THEN
    PURE_ONCE_REWRITE_TAC [CONJ_SYM] THEN
    REWRITE_TAC [DE_MORGAN_THM,EXCLUDED_MIDDLE]);

val DELETE_EQ_SING =
    store_thm
    ("DELETE_EQ_SING",
     (--`!s. !x:'a. (x IN s) ==> ((s DELETE x = EMPTY) = (s = {x}))`--),
     PURE_ONCE_REWRITE_TAC [EXTENSION] THEN
     REWRITE_TAC [NOT_IN_EMPTY,DE_MORGAN_THM,IN_INSERT,IN_DELETE] THEN
     REPEAT STRIP_TAC THEN EQ_TAC THENL
     [DISCH_TAC THEN GEN_TAC THEN
      FIRST_ASSUM (fn th=>fn g => STRIP_ASSUME_TAC (SPEC (--`x':'a`--) th) g)
      THEN ASM_REWRITE_TAC [] THEN DISCH_THEN SUBST_ALL_TAC THEN RES_TAC,
      let val th = PURE_ONCE_REWRITE_RULE [DISJ_SYM] EXCLUDED_MIDDLE
      in DISCH_TAC THEN GEN_TAC THEN ASM_REWRITE_TAC [th]
      end]);

val CHOICE_SING =
    store_thm
    ("CHOICE_SING",
     (--`!x:'a. CHOICE {x} = x`--),
     GEN_TAC THEN
     MP_TAC (MATCH_MP CHOICE_DEF (SPEC (--`x:'a`--) NOT_SING_EMPTY)) THEN
     REWRITE_TAC [IN_SING]);

val REST_SING =
    store_thm
    ("REST_SING",
     (--`!x:'a. REST {x} = EMPTY`--),
     REWRITE_TAC [CHOICE_SING,REST_DEF,SING_DELETE]);

val SING_IFF_EMPTY_REST =
    store_thm
    ("SING_IFF_EMPTY_REST",
     (--`!s:'a set. SING s = ~(s = EMPTY) /\ (REST s = EMPTY)`--),
     PURE_ONCE_REWRITE_TAC [SING_DEF] THEN
     GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL
     [ASM_REWRITE_TAC [REST_SING] THEN
      REWRITE_TAC [EXTENSION,NOT_IN_EMPTY,IN_INSERT] THEN
      CONV_TAC NOT_FORALL_CONV THEN
      EXISTS_TAC (--`x:'a`--) THEN REWRITE_TAC [],
      EXISTS_TAC (--`CHOICE s:'a`--) THEN
      IMP_RES_THEN (SUBST1_TAC o SYM) CHOICE_INSERT_REST THEN
      ASM_REWRITE_TAC [EXTENSION,IN_SING,CHOICE_SING]]);



(* ===================================================================== *)
(* The image of a function on a set.					 *)
(* ===================================================================== *)

val IMAGE_DEF =
    new_definition
    ("IMAGE_DEF", (--`IMAGE (f:'a->'b) s = {f x | x IN s}`--));

val IN_IMAGE =
    store_thm
    ("IN_IMAGE",
     (--`!y:'b. !s f. (y IN (IMAGE f s)) = ?x:'a. (y = f x) /\ x IN s`--),
      PURE_ONCE_REWRITE_TAC [IMAGE_DEF] THEN
      CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
      REPEAT GEN_TAC THEN REFL_TAC);

val IMAGE_IN =
    store_thm
    ("IMAGE_IN",
     (--`!x s. (x IN s) ==> !(f:'a->'b). f x IN (IMAGE f s)`--),
     PURE_ONCE_REWRITE_TAC [IN_IMAGE] THEN
     REPEAT STRIP_TAC THEN
     EXISTS_TAC (--`x:'a`--) THEN
     CONJ_TAC THENL [REFL_TAC, FIRST_ASSUM ACCEPT_TAC]);

val IMAGE_EMPTY =
     store_thm
     ("IMAGE_EMPTY",
      (--`!f:'a->'b. IMAGE f EMPTY = EMPTY`--),
      REWRITE_TAC[EXTENSION,IN_IMAGE,NOT_IN_EMPTY]);

val IMAGE_ID =
    store_thm
    ("IMAGE_ID",
     (--`!s:'a set. IMAGE (\x:'a.x) s = s`--),
     REWRITE_TAC [EXTENSION,IN_IMAGE] THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [ALL_TAC,EXISTS_TAC (--`x:'a`--)] THEN
     ASM_REWRITE_TAC []);

val o_THM = combinTheory.o_THM;

val IMAGE_COMPOSE =
    store_thm
    ("IMAGE_COMPOSE",
     (--`!f:'b->'c. !g:'a->'b. !s. IMAGE (f o g) s = IMAGE f (IMAGE g s)`--),
     PURE_REWRITE_TAC [EXTENSION,IN_IMAGE,o_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [EXISTS_TAC (--`g (x':'a):'b`--) THEN
      CONJ_TAC THENL [ALL_TAC,EXISTS_TAC (--`x':'a`--)] THEN
      ASM_REWRITE_TAC [],
      EXISTS_TAC (--`x'':'a`--) THEN ASM_REWRITE_TAC[]]);

val IMAGE_INSERT =
    store_thm
    ("IMAGE_INSERT",
     (--`!(f:'a->'b) x s. IMAGE f (x INSERT s) = f x INSERT (IMAGE f s)`--),
     PURE_REWRITE_TAC [EXTENSION,IN_INSERT,IN_IMAGE] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [ALL_TAC,DISJ2_TAC THEN EXISTS_TAC (--`x'':'a`--),
      EXISTS_TAC (--`x:'a`--),EXISTS_TAC (--`x'':'a`--)] THEN
     ASM_REWRITE_TAC[]);

val IMAGE_EQ_EMPTY =
    store_thm
    ("IMAGE_EQ_EMPTY",
     (--`!s. !f:'a->'b. ((IMAGE f s) = EMPTY) = (s = EMPTY)`--),
     GEN_TAC THEN
     STRIP_ASSUME_TAC (SPEC (--`s:'a set`--) SET_CASES) THEN
     ASM_REWRITE_TAC [IMAGE_EMPTY,IMAGE_INSERT,NOT_INSERT_EMPTY]);

val IMAGE_DELETE = store_thm("IMAGE_DELETE",
(--`!(f:'a->'b) x s. ~(x IN s) ==> (IMAGE f (s DELETE x) = (IMAGE f s))`--),
     REPEAT GEN_TAC THEN STRIP_TAC THEN
     PURE_REWRITE_TAC [EXTENSION,IN_DELETE,IN_IMAGE] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     EXISTS_TAC (--`x'':'a`--) THEN ASM_REWRITE_TAC [] THEN
     DISCH_THEN SUBST_ALL_TAC THEN RES_TAC);

val IMAGE_UNION = store_thm("IMAGE_UNION",
(--`!(f:'a->'b) s t. IMAGE f (s UNION t) = (IMAGE f s) UNION (IMAGE f t)`--),
     PURE_REWRITE_TAC [EXTENSION,IN_UNION,IN_IMAGE] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [DISJ1_TAC,DISJ2_TAC,ALL_TAC,ALL_TAC] THEN
     EXISTS_TAC (--`x':'a`--) THEN ASM_REWRITE_TAC []);

val IMAGE_SUBSET =
    store_thm
    ("IMAGE_SUBSET",
     (--`!s t. (s SUBSET t) ==> !f:'a->'b. (IMAGE f s) SUBSET (IMAGE f t)`--),
     PURE_REWRITE_TAC [SUBSET_DEF,IN_IMAGE] THEN
     REPEAT STRIP_TAC THEN RES_TAC THEN
     EXISTS_TAC (--`x':'a`--) THEN ASM_REWRITE_TAC []);

val IMAGE_INTER = store_thm ("IMAGE_INTER",
--`!(f:'a->'b) s t. IMAGE f (s INTER t) SUBSET (IMAGE f s INTER IMAGE f t)`--,
     REPEAT GEN_TAC THEN
     REWRITE_TAC [SUBSET_DEF,IN_IMAGE,IN_INTER] THEN
     REPEAT STRIP_TAC THEN
     EXISTS_TAC (--`x':'a`--) THEN
     CONJ_TAC THEN FIRST_ASSUM ACCEPT_TAC);


(* ===================================================================== *)
(* Injective functions on a set.					 *)
(* ===================================================================== *)

val INJ_DEF =
    new_definition
    ("INJ_DEF",
     (--`INJ (f:'a->'b) s t =
          (!x. x IN s ==> (f x) IN t) /\
          (!x y. (x IN s /\ y IN s) ==> (f x = f y) ==> (x = y))`--));

val INJ_ID =
    store_thm
    ("INJ_ID",
     (--`!s. INJ (\x:'a.x) s s`--),
     PURE_ONCE_REWRITE_TAC [INJ_DEF] THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT STRIP_TAC);

val INJ_COMPOSE =
    store_thm
    ("INJ_COMPOSE",
     (--`!f:'a->'b. !g:'b->'c.
      !s t u. (INJ f s t  /\ INJ g t u) ==> INJ (g o f) s u`--),
     PURE_REWRITE_TAC [INJ_DEF,o_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [FIRST_ASSUM MATCH_MP_TAC THEN RES_TAC,
      RES_TAC THEN RES_TAC]);

val INJ_EMPTY =
    store_thm
    ("INJ_EMPTY",
     (--`!f:'a->'b. (!s. INJ f {} s) /\ (!s. INJ f s {} = (s = {}))`--),
     REWRITE_TAC [INJ_DEF,NOT_IN_EMPTY,EXTENSION] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN RES_TAC);


(* ===================================================================== *)
(* Surjective functions on a set.					 *)
(* ===================================================================== *)

val SURJ_DEF =
    new_definition
    ("SURJ_DEF",
     (--`SURJ (f:'a->'b) s t =
           (!x. x IN s ==> (f x) IN t) /\
           (!x. (x IN t) ==> ?y. y IN s /\ (f y = x))`--));

val SURJ_ID =
    store_thm
    ("SURJ_ID",
     (--`!s. SURJ (\x:'a.x) s s`--),
     PURE_ONCE_REWRITE_TAC [SURJ_DEF] THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT STRIP_TAC THEN
     EXISTS_TAC (--`x:'a`--) THEN
     ASM_REWRITE_TAC []);

val SURJ_COMPOSE =
    store_thm
    ("SURJ_COMPOSE",
     (--`!f:'a->'b. !g:'b->'c.
      !s t u. (SURJ f s t  /\ SURJ g t u) ==> SURJ (g o f) s u`--),
     PURE_REWRITE_TAC [SURJ_DEF,o_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
     [FIRST_ASSUM MATCH_MP_TAC THEN RES_TAC,
      RES_TAC THEN RES_TAC THEN
      EXISTS_TAC (--`y'':'a`--) THEN
      ASM_REWRITE_TAC []]);

val SURJ_EMPTY = store_thm ("SURJ_EMPTY",
--`!f:'a->'b. (!s. SURJ f {} s = (s = {})) /\ (!s. SURJ f s {} = (s = {}))`--,
     REWRITE_TAC [SURJ_DEF,NOT_IN_EMPTY,EXTENSION]);

val IMAGE_SURJ =
    store_thm
    ("IMAGE_SURJ",
     (--`!f:'a->'b. !s t. SURJ f s t = ((IMAGE f s) = t)`--),
     PURE_REWRITE_TAC [SURJ_DEF,EXTENSION,IN_IMAGE] THEN
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [REPEAT (STRIP_TAC ORELSE EQ_TAC) THENL
      [RES_TAC THEN ASM_REWRITE_TAC [],
       MAP_EVERY PURE_ONCE_REWRITE_TAC [[CONJ_SYM],[EQ_SYM_EQ]] THEN
       FIRST_ASSUM MATCH_MP_TAC THEN FIRST_ASSUM ACCEPT_TAC],
      DISCH_THEN (ASSUME_TAC o CONV_RULE (ONCE_DEPTH_CONV SYM_CONV)) THEN
      ASM_REWRITE_TAC [] THEN REPEAT STRIP_TAC THENL
      [EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC [],
       EXISTS_TAC (--`x':'a`--) THEN ASM_REWRITE_TAC []]]);

(* ===================================================================== *)
(* Bijective functions on a set.					 *)
(* ===================================================================== *)

val BIJ_DEF =
    new_definition
    ("BIJ_DEF",
     (--`BIJ (f:'a->'b) s t = INJ f s t /\ SURJ f s t`--));

val BIJ_ID =
    store_thm
    ("BIJ_ID",
     (--`!s. BIJ (\x:'a.x) s s`--),
     REWRITE_TAC [BIJ_DEF,INJ_ID,SURJ_ID]);

val BIJ_EMPTY = store_thm("BIJ_EMPTY",
(--`!f:'a->'b. (!s. BIJ f {} s = (s = {})) /\ (!s. BIJ f s {} = (s = {}))`--),
     REWRITE_TAC [BIJ_DEF,INJ_EMPTY,SURJ_EMPTY]);

val BIJ_COMPOSE =
    store_thm
    ("BIJ_COMPOSE",
     (--`!f:'a->'b. !g:'b->'c.
      !s t u. (BIJ f s t  /\ BIJ g t u) ==> BIJ (g o f) s u`--),
     PURE_REWRITE_TAC [BIJ_DEF] THEN
     REPEAT STRIP_TAC THENL
     [IMP_RES_TAC INJ_COMPOSE,IMP_RES_TAC SURJ_COMPOSE]);

(* ===================================================================== *)
(* Left and right inverses.						 *)
(* ===================================================================== *)

val lemma1 = TAC_PROOF(([],
(--`!(f:'a->'b) s.
      (!x y. x IN s /\ y IN s ==> (f x = f y) ==> (x = y)) =
      (!y. y IN s ==> !x.((x IN s /\ (f x = f y))=(y IN s /\ (x = y))))`--)),
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN
     RES_TAC THEN ASM_REWRITE_TAC []);

val lemma2 = TAC_PROOF (([],
(--`!f:'a->'b. !s. ?g. !t. INJ f s t ==> !x:'a. x IN s ==> (g(f x) = x)`--)),
     REPEAT GEN_TAC THEN PURE_REWRITE_TAC [INJ_DEF,lemma1] THEN
     EXISTS_TAC (--`\y:'b. @x:'a. x IN s /\ (f x = y)`--) THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT STRIP_TAC THEN (RES_THEN (fn th => REWRITE_TAC [th])) THEN
     ASM_REWRITE_TAC [] THEN CONV_TAC SELECT_CONV THEN
     EXISTS_TAC (--`x:'a`--) THEN REFL_TAC);

(* --------------------------------------------------------------------- *)
(* LINV_DEF:								 *)
(*   |- !f s t. INJ f s t ==> (!x. x IN s ==> (LINV f s(f x) = x))	 *)
(* --------------------------------------------------------------------- *)

val LINV_DEF =
   let val th1 = CONV_RULE (ONCE_DEPTH_CONV RIGHT_IMP_EXISTS_CONV) lemma2
       val th2 = CONV_RULE SKOLEM_CONV th1
   in new_specification{name="LINV_DEF",sat_thm=th2,
                        consts=[{const_name="LINV",fixity=Prefix}]}
   end;

val lemma3 = TAC_PROOF(([],
(--`!f:'a->'b. !s. ?g. !t. SURJ f s t ==> !x:'b. x IN t ==> (f(g x) = x)`--)),
     REPEAT GEN_TAC THEN PURE_REWRITE_TAC [SURJ_DEF] THEN
     EXISTS_TAC (--`\y:'b. @x:'a. x IN s /\ (f x = y)`--) THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     REPEAT STRIP_TAC THEN
     (fn (A,g) =>
       let val tm = mk_conj(Term`^(rand(lhs g)) IN s`, g)
       in SUBGOAL_THEN tm (fn th => ACCEPT_TAC(CONJUNCT2 th))(A,g)
       end)
     THEN CONV_TAC SELECT_CONV THEN
     FIRST_ASSUM MATCH_MP_TAC THEN
     FIRST_ASSUM ACCEPT_TAC);

(* --------------------------------------------------------------------- *)
(* RINV_DEF:								 *)
(*   |- !f s t. SURJ f s t ==> (!x. x IN t ==> (f(RINV f s x) = x))      *)
(* --------------------------------------------------------------------- *)

val RINV_DEF =
    let val th1 = CONV_RULE (ONCE_DEPTH_CONV RIGHT_IMP_EXISTS_CONV) lemma3
        val th2 = CONV_RULE SKOLEM_CONV th1
    in new_specification{name="RINV_DEF",sat_thm=th2,
                         consts=[{const_name="RINV",fixity=Prefix}]}
    end;

(* ===================================================================== *)
(* Finiteness								 *)
(* ===================================================================== *)

val FINITE_DEF =
 new_definition
 ("FINITE_DEF",
  (--`!s:'a set.
    FINITE s = !P. P EMPTY /\ (!s. P s ==> !e. P (e INSERT s)) ==> P s`--));

val FINITE_EMPTY =
    store_thm
    ("FINITE_EMPTY",
     (--`FINITE (EMPTY:'a set)`--),
     PURE_ONCE_REWRITE_TAC [FINITE_DEF] THEN
     REPEAT STRIP_TAC);

val FINITE_INSERT =
    TAC_PROOF
    (([], (--`!s. FINITE s ==> !x:'a. FINITE (x INSERT s)`--)),
     PURE_ONCE_REWRITE_TAC [FINITE_DEF] THEN
     REPEAT STRIP_TAC THEN SPEC_TAC ((--`x:'a`--),(--`x:'a`--)) THEN
     REPEAT (FIRST_ASSUM MATCH_MP_TAC) THEN
     CONJ_TAC THEN FIRST_ASSUM MATCH_ACCEPT_TAC);

val SIMPLE_FINITE_INDUCT =
    TAC_PROOF
    (([], (--`!P. P EMPTY /\ (!s. P s ==> (!e:'a. P(e INSERT s)))
                ==>
               !s. FINITE s ==> P s`--)),
     GEN_TAC THEN STRIP_TAC THEN
     PURE_ONCE_REWRITE_TAC [FINITE_DEF] THEN
     GEN_TAC THEN DISCH_THEN MATCH_MP_TAC THEN
     ASM_REWRITE_TAC []);

val lemma =
  let val tac = ASM_CASES_TAC (--`P:bool`--) THEN ASM_REWRITE_TAC[]
      val lem = TAC_PROOF(([],(--`(P ==> P /\ Q) = (P ==> Q)`--)), tac)
      val th1 = SPEC (--`\s:'a set. FINITE s /\ P s`--)
                     SIMPLE_FINITE_INDUCT
  in REWRITE_RULE [lem,FINITE_EMPTY] (BETA_RULE th1)
  end;

val FINITE_INDUCT = store_thm("FINITE_INDUCT",
--`!P. P {} /\ (!s. FINITE s /\ P s ==> (!e. ~(e IN s) ==> P(e INSERT s)))
       ==> !s:'a set. FINITE s
                          ==> P s`--,
     GEN_TAC THEN STRIP_TAC THEN
     MATCH_MP_TAC lemma THEN
     ASM_REWRITE_TAC [] THEN
     REPEAT STRIP_TAC THENL
     [IMP_RES_THEN MATCH_ACCEPT_TAC FINITE_INSERT,
      ASM_CASES_TAC (--`(e:'a) IN s`--) THENL
      [IMP_RES_THEN SUBST1_TAC ABSORPTION, RES_TAC] THEN
      ASM_REWRITE_TAC []]);

(* --------------------------------------------------------------------- *)
(* Load the set induction tactic in...                                   *)
(* --------------------------------------------------------------------- *)

val SET_INDUCT_TAC = PSet_ind.SET_INDUCT_TAC FINITE_INDUCT;

val FINITE_DELETE =
    TAC_PROOF
    (([], --`!s. FINITE s ==> !x:'a. FINITE (s DELETE x)`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [EMPTY_DELETE,FINITE_EMPTY],
      PURE_ONCE_REWRITE_TAC [DELETE_INSERT] THEN
      REPEAT STRIP_TAC THEN
      COND_CASES_TAC THENL
      [FIRST_ASSUM MATCH_ACCEPT_TAC,
       FIRST_ASSUM (fn th => fn g => ASSUME_TAC (SPEC (--`x:'a`--) th) g) THEN
       IMP_RES_TAC FINITE_INSERT THEN
       FIRST_ASSUM MATCH_ACCEPT_TAC]]);

val INSERT_FINITE =
    TAC_PROOF
    (([], (--`!x:'a. !s. FINITE(x INSERT s) ==> FINITE s`--)),
     REPEAT GEN_TAC THEN ASM_CASES_TAC (--`(x:'a) IN s`--) THENL
     [IMP_RES_TAC ABSORPTION THEN ASM_REWRITE_TAC [],
      DISCH_THEN (MP_TAC o SPEC (--`x:'a`--) o  MATCH_MP FINITE_DELETE) THEN
      REWRITE_TAC [DELETE_INSERT] THEN
      IMP_RES_TAC DELETE_NON_ELEMENT THEN ASM_REWRITE_TAC[]]);

val FINITE_INSERT =
    store_thm
    ("FINITE_INSERT",
     (--`!x:'a. !s. FINITE(x INSERT s) = FINITE s`--),
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [MATCH_ACCEPT_TAC INSERT_FINITE,
      DISCH_THEN (MATCH_ACCEPT_TAC o MATCH_MP FINITE_INSERT)]);

val DELETE_FINITE =
    TAC_PROOF
    (([], (--`!x:'a. !s. FINITE (s DELETE x) ==> FINITE s`--)),
     REPEAT GEN_TAC THEN ASM_CASES_TAC (--`(x:'a) IN s`--) THEN
     DISCH_TAC THENL
     [IMP_RES_THEN (SUBST1_TAC o SYM) INSERT_DELETE THEN
      ASM_REWRITE_TAC [FINITE_INSERT],
      IMP_RES_THEN (SUBST1_TAC o SYM) DELETE_NON_ELEMENT THEN
      FIRST_ASSUM ACCEPT_TAC]);


val FINITE_DELETE =
    store_thm
    ("FINITE_DELETE",
     (--`!x:'a. !s. FINITE(s DELETE x) = FINITE s`--),
     REPEAT GEN_TAC THEN EQ_TAC THENL
     [MATCH_ACCEPT_TAC DELETE_FINITE,
      DISCH_THEN (MATCH_ACCEPT_TAC o MATCH_MP FINITE_DELETE)]);

open SingleStep simpLib boolSimps
val UNION_FINITE = prove(
  --`!s:'a set. FINITE s ==> !t. FINITE t ==> FINITE (s UNION t)`--,
  SET_INDUCT_TAC THENL [
    REWRITE_TAC [UNION_EMPTY],
    SET_INDUCT_TAC THENL [
      IMP_RES_TAC FINITE_INSERT THEN ASM_REWRITE_TAC [UNION_EMPTY],
      `(e INSERT s) UNION (e' INSERT s') =
          s UNION (e INSERT e' INSERT s')` by
         SIMP_TAC bool_ss [IN_UNION, EXTENSION, IN_INSERT, NOT_IN_EMPTY,
                           EQ_IMP_THM, FORALL_AND_THM, DISJ_IMP_THM] THEN
      ASM_SIMP_TAC bool_ss [FINITE_INSERT, FINITE_EMPTY]
    ]
  ]);

val FINITE_UNION_LEMMA = TAC_PROOF(([],
--`!s:'a set. FINITE s ==> !t. FINITE (s UNION t) ==> FINITE t`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [UNION_EMPTY],
      GEN_TAC THEN ASM_REWRITE_TAC [INSERT_UNION] THEN
      COND_CASES_TAC THENL
      [FIRST_ASSUM MATCH_ACCEPT_TAC,
       DISCH_THEN (MP_TAC o MATCH_MP INSERT_FINITE) THEN
       FIRST_ASSUM MATCH_ACCEPT_TAC]]);

val FINITE_UNION = prove(
  --`!s:'a set. !t. FINITE(s UNION t) ==> (FINITE s /\ FINITE t)`--,
  REPEAT STRIP_TAC THEN IMP_RES_THEN MATCH_MP_TAC FINITE_UNION_LEMMA THEN
  PROVE_TAC [UNION_COMM, UNION_ASSOC, UNION_IDEMPOT]);

val FINITE_UNION =
    store_thm
    ("FINITE_UNION",
     (--`!s:'a set. !t. FINITE(s UNION t) = FINITE s /\ FINITE t`--),
     REPEAT STRIP_TAC THEN EQ_TAC THENL
     [REPEAT STRIP_TAC THEN IMP_RES_TAC FINITE_UNION,
      REPEAT STRIP_TAC THEN IMP_RES_TAC UNION_FINITE]);

val INTER_FINITE =
    store_thm
    ("INTER_FINITE",
     (--`!s:'a set. FINITE s ==> !t. FINITE (s INTER t)`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [INTER_EMPTY,FINITE_EMPTY],
      REWRITE_TAC [INSERT_INTER] THEN GEN_TAC THEN
      COND_CASES_TAC THENL
      [FIRST_ASSUM (fn th => fn g => ASSUME_TAC (SPEC (--`t:'a set`--) th) g
                                     handle _ => NO_TAC g) THEN
       IMP_RES_TAC FINITE_INSERT THEN
       FIRST_ASSUM MATCH_ACCEPT_TAC,
       FIRST_ASSUM MATCH_ACCEPT_TAC]]);

val SUBSET_FINITE =
    store_thm
    ("SUBSET_FINITE",
     (--`!s:'a set. FINITE s ==> (!t. t SUBSET s ==> FINITE t)`--),
     SET_INDUCT_TAC THENL
     [PURE_ONCE_REWRITE_TAC [SUBSET_EMPTY] THEN
      REPEAT STRIP_TAC THEN ASM_REWRITE_TAC [FINITE_EMPTY],
      GEN_TAC THEN ASM_CASES_TAC (--`(e:'a) IN t`--) THENL
      [REWRITE_TAC [SUBSET_INSERT_DELETE] THEN
       STRIP_TAC THEN RES_TAC THEN IMP_RES_TAC DELETE_FINITE,
       IMP_RES_TAC SUBSET_INSERT THEN ASM_REWRITE_TAC []]]);

val PSUBSET_FINITE =
    store_thm
    ("PSUBSET_FINITE",
     (--`!s:'a set. FINITE s ==> (!t. t PSUBSET s ==> FINITE t)`--),
     PURE_ONCE_REWRITE_TAC [PSUBSET_DEF] THEN
     REPEAT STRIP_TAC THEN IMP_RES_TAC SUBSET_FINITE);

val FINITE_DIFF =
    store_thm
    ("FINITE_DIFF",
     (--`!s:'a set. FINITE s ==> !t. FINITE(s DIFF t)`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [EMPTY_DIFF,FINITE_EMPTY],
      ASM_REWRITE_TAC [INSERT_DIFF] THEN
      GEN_TAC THEN COND_CASES_TAC THENL
      [FIRST_ASSUM MATCH_ACCEPT_TAC,
       FIRST_ASSUM (fn th => fn g => ASSUME_TAC (SPEC (--`t:'a set`--)th) g)
       THEN IMP_RES_THEN MATCH_ACCEPT_TAC FINITE_INSERT]]);

val FINITE_SING =
    store_thm
    ("FINITE_SING",
     (--`!x:'a. FINITE {x}`--),
     GEN_TAC THEN MP_TAC FINITE_EMPTY THEN
     SUBST1_TAC (SYM (SPEC (--`x:'a`--) SING_DELETE)) THEN
     DISCH_TAC THEN IMP_RES_THEN MATCH_ACCEPT_TAC FINITE_INSERT);

val SING_FINITE =
    store_thm
    ("SING_FINITE",
     (--`!s:'a set. SING s ==> FINITE s`--),
     PURE_ONCE_REWRITE_TAC [SING_DEF] THEN
     GEN_TAC THEN DISCH_THEN (STRIP_THM_THEN SUBST1_TAC) THEN
     MATCH_ACCEPT_TAC FINITE_SING);

val IMAGE_FINITE =
    store_thm
    ("IMAGE_FINITE",
     (--`!s. FINITE s ==> !f:'a->'b. FINITE(IMAGE f s)`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [IMAGE_EMPTY,FINITE_EMPTY],
      ASM_REWRITE_TAC [IMAGE_INSERT,FINITE_INSERT]]);

(* =====================================================================*)
(* Cardinality 								*)
(* =====================================================================*)

(* --------------------------------------------------------------------- *)
(* card_rel_def: defining equations for a relation `R s n`, which means  *)
(* that the finite s has cardinality n.				 	 *)
(* --------------------------------------------------------------------- *)

val card_rel_def =
    (--`(!s. R s 0 = (s = EMPTY)) /\
      (!s n. R s (SUC n) = ?x:'a. x IN s /\ R (s DELETE x) n)`--);

(* ---------------------------------------------------------------------*)
(* Prove that such a relation exists.					*)
(* ---------------------------------------------------------------------*)

val CARD_REL_EXISTS =  prove_rec_fn_exists num_Axiom card_rel_def;

(* ---------------------------------------------------------------------*)
(* Now, prove that it doesn't matter which element we delete		*)
(* Proof modified for Version 12 IMP_RES_THEN		 [TFM 91.01.23]	*)
(* ---------------------------------------------------------------------*)

val CARD_REL_DEL_LEMMA =
    TAC_PROOF
    ((strip_conj card_rel_def,
      (--`!(n:num) s (x:'a).
       x IN s ==>
       R (s DELETE x) n  ==>
      !y:'a. y IN s ==> R (s DELETE y) n`--)),
     INDUCT_TAC THENL
     [REPEAT GEN_TAC THEN DISCH_TAC THEN
      IMP_RES_TAC DELETE_EQ_SING THEN ASM_REWRITE_TAC [] THEN
      DISCH_THEN SUBST1_TAC THEN REWRITE_TAC [IN_SING] THEN
      GEN_TAC THEN DISCH_THEN SUBST1_TAC THEN REWRITE_TAC [SING_DELETE],
      ASM_REWRITE_TAC [] THEN REPEAT STRIP_TAC THEN
      let val th = (SPEC (--`y:'a = x'`--) EXCLUDED_MIDDLE)
      in DISJ_CASES_THEN2 SUBST_ALL_TAC ASSUME_TAC th
      end
      THENL
      [MP_TAC (SPECL [(--`s:'a set`--),(--`x:'a`--),(--`x':'a`--)]
                     IN_DELETE_EQ) THEN
       ASM_REWRITE_TAC [] THEN DISCH_TAC THEN
       PURE_ONCE_REWRITE_TAC [DELETE_COMM] THEN
       EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC[],
       let val th = (SPEC (--`x:'a = y`--) EXCLUDED_MIDDLE)
       in DISJ_CASES_THEN2 SUBST_ALL_TAC ASSUME_TAC th
       end
       THENL
       [EXISTS_TAC (--`x':'a`--) THEN ASM_REWRITE_TAC [],
        EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC [IN_DELETE] THEN
        RES_THEN (TRY o IMP_RES_THEN ASSUME_TAC) THEN
        PURE_ONCE_REWRITE_TAC [DELETE_COMM] THEN
	FIRST_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC [IN_DELETE] THEN
	CONV_TAC (ONCE_DEPTH_CONV SYM_CONV) THEN FIRST_ASSUM ACCEPT_TAC]]]);


(* --------------------------------------------------------------------- *)
(* So `R s` specifies a unique number.				         *)
(* --------------------------------------------------------------------- *)

val CARD_REL_UNIQUE =
    TAC_PROOF
    ((strip_conj card_rel_def,
      (--`!n:num. !s:'a set. R s n ==> (!m. R s m ==> (n = m))`--)),
     INDUCT_TAC THEN ASM_REWRITE_TAC [] THENL
     [GEN_TAC THEN STRIP_TAC THEN INDUCT_TAC THEN
      CONV_TAC (ONCE_DEPTH_CONV SYM_CONV) THENL
      [STRIP_TAC THEN REFL_TAC, ASM_REWRITE_TAC[NOT_SUC,NOT_IN_EMPTY]],
      GEN_TAC THEN STRIP_TAC THEN INDUCT_TAC THENL
      [ASM_REWRITE_TAC [NOT_SUC,SYM(SPEC_ALL MEMBER_NOT_EMPTY)] THEN
       EXISTS_TAC (--`x:'a`--) THEN FIRST_ASSUM ACCEPT_TAC,
       ASM_REWRITE_TAC [INV_SUC_EQ] THEN STRIP_TAC THEN
       IMP_RES_TAC CARD_REL_DEL_LEMMA THEN RES_TAC]]);

(* --------------------------------------------------------------------- *)
(* Now, ?n. R s n if s is finite.					*)
(* --------------------------------------------------------------------- *)

val CARD_REL_EXISTS_LEMMA = TAC_PROOF
((strip_conj card_rel_def,
 (--`!s:'a set. FINITE s ==> ?n:num. R s n`--)),
     SET_INDUCT_TAC THENL
     [EXISTS_TAC (--`0`--) THEN ASM_REWRITE_TAC[],
      FIRST_ASSUM (fn th => fn g => CHOOSE_THEN ASSUME_TAC th g) THEN
      EXISTS_TAC (--`SUC n`--) THEN ASM_REWRITE_TAC [] THEN
      EXISTS_TAC (--`e:'a`--) THEN IMP_RES_TAC DELETE_NON_ELEMENT THEN
      ASM_REWRITE_TAC [DELETE_INSERT,IN_INSERT]]);

(* ---------------------------------------------------------------------*)
(* So (@n. R s n) = m iff R s m        (\s.@n.R s n defines a function)	*)
(* Proof modified for Version 12 IMP_RES_THEN		 [TFM 91.01.23]	*)
(* ---------------------------------------------------------------------*)

val CARD_REL_THM =
    TAC_PROOF
    ((strip_conj card_rel_def,
     (--`!m s. FINITE s ==> (((@n:num. R (s:'a set) n) = m) = R s m)`--)),
     REPEAT STRIP_TAC THEN
     IMP_RES_TAC CARD_REL_EXISTS_LEMMA THEN
     EQ_TAC THENL
     [DISCH_THEN (SUBST1_TAC o SYM) THEN CONV_TAC SELECT_CONV THEN
      EXISTS_TAC (--`n:num`--) THEN FIRST_ASSUM MATCH_ACCEPT_TAC,
      STRIP_TAC THEN
      IMP_RES_THEN ASSUME_TAC CARD_REL_UNIQUE THEN
      CONV_TAC SYM_CONV THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      CONV_TAC SELECT_CONV THEN
      EXISTS_TAC (--`n:num`--) THEN FIRST_ASSUM MATCH_ACCEPT_TAC]);

(* ---------------------------------------------------------------------*)
(* Now, prove the existence of the required cardinality function.	*)
(* ---------------------------------------------------------------------*)

val CARD_EXISTS = TAC_PROOF(([],
(--` ?CARD.
       (CARD EMPTY = 0) /\
       (!s. FINITE s ==>
       !x:'a. CARD(x INSERT s) = (if x IN s then CARD s else SUC(CARD s)))`--)),
     STRIP_ASSUME_TAC CARD_REL_EXISTS THEN
     EXISTS_TAC (--`\s:'a set. @n:num. R s n`--) THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN CONJ_TAC THENL
     [ASSUME_TAC FINITE_EMPTY THEN IMP_RES_TAC CARD_REL_THM THEN
      FIRST_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC [],
      REPEAT STRIP_TAC THEN COND_CASES_TAC THENL
      [IMP_RES_THEN SUBST1_TAC ABSORPTION THEN REFL_TAC,
       IMP_RES_THEN (ASSUME_TAC o SPEC (--`x:'a`--)) FINITE_INSERT THEN
       IMP_RES_THEN (TRY o MATCH_MP_TAC) CARD_REL_THM THEN
       ASM_REWRITE_TAC [] THEN EXISTS_TAC (--`x:'a`--) THEN
       IMP_RES_TAC DELETE_NON_ELEMENT THEN
       ASM_REWRITE_TAC [IN_INSERT,DELETE_INSERT] THEN
       CONV_TAC SELECT_CONV THEN
       IMP_RES_THEN (TRY o MATCH_ACCEPT_TAC) CARD_REL_EXISTS_LEMMA]]);

(* ---------------------------------------------------------------------*)
(* Finally, introduce the CARD function via a constant specification.	*)
(* ---------------------------------------------------------------------*)

val CARD_DEF = new_specification
                 {name="CARD_DEF", sat_thm=CARD_EXISTS,
                  consts=[{const_name="CARD",fixity=Prefix}]};

(* ---------------------------------------------------------------------*)
(* Various cardinality results.						*)
(* ---------------------------------------------------------------------*)

val CARD_EMPTY = save_thm("CARD_EMPTY",CONJUNCT1 CARD_DEF);

val CARD_INSERT = save_thm("CARD_INSERT",CONJUNCT2 CARD_DEF);

val CARD_EQ_0 =
    store_thm
    ("CARD_EQ_0",
     (--`!s:'a set. FINITE s ==> ((CARD s = 0) = (s = EMPTY))`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [CARD_EMPTY],
      IMP_RES_TAC CARD_INSERT THEN
      ASM_REWRITE_TAC [NOT_INSERT_EMPTY,NOT_SUC]]);

val CARD_DELETE =
    store_thm
    ("CARD_DELETE",
     (--`!s. FINITE s ==>
          !x:'a. CARD(s DELETE x) = if x IN s then CARD s - 1 else CARD s`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [EMPTY_DELETE,NOT_IN_EMPTY],
      PURE_REWRITE_TAC [DELETE_INSERT,IN_INSERT] THEN
      REPEAT GEN_TAC THEN ASM_CASES_TAC (--`x:'a = e`--) THENL
      [IMP_RES_TAC CARD_DEF THEN ASM_REWRITE_TAC [SUC_SUB1],
       SUBST1_TAC (SPECL [(--`e:'a`--),(--`x:'a`--)] EQ_SYM_EQ) THEN
       IMP_RES_THEN (ASSUME_TAC o SPEC (--`x:'a`--)) FINITE_DELETE THEN
       IMP_RES_TAC CARD_DEF THEN ASM_REWRITE_TAC [IN_DELETE,SUC_SUB1] THEN
       COND_CASES_TAC THEN ASM_REWRITE_TAC [] THEN
       STRIP_ASSUME_TAC (SPEC (--`CARD(s:'a set)`--) num_CASES) THENL
       [let fun tac th g = SUBST_ALL_TAC th g handle _ => ASSUME_TAC th g
        in REPEAT_GTCL IMP_RES_THEN tac CARD_EQ_0
        end THEN IMP_RES_TAC NOT_IN_EMPTY,
	ASM_REWRITE_TAC [SUC_SUB1]]]]);


val lemma1 =
    TAC_PROOF
    (([], (--`!n m. (SUC n <= SUC m) = (n <= m)`--)),
     REWRITE_TAC [LESS_OR_EQ,INV_SUC_EQ,LESS_MONO_EQ]);

val lemma2 =
    TAC_PROOF
    (([], (--`!n m. (n <= SUC m) = (n <= m \/ (n = SUC m))`--)),
     REWRITE_TAC [LESS_OR_EQ,LESS_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN ASM_REWRITE_TAC[]);

val CARD_INTER_LESS_EQ =
    store_thm
    ("CARD_INTER_LESS_EQ",
     (--`!s:'a set. FINITE s ==> !t. CARD (s INTER t) <= CARD s`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [CARD_DEF,INTER_EMPTY,LESS_EQ_REFL],
      PURE_ONCE_REWRITE_TAC [INSERT_INTER] THEN
      GEN_TAC THEN COND_CASES_TAC THENL
      [IMP_RES_THEN (ASSUME_TAC o SPEC (--`t:'a set`--)) INTER_FINITE THEN
       IMP_RES_TAC CARD_DEF THEN ASM_REWRITE_TAC [IN_INTER,lemma1],
       IMP_RES_TAC CARD_DEF THEN ASM_REWRITE_TAC [lemma2]]]);

val CARD_UNION =
    store_thm
    ("CARD_UNION",
     (--`!s:'a set.
       FINITE s ==>
       !t. FINITE t ==>
           (CARD (s UNION t) + CARD (s INTER t) = CARD s + CARD t)`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [UNION_EMPTY,INTER_EMPTY,CARD_DEF,ADD_CLAUSES],
      REPEAT STRIP_TAC THEN REWRITE_TAC [INSERT_UNION,INSERT_INTER] THEN
      ASM_CASES_TAC (--`(e:'a) IN t`--) THENL
      [IMP_RES_THEN (ASSUME_TAC o SPEC (--`t:'a set`--)) INTER_FINITE THEN
       IMP_RES_TAC CARD_DEF THEN RES_TAC THEN
       ASM_REWRITE_TAC [IN_INTER,ADD_CLAUSES],
       IMP_RES_TAC UNION_FINITE THEN
       IMP_RES_TAC CARD_DEF THEN RES_TAC THEN
       ASM_REWRITE_TAC [ADD_CLAUSES, INV_SUC_EQ, IN_UNION]]]);

val lemma =
    TAC_PROOF
    (([], (--`!n m. (n <= SUC m) = (n <= m \/ (n = SUC m))`--)),
     REWRITE_TAC [LESS_OR_EQ,LESS_THM] THEN
     REPEAT (STRIP_TAC ORELSE EQ_TAC) THEN ASM_REWRITE_TAC[]);

val CARD_SUBSET =
    store_thm
    ("CARD_SUBSET",
     (--`!s:'a set.
         FINITE s ==> !t. t SUBSET s ==> CARD t <= CARD s`--),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [SUBSET_EMPTY,CARD_EMPTY] THEN
        GEN_TAC THEN DISCH_THEN SUBST1_TAC THEN
        REWRITE_TAC [CARD_DEF,LESS_EQ_REFL],
      IMP_RES_THEN (ASSUME_TAC o SPEC (--`e:'a`--)) FINITE_INSERT THEN
        IMP_RES_TAC CARD_INSERT THEN
        ASM_REWRITE_TAC [SUBSET_INSERT_DELETE] THEN
        REPEAT STRIP_TAC THEN RES_THEN MP_TAC THEN
        IMP_RES_TAC SUBSET_FINITE THEN
        IMP_RES_TAC DELETE_FINITE THEN
        IMP_RES_TAC CARD_DELETE THEN
        ASM_REWRITE_TAC [] THEN COND_CASES_TAC THENL
        [let val th = SPEC (--`CARD (t:'a set)`--) num_CASES
         in REPEAT_TCL STRIP_THM_THEN SUBST_ALL_TAC th
         end THENL
          [REWRITE_TAC [LESS_OR_EQ,LESS_0],
           REWRITE_TAC [SUC_SUB1,LESS_OR_EQ,LESS_MONO_EQ,INV_SUC_EQ]],
        STRIP_TAC THEN ASM_REWRITE_TAC [lemma]]]);

val CARD_PSUBSET =
    store_thm
    ("CARD_PSUBSET",
     (--`!s:'a set.
         FINITE s ==> !t. t PSUBSET s ==> CARD t < CARD s`--),
     REPEAT STRIP_TAC THEN IMP_RES_TAC PSUBSET_DEF THEN
     IMP_RES_THEN (IMP_RES_THEN MP_TAC) CARD_SUBSET THEN
     PURE_ONCE_REWRITE_TAC [LESS_OR_EQ] THEN
     DISCH_THEN (STRIP_THM_THEN
       (fn th => fn g => ACCEPT_TAC th g handle _ => MP_TAC th g)) THEN
     IMP_RES_THEN STRIP_ASSUME_TAC PSUBSET_INSERT_SUBSET THEN
     IMP_RES_THEN (IMP_RES_THEN MP_TAC) CARD_SUBSET THEN
     IMP_RES_TAC INSERT_SUBSET THEN
     IMP_RES_TAC SUBSET_FINITE THEN
     IMP_RES_TAC CARD_INSERT THEN
     ASM_REWRITE_TAC [LESS_EQ] THEN
     REPEAT STRIP_TAC THEN FIRST_ASSUM ACCEPT_TAC);

val CARD_SING =
    store_thm
    ("CARD_SING",
     (--`!x:'a. CARD {x} = 1`--),
     CONV_TAC (ONCE_DEPTH_CONV num_CONV) THEN
     GEN_TAC THEN ASSUME_TAC FINITE_EMPTY THEN
     IMP_RES_THEN (ASSUME_TAC o SPEC (--`x:'a`--)) FINITE_INSERT THEN
     IMP_RES_TAC CARD_DEF THEN ASM_REWRITE_TAC [NOT_IN_EMPTY,CARD_DEF]);

val SING_IFF_CARD1 =
    store_thm
    ("SING_IFF_CARD1",
     (--`!s:'a set. SING s = (CARD s = 1) /\ FINITE s`--),
     REWRITE_TAC [SING_DEF,ONE] THEN
     GEN_TAC THEN EQ_TAC THENL
     [DISCH_THEN (CHOOSE_THEN SUBST1_TAC) THEN
      CONJ_TAC THENL
      [ASSUME_TAC FINITE_EMPTY THEN
       IMP_RES_TAC CARD_INSERT THEN
       ASM_REWRITE_TAC [CARD_EMPTY,NOT_IN_EMPTY],
       REWRITE_TAC [FINITE_INSERT,FINITE_EMPTY]],
      STRIP_ASSUME_TAC (SPEC (--`s:'a set`--) SET_CASES) THENL
      [ASM_REWRITE_TAC [CARD_EMPTY,NOT_EQ_SYM(SPEC_ALL NOT_SUC)],
       ASM_REWRITE_TAC [FINITE_INSERT] THEN
       DISCH_THEN (CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
       IMP_RES_TAC CARD_INSERT THEN
       IMP_RES_TAC CARD_EQ_0 THEN
       ASM_REWRITE_TAC [INV_SUC_EQ] THEN
       DISCH_TAC THEN EXISTS_TAC (--`x:'a`--) THEN
       ASM_REWRITE_TAC []]]);

(* ---------------------------------------------------------------------*)
(* A theorem from homeier@aero.uniblab (Peter Homeier)      		*)
(* ---------------------------------------------------------------------*)
val CARD_DIFF =
    store_thm
    ("CARD_DIFF",
     (--`!t:'a set.
          FINITE t ==>
          !s:'a set. FINITE s ==>
                       (CARD (s DIFF t) = (CARD s - CARD (s INTER t)))`--),
     SET_INDUCT_TAC THEN REPEAT STRIP_TAC THENL
     [REWRITE_TAC [DIFF_EMPTY,INTER_EMPTY,CARD_EMPTY,SUB_0],
      PURE_ONCE_REWRITE_TAC [INTER_COMM] THEN
      PURE_ONCE_REWRITE_TAC [INSERT_INTER] THEN
      COND_CASES_TAC THENL
      [let val th = SPEC (--`s':'a set`--)
                         (UNDISCH (SPEC (--`s:'a set`--) INTER_FINITE))
       in PURE_ONCE_REWRITE_TAC [MATCH_MP CARD_INSERT th]
       end THEN
       IMP_RES_THEN (ASSUME_TAC o SPEC (--`e:'a`--)) FINITE_DELETE THEN
       IMP_RES_TAC CARD_DELETE THEN
       RES_TAC THEN ASM_REWRITE_TAC [IN_INTER,DIFF_INSERT] THEN
       PURE_ONCE_REWRITE_TAC [SYM (SPEC_ALL SUB_PLUS)] THEN
       REWRITE_TAC [ONE,ADD_CLAUSES,DELETE_INTER] THEN
       MP_TAC (SPECL [(--`s':'a set`--),(--`s:'a set`--),(--`e:'a`--)]
                     IN_INTER) THEN
       ASM_REWRITE_TAC [DELETE_NON_ELEMENT] THEN
       DISCH_THEN SUBST1_TAC THEN
       SUBST1_TAC (SPECL [(--`s:'a set`--),(--`s':'a set`--)] INTER_COMM)
       THEN REFL_TAC,
       IMP_RES_TAC DELETE_NON_ELEMENT THEN
       PURE_ONCE_REWRITE_TAC [INTER_COMM] THEN
       RES_TAC THEN ASM_REWRITE_TAC [DIFF_INSERT]]]);

(* ---------------------------------------------------------------------*)
(* A theorem from homeier@aero.uniblab (Peter Homeier)	        	*)
(* ---------------------------------------------------------------------*)
val LESS_CARD_DIFF =
    store_thm
    ("LESS_CARD_DIFF",
     (--`!t:'a set. FINITE t ==>
      !s. FINITE s ==> (CARD t < CARD s) ==> (0 < CARD(s DIFF t))`--),
     REPEAT STRIP_TAC THEN
     REPEAT_GTCL IMP_RES_THEN SUBST1_TAC CARD_DIFF THEN
     PURE_REWRITE_TAC [GSYM SUB_LESS_0] THEN
     let val th1 = UNDISCH (SPEC (--`s:'a set`--) CARD_INTER_LESS_EQ)
         val th2 = SPEC (--`t:'a set`--)
                        (PURE_ONCE_REWRITE_RULE [LESS_OR_EQ] th1)
     in DISJ_CASES_THEN2 ACCEPT_TAC (SUBST_ALL_TAC o SYM) th2
     end THEN
     let val th3 = SPEC (--`s:'a set`--)
                        (UNDISCH(SPEC(--`t:'a set`--) CARD_INTER_LESS_EQ))
         val th4 = PURE_ONCE_REWRITE_RULE [INTER_COMM] th3
     in
     IMP_RES_TAC (PURE_ONCE_REWRITE_RULE [GSYM NOT_LESS] th4)
     end);

val FINITE_COMPLETE_INDUCTION = store_thm(
  "FINITE_COMPLETE_INDUCTION",
  Term`!P.
          (!x. (!y. y PSUBSET x ==> P y) ==> FINITE x ==> P x) ==>
          !x. FINITE x ==> P x`,
  GEN_TAC THEN STRIP_TAC THEN
  MATCH_MP_TAC ((BETA_RULE o
                 Q.ISPEC `\x. FINITE x ==> P x` o
                 REWRITE_RULE [prim_recTheory.WF_measure] o
                 Q.ISPEC `measure CARD`)
                relationTheory.WF_INDUCTION_THM) THEN
  REPEAT STRIP_TAC THEN
  RULE_ASSUM_TAC (REWRITE_RULE [AND_IMP_INTRO]) THEN
  Q.PAT_ASSUM `!x. (!y. y PSUBSET x ==> P y) /\ FINITE x ==>
                   P x` MATCH_MP_TAC THEN
  ASM_REWRITE_TAC [] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN
  ASM_REWRITE_TAC [prim_recTheory.measure_def,
                   relationTheory.inv_image_def] THEN
  BETA_TAC THEN mesonLib.ASM_MESON_TAC [PSUBSET_FINITE, CARD_PSUBSET]);

(* =====================================================================*)
(* Infiniteness								*)
(* =====================================================================*)

val INFINITE_DEF = new_definition ("INFINITE_DEF",
(--`!s:'a set. INFINITE s = ~FINITE s`--));

val NOT_IN_FINITE =
    store_thm
    ("NOT_IN_FINITE",
     (--`INFINITE (UNIV:'a set)
           =
         !s:'a set. FINITE s ==> ?x. ~(x IN s)`--),
     PURE_ONCE_REWRITE_TAC [INFINITE_DEF] THEN EQ_TAC THENL
     [CONV_TAC CONTRAPOS_CONV THEN
      CONV_TAC (ONCE_DEPTH_CONV NOT_FORALL_CONV) THEN
      REWRITE_TAC [NOT_IMP] THEN
      CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
      REWRITE_TAC [EQ_UNIV] THEN
      CONV_TAC (ONCE_DEPTH_CONV SYM_CONV) THEN
      REPEAT STRIP_TAC THEN ASM_REWRITE_TAC [],
      REPEAT STRIP_TAC THEN RES_THEN STRIP_ASSUME_TAC THEN
      ASSUME_TAC (SPEC (--`x:'a`--) IN_UNIV) THEN RES_TAC]);

val INFINITE_INHAB = store_thm(
  "INFINITE_INHAB",
  Term`!P. INFINITE P ==> ?x. x IN P`,
  REWRITE_TAC [MEMBER_NOT_EMPTY, INFINITE_DEF] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM SUBST_ALL_TAC THEN POP_ASSUM MP_TAC THEN
  REWRITE_TAC [FINITE_EMPTY]);

val INVERSE_LEMMA =
    TAC_PROOF
    (([], (--`!f:'a->'b. (!x y. (f x = f y) ==> (x = y)) ==>
                     ((\x:'b. @y:'a. x = f y) o f = \x:'a.x)`--)),
     REPEAT STRIP_TAC THEN CONV_TAC FUN_EQ_CONV THEN
     PURE_ONCE_REWRITE_TAC [o_THM] THEN
     CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN
     GEN_TAC THEN FIRST_ASSUM MATCH_MP_TAC THEN
     CONV_TAC (SYM_CONV THENC SELECT_CONV) THEN
     EXISTS_TAC (--`x:'a`--) THEN REFL_TAC);

val IMAGE_11_INFINITE =
    store_thm
    ("IMAGE_11_INFINITE",
     (--`!f:'a->'b. (!x y. (f x = f y) ==> (x = y)) ==>
      !s:'a set. INFINITE s ==> INFINITE (IMAGE f s)`--),
     GEN_TAC THEN STRIP_TAC THEN GEN_TAC THEN
     CONV_TAC CONTRAPOS_CONV THEN
     REWRITE_TAC [INFINITE_DEF] THEN STRIP_TAC THEN
     let val alpha = Type`:'a` and beta = Type`:'b`
         val thm = INST_TYPE [beta |-> alpha, alpha |-> beta] IMAGE_FINITE
     in IMP_RES_THEN (MP_TAC o ISPEC (--`\x:'b. @y:'a. x = f y`--)) thm
     end THEN
     REWRITE_TAC [SYM(SPEC_ALL IMAGE_COMPOSE)] THEN
     IMP_RES_TAC INVERSE_LEMMA THEN
     ASM_REWRITE_TAC [IMAGE_ID]);

val INFINITE_SUBSET =
    store_thm
    ("INFINITE_SUBSET",
     (--`!s:'a set. INFINITE s ==> (!t. s SUBSET t ==> INFINITE t)`--),
     PURE_ONCE_REWRITE_TAC [INFINITE_DEF] THEN
     REPEAT STRIP_TAC THEN IMP_RES_TAC SUBSET_FINITE THEN RES_TAC);

val IN_INFINITE_NOT_FINITE =
    store_thm
    ("IN_INFINITE_NOT_FINITE",
     (--`!s t. (INFINITE s /\ FINITE t) ==> ?x:'a. x IN s /\ ~(x IN t)`--),
     CONV_TAC (ONCE_DEPTH_CONV CONTRAPOS_CONV) THEN
     CONV_TAC (ONCE_DEPTH_CONV NOT_EXISTS_CONV) THEN
     PURE_ONCE_REWRITE_TAC [DE_MORGAN_THM] THEN
     REWRITE_TAC [SYM(SPEC_ALL IMP_DISJ_THM)] THEN
     PURE_ONCE_REWRITE_TAC [SYM(SPEC_ALL SUBSET_DEF)] THEN
     PURE_ONCE_REWRITE_TAC [SYM(SPEC_ALL INFINITE_DEF)] THEN
     REPEAT STRIP_TAC THEN IMP_RES_TAC INFINITE_SUBSET);

(* ---------------------------------------------------------------------- *)
(* The next series of lemmas are used for proving that if UNIV: set       *)
(* is INFINITE then :'a satisfies an axiom of infinity.			  *)
(*									  *)
(* The function g:num->'a set defines a series of sets:		          *)
(*									  *)
(*    {}, {x1}, {x1,x2}, {x1,x2,x3},...					  *)
(*									  *)
(* and one then defines an f:'a->'a such that f(xi)=xi+1.		  *)
(* ---------------------------------------------------------------------- *)

(* ---------------------------------------------------------------------*)
(* Defining equations for g 				                *)
(* ---------------------------------------------------------------------*)

val gdef = map Term
    [    `g  0      = ({}:'a set)`,
     `!n. g (SUC n) = (@x:'a.~(x IN (g n))) INSERT (g n)`];

(* ---------------------------------------------------------------------*)
(* Lemma: g n is finite for all n.					*)
(* ---------------------------------------------------------------------*)

val g_finite =
    TAC_PROOF
    ((gdef, (--`!n:num. FINITE (g n:'a set)`--)),
     INDUCT_TAC THEN ASM_REWRITE_TAC[FINITE_EMPTY,FINITE_INSERT]);

(* ---------------------------------------------------------------------*)
(* Lemma: g n is contained in g (n+i) for all i.			*)
(* ---------------------------------------------------------------------*)

val g_subset =
    TAC_PROOF
    ((gdef, (--`!n. !x:'a. x IN (g n) ==> !i. x IN (g (n+i))`--)),
     REPEAT GEN_TAC THEN DISCH_TAC THEN INDUCT_TAC THEN
     ASM_REWRITE_TAC [ADD_CLAUSES,IN_INSERT]);

(* ---------------------------------------------------------------------*)
(* Lemma: if x is in g(n) then {x} = g(n+1)-g(n) for some n.		*)
(* ---------------------------------------------------------------------*)

val lemma =
    TAC_PROOF(([], (--`((A \/ B) /\ ~B) = (A /\ ~B)`--)),
              BOOL_CASES_TAC (--`B:bool`--) THEN REWRITE_TAC[]);

val g_cases =
    TAC_PROOF
    ((gdef, (--`(!s. FINITE s ==> ?x:'a. ~(x IN s)) ==>
    	      !x:'a. (?n. x IN (g n)) ==>
	            (?m. (x IN (g (SUC m))) /\ ~(x IN (g m)))`--)),
     DISCH_TAC THEN GEN_TAC THEN
     DISCH_THEN (STRIP_THM_THEN MP_TAC o
                 CONV_RULE numLib.EXISTS_LEAST_CONV) THEN
     REPEAT_TCL STRIP_THM_THEN SUBST1_TAC (SPEC (--`n:num`--) num_CASES) THEN
     ASM_REWRITE_TAC [NOT_IN_EMPTY,IN_INSERT] THEN STRIP_TAC THENL
     [REWRITE_TAC [lemma] THEN EXISTS_TAC (--`n':num`--) THEN
      CONJ_TAC THEN TRY(FIRST_ASSUM ACCEPT_TAC) THEN
      FIRST_ASSUM (fn th => fn g => SUBST1_TAC th g) THEN
      CONV_TAC SELECT_CONV THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      MATCH_ACCEPT_TAC g_finite,
      REWRITE_TAC [lemma] THEN
      FIRST_ASSUM (fn th => fn g => MP_TAC (SPEC (--`n':num`--) th) g) THEN
      REWRITE_TAC [LESS_SUC_REFL] THEN
      DISCH_THEN IMP_RES_TAC]);

(* ---------------------------------------------------------------------*)
(* Lemma: @x.~(x IN {}) is an element of every g(n+1).			*)
(* ---------------------------------------------------------------------*)

val z_in_g1 =
    TAC_PROOF
    ((gdef, (--`(@x:'a.~(x IN {})) IN (g (SUC 0))`--)),
     ASM_REWRITE_TAC [NOT_IN_EMPTY,IN_INSERT]);

val z_in_gn =
    TAC_PROOF
    ((gdef, (--`!n:num. (@x:'a. ~(x IN {})) IN (g (SUC n))`--)),
     PURE_ONCE_REWRITE_TAC [ADD1] THEN
     PURE_ONCE_REWRITE_TAC [ADD_SYM] THEN
     MATCH_MP_TAC g_subset THEN
     REWRITE_TAC [num_CONV (--`1`--),z_in_g1]);

(* ---------------------------------------------------------------------*)
(* Lemma: @x. ~(x IN g n) is an element of g(n+1).			*)
(* ---------------------------------------------------------------------*)

val in_lemma =
    TAC_PROOF
    ((gdef, (--`!n:num. (@x:'a. ~(x IN (g n))) IN (g(SUC n))`--)),
     ASM_REWRITE_TAC [IN_INSERT]);

(* ---------------------------------------------------------------------*)
(* Lemma: the x added to g(n+1) is not in g(n)				*)
(* ---------------------------------------------------------------------*)

val not_in_lemma =
    TAC_PROOF
    ((gdef, (--`(!s. FINITE s ==>
                     ?x:'a. ~(x IN s)) ==>
	             !i n. ~((@x:'a. ~(x IN (g (n+i)))) IN g n)`--)),
     DISCH_TAC THEN INDUCT_TAC THENL
     [ASM_REWRITE_TAC [ADD_CLAUSES] THEN
      GEN_TAC THEN CONV_TAC SELECT_CONV THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      MATCH_ACCEPT_TAC g_finite,
      PURE_ONCE_REWRITE_TAC [ADD_CLAUSES] THEN
      PURE_ONCE_REWRITE_TAC [SYM(el 3 (CONJUNCTS ADD_CLAUSES))] THEN
      GEN_TAC THEN FIRST_ASSUM (fn th => fn g =>
                                  MP_TAC(SPEC (--`SUC n`--) th) g) THEN
      REWRITE_TAC (map ASSUME gdef) THEN
      REWRITE_TAC [IN_INSERT,DE_MORGAN_THM] THEN
      REPEAT STRIP_TAC THEN RES_TAC]);

(* ---------------------------------------------------------------------*)
(* Lemma: each value is added to a unique g(n).				*)
(* ---------------------------------------------------------------------*)

val less_lemma =
    TAC_PROOF
    (([], (--`!m n. ~(m = n) = ((m < n) \/ (n < m))`--)),
      REPEAT GEN_TAC THEN ASM_CASES_TAC (--`n < m`--) THEN
      ASM_REWRITE_TAC [] THENL
      [DISCH_THEN SUBST_ALL_TAC THEN IMP_RES_TAC LESS_REFL,
       IMP_RES_THEN MP_TAC NOT_LESS THEN
       REWRITE_TAC [LESS_OR_EQ] THEN STRIP_TAC THEN
       ASM_REWRITE_TAC[] THENL
       [IMP_RES_TAC LESS_NOT_EQ, MATCH_ACCEPT_TAC LESS_REFL]]);

val gn_unique = TAC_PROOF
((gdef,
 (--`(!s. FINITE s ==>
        ?x:'a. ~(x IN s)) ==>
        !(n:num) m. ((@x:'a.~(x IN (g n))) = @x:'a.~(x IN (g m))) = (n=m)`--)),
     DISCH_TAC THEN REPEAT GEN_TAC THEN EQ_TAC THENL
     [CONV_TAC CONTRAPOS_CONV THEN
      REWRITE_TAC [less_lemma] THEN
      DISCH_THEN (STRIP_THM_THEN MP_TAC) THEN
      DISCH_THEN (STRIP_THM_THEN SUBST1_TAC o MATCH_MP LESS_ADD_1) THEN
      REWRITE_TAC [num_CONV (--`1`--),ADD_CLAUSES] THEN
      REWRITE_TAC [SYM(el 3 (CONJUNCTS ADD_CLAUSES))] THEN
      IMP_RES_TAC not_in_lemma THEN
      DISCH_TAC THENL
      [MP_TAC (SPEC (--`n:num`--) in_lemma) THEN
       EVERY_ASSUM (fn th => fn g => SUBST1_TAC th g handle _ => ALL_TAC g)
       THEN DISCH_TAC THEN RES_TAC,
       MP_TAC (SPEC (--`m:num`--) in_lemma) THEN
       EVERY_ASSUM (fn th=>fn g => SUBST1_TAC (SYM th) g handle _ => ALL_TAC g)
       THEN DISCH_TAC THEN RES_TAC],
      DISCH_THEN SUBST1_TAC THEN REFL_TAC]);

(* ---------------------------------------------------------------------*)
(* Lemma: the value added to g(n) to get g(n+1) is unique.		*)
(* ---------------------------------------------------------------------*)

val x_unique =
    TAC_PROOF
    ((gdef, (--`!n. !x. !y:'a.
	       (~(x IN g n) /\ ~(y IN g n))
                ==> (x IN g(SUC n))
                ==> (y IN g(SUC n))
                ==> (x = y)`--)),
     REPEAT GEN_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC [IN_INSERT] THEN
     REPEAT (DISCH_THEN SUBST1_TAC) THEN REFL_TAC);

(* ---------------------------------------------------------------------*)
(* Now, show the existence of a non-onto one-one fuction.  The required	*)
(* function is denoted by fdef.  The theorem cases is:			*)
(*									*)
(*   |- (?n. x IN (g n)) \/ (!n. ~x IN (g n))				*)
(*									*)
(* and is used to do case splits on the condition of the conditional 	*)
(* present in fdef.							*)
(* ---------------------------------------------------------------------*)

val fdef = Term
   `\x:'a. if (?n. x IN (g n))
           then (@y. ~(y IN (g (SUC @n. x IN g(SUC n) /\ ~(x IN (g n))))))
           else  x`;

val cases =
   let val thm = GEN (--`x:'a`--)
                     (SPEC (--`?n:num.(x:'a) IN (g n)`--) EXCLUDED_MIDDLE)
   in CONV_RULE (ONCE_DEPTH_CONV NOT_EXISTS_CONV) thm
   end;


val INF_IMP_INFINITY = TAC_PROOF(([],
--`(!s. FINITE s ==> ?x:'a. ~(x IN s)) ==>
   ?f:'a->'a.
       (!x y. (f x = f y) ==> (x=y)) /\
       ?y. !x. ~(f x = y)`--),
 let val xcases = SPEC (--`x:'a`--) cases
     and ycases = SPEC (--`y:'a`--) cases
     fun nv x = (--`SUC(@n. ^x IN (g(SUC n)) /\ ~(^x IN (g n)))`--)
 in
 STRIP_ASSUME_TAC (prove_rec_fn_exists num_Axiom (list_mk_conj gdef)) THEN
 STRIP_TAC THEN EXISTS_TAC fdef THEN
 CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN CONJ_TAC THENL
 [REPEAT GEN_TAC THEN
  DISJ_CASES_THEN (fn th => REWRITE_TAC[th] THEN STRIP_ASSUME_TAC th) xcases
  THEN
  DISJ_CASES_THEN (fn th => REWRITE_TAC[th] THEN STRIP_ASSUME_TAC th) ycases
  THENL
  [REWRITE_TAC [UNDISCH gn_unique,INV_SUC_EQ] THEN
   IMP_RES_THEN (IMP_RES_THEN(STRIP_ASSUME_TAC o SELECT_RULE)) g_cases THEN
   DISCH_THEN SUBST_ALL_TAC THEN IMP_RES_TAC x_unique,
   ASSUME_TAC (SPEC (nv (--`x:'a`--)) in_lemma) THEN
   DISCH_THEN (SUBST_ALL_TAC o SYM) THEN RES_TAC,
   ASSUME_TAC (SPEC (nv (--`y:'a`--)) in_lemma) THEN
   DISCH_THEN SUBST_ALL_TAC THEN RES_TAC],
   EXISTS_TAC (--`@x:'a.~(x IN g 0)`--) THEN GEN_TAC THEN
   DISJ_CASES_THEN (fn th => REWRITE_TAC[th] THEN ASSUME_TAC th) xcases
   THENL
   [REWRITE_TAC [UNDISCH gn_unique,NOT_SUC],
    ASSUME_TAC (SPEC (--`n:num`--) z_in_gn) THEN
    FIRST_ASSUM (fn th => fn g => SUBST1_TAC th g) THEN
    DISCH_THEN SUBST_ALL_TAC THEN RES_TAC]]
  end);

(* --------------------------------------------------------------------- *)
(* We now also prove the converse, namely that if :'a satisfies an axiom *)
(* of infinity then UNIV:'a set is INFINITE.			         *)
(* --------------------------------------------------------------------- *)

(* --------------------------------------------------------------------- *)
(* First, a version of the primitive recursion theorem			 *)
(* --------------------------------------------------------------------- *)

val prth =
    prove_rec_fn_exists num_Axiom
    (Term`(fn f x 0       = x) /\
          (fn f x (SUC n) = (f:'a->'a) (fn f x n))`);

val prmth =
    TAC_PROOF
    (([], (--`!x:'a. !f. ?fn. (fn 0 = x) /\ !n. fn (SUC n) = f(fn n)`--)),
     REPEAT GEN_TAC THEN STRIP_ASSUME_TAC prth THEN
     EXISTS_TAC (--`fn (f:'a->'a) (x:'a) : num->'a`--) THEN
     ASM_REWRITE_TAC []);

(* --------------------------------------------------------------------- *)
(* Lemma: if f is one-to-one and not onto, there is a one-one f:num->'a. *)
(* --------------------------------------------------------------------- *)

val num_fn_thm = TAC_PROOF(([],
(--`(?f:'a->'a. (!x y. (f x = f y) ==> (x=y)) /\ ?y. !x. ~(f x = y))
    ==>
    (?fn:num->'a. (!n m. (fn n = fn m) ==> (n=m)))`--)),
     STRIP_TAC THEN
     STRIP_ASSUME_TAC (SPECL [(--`y:'a`--),(--`f:'a->'a`--)] prmth) THEN
     EXISTS_TAC (--`fn:num->'a`--) THEN INDUCT_TAC THENL
     [CONV_TAC (ONCE_DEPTH_CONV SYM_CONV) THEN
      INDUCT_TAC THEN ASM_REWRITE_TAC[],
      INDUCT_TAC THEN ASM_REWRITE_TAC [INV_SUC_EQ] THEN
      REPEAT STRIP_TAC THEN RES_TAC THEN RES_TAC]);

(* --------------------------------------------------------------------- *)
(* Lemma: every finite set of numbers has an upper bound.		*)
(* --------------------------------------------------------------------- *)

val finite_N_bounded =
    TAC_PROOF
    (([], (--`!s. FINITE s ==> ?m. !n. (n IN s) ==> n < m`--)),
     SET_INDUCT_TAC THENL
     [REWRITE_TAC [NOT_IN_EMPTY],
      FIRST_ASSUM (fn th => fn g => CHOOSE_THEN ASSUME_TAC th g) THEN
      EXISTS_TAC (--`(SUC m) + e`--) THEN REWRITE_TAC [IN_INSERT] THEN
      REPEAT STRIP_TAC THENL
      [PURE_ONCE_REWRITE_TAC [ADD_SYM] THEN ASM_REWRITE_TAC [LESS_ADD_SUC],
       RES_TAC THEN IMP_RES_TAC LESS_IMP_LESS_ADD THEN
       let val [_,_,c1,c2] = CONJUNCTS ADD_CLAUSES
       in ASM_REWRITE_TAC [c1,SYM c2]
       end]]);

(* --------------------------------------------------------------------- *)
(* Lemma: the set UNIV:(num->bool) is infinite.				*)
(* --------------------------------------------------------------------- *)

val N_lemma =
    TAC_PROOF
    (([], (--`INFINITE(UNIV:(num->bool))`--)),
     REWRITE_TAC [INFINITE_DEF] THEN STRIP_TAC THEN
     IMP_RES_THEN MP_TAC finite_N_bounded THEN
     REWRITE_TAC [IN_UNIV] THEN
     CONV_TAC NOT_EXISTS_CONV THEN GEN_TAC THEN
     CONV_TAC NOT_FORALL_CONV THEN EXISTS_TAC (--`SUC m`--) THEN
     REWRITE_TAC [NOT_LESS,LESS_OR_EQ,LESS_SUC_REFL]);

(* --------------------------------------------------------------------- *)
(* Lemma: if s is finite, f:num->'a is one-one, then ?n. f(n) not in s	*)
(* --------------------------------------------------------------------- *)

val main_lemma =
    TAC_PROOF
    (([], (--`!s:'a set. FINITE s ==>
           !f:num->'a. (!n m. (f n = f m) ==> (n=m)) ==> ?n. ~(f n IN s)`--)),
     REPEAT STRIP_TAC THEN
     ASSUME_TAC N_lemma THEN
     IMP_RES_TAC IMAGE_11_INFINITE THEN
     IMP_RES_THEN (TRY o IMP_RES_THEN MP_TAC) IN_INFINITE_NOT_FINITE THEN
     REWRITE_TAC [IN_IMAGE,IN_UNIV] THEN
     REPEAT STRIP_TAC THEN EXISTS_TAC (--`x':num`--) THEN
     EVERY_ASSUM (fn th => fn g => SUBST1_TAC (SYM th) g handle _ => ALL_TAC g)
     THEN FIRST_ASSUM ACCEPT_TAC);

(* ---------------------------------------------------------------------*)
(* Now show that we can always choose an element not in a finite set.	*)
(* ---------------------------------------------------------------------*)

val INFINITY_IMP_INF =
    TAC_PROOF
    (([],(--`(?f:'a->'a. (!x y. (f x = f y) ==> (x=y)) /\ ?y. !x. ~(f x = y))
          ==> (!s. FINITE s ==> ?x:'a. ~(x IN s))`--)),
     DISCH_THEN (STRIP_ASSUME_TAC o MATCH_MP num_fn_thm) THEN
     GEN_TAC THEN STRIP_TAC THEN
     IMP_RES_TAC main_lemma THEN
     EXISTS_TAC (--`(fn:num->'a) n`--) THEN
     FIRST_ASSUM ACCEPT_TAC);


(* ---------------------------------------------------------------------*)
(* Finally, we can prove the desired theorem.				*)
(* ---------------------------------------------------------------------*)

val INFINITE_UNIV =
    store_thm
    ("INFINITE_UNIV",
     (--`INFINITE (UNIV:'a set)
        =
      (?f:'a->'a. (!x y. (f x = f y) ==> (x = y)) /\ (?y. !x. ~(f x = y)))`--),
     PURE_ONCE_REWRITE_TAC [NOT_IN_FINITE] THEN
     ACCEPT_TAC (IMP_ANTISYM_RULE INF_IMP_INFINITY INFINITY_IMP_INF));


val FINITE_PSUBSET_INFINITE = store_thm("FINITE_PSUBSET_INFINITE",
(--`!s. INFINITE (s:'a set) =
        !t. FINITE (t:'a set) ==> ((t SUBSET s) ==> (t PSUBSET s))`--),
   PURE_REWRITE_TAC [INFINITE_DEF,PSUBSET_DEF] THEN
   GEN_TAC THEN EQ_TAC THENL
   [REPEAT STRIP_TAC THENL
    [FIRST_ASSUM ACCEPT_TAC,
     FIRST_ASSUM (fn th => fn g => SUBST_ALL_TAC th g handle _ => NO_TAC g)
     THEN RES_TAC],
    REPEAT STRIP_TAC THEN RES_TAC THEN
    ASSUME_TAC (SPEC (--`s:'a set`--) SUBSET_REFL) THEN
    ASSUME_TAC (REFL (--`s:'a set`--)) THEN RES_TAC]);

val FINITE_PSUBSET_UNIV = store_thm("FINITE_PSUBSET_UNIV",
(--`INFINITE (UNIV:'a set) = !s:'a set. FINITE s ==> s PSUBSET UNIV`--),
     PURE_ONCE_REWRITE_TAC [FINITE_PSUBSET_INFINITE] THEN
     REWRITE_TAC [PSUBSET_DEF,SUBSET_UNIV]);

val INFINITE_DIFF_FINITE = store_thm("INFINITE_DIFF_FINITE",
     (--`!s t. (INFINITE s /\ FINITE t) ==> ~(s DIFF t = ({}:'a set))`--),
     REPEAT GEN_TAC THEN STRIP_TAC THEN
     IMP_RES_TAC IN_INFINITE_NOT_FINITE THEN
     REWRITE_TAC [EXTENSION,IN_DIFF,NOT_IN_EMPTY] THEN
     CONV_TAC NOT_FORALL_CONV THEN
     EXISTS_TAC (--`x:'a`--) THEN ASM_REWRITE_TAC[]);


val FINITE_ISO_NUM =
    store_thm
    ("FINITE_ISO_NUM",
     (--`!s:'a set.
       FINITE s ==>
       ?f. (!n m. (n < CARD s /\ m < CARD s) ==> (f n = f m) ==> (n = m)) /\
           (s = {f n | n < CARD s})`--),
  SET_INDUCT_TAC THENL
  [PURE_ONCE_REWRITE_TAC [EXTENSION] THEN
   CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
   REWRITE_TAC [CARD_EMPTY,NOT_LESS_0,NOT_IN_EMPTY],
   FIRST_ASSUM (fn th => fn g => CHOOSE_THEN STRIP_ASSUME_TAC th g) THEN
   PURE_ONCE_REWRITE_TAC [UNDISCH (SPEC (--`s:'a set`--) CARD_INSERT)] THEN
   FILTER_ASM_REWRITE_TAC is_neg [] THEN
   PURE_ONCE_REWRITE_TAC [LESS_THM] THEN
   EXISTS_TAC (--`\n. if n < (CARD (s:'a set)) then f n else (e:'a)`--) THEN
   CONV_TAC (ONCE_DEPTH_CONV BETA_CONV) THEN CONJ_TAC THENL
   [REPEAT GEN_TAC THEN
    let fun ttac th g = SUBST_ALL_TAC th g handle _ => ASSUME_TAC th g
    in DISCH_THEN (REPEAT_TCL STRIP_THM_THEN ttac) end
    THENL
    [REPEAT STRIP_TAC THEN REFL_TAC,
     let fun is_less t = (fst(strip_comb t) = (--`$<`--)) handle _ => false
     in FILTER_ASM_REWRITE_TAC is_less [LESS_REFL] end THEN
     FIRST_ASSUM (fn th => fn g => MP_TAC (assert (is_eq o concl) th) g) THEN
     PURE_ONCE_REWRITE_TAC [EXTENSION] THEN
     CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
     REPEAT STRIP_TAC THEN RES_TAC THEN RES_TAC,
     let fun is_less t = (fst(strip_comb t) = (--`$<`--)) handle _ => false
     in FILTER_ASM_REWRITE_TAC is_less [LESS_REFL] end THEN
     FIRST_ASSUM (fn th => fn g => MP_TAC (assert (is_eq o concl) th) g) THEN
     PURE_ONCE_REWRITE_TAC [EXTENSION] THEN
     CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
     CONV_TAC (ONCE_DEPTH_CONV SYM_CONV) THEN
     REPEAT STRIP_TAC THEN RES_TAC THEN RES_TAC,
     let fun is_less t = (fst(strip_comb t) = (--`$<`--)) handle _ => false
     in FILTER_ASM_REWRITE_TAC is_less [LESS_REFL] end THEN
     FIRST_ASSUM MATCH_MP_TAC THEN
     CONJ_TAC THEN FIRST_ASSUM ACCEPT_TAC],
    FIRST_ASSUM (fn th => fn g => (MP_TAC (assert(is_eq o concl) th)) g) THEN
    PURE_REWRITE_TAC [EXTENSION,IN_INSERT] THEN
    CONV_TAC (ONCE_DEPTH_CONV SET_SPEC_CONV) THEN
    DISCH_THEN (fn th => PURE_ONCE_REWRITE_TAC [th]) THEN
    GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL
    [EXISTS_TAC (--`CARD (s:'a set)`--) THEN
     REWRITE_TAC [LESS_REFL] THEN FIRST_ASSUM ACCEPT_TAC,
     EXISTS_TAC (--`n:num`--) THEN
     FILTER_ASM_REWRITE_TAC (fn t => (not(lhs t = (--`s:'a set`--)))
                                     handle _ => true) [],
     SUBST1_TAC
       (ASSUME (--`x:'a = (if n < CARD (s:'a set) then f n else e)`--)) THEN
     SUBST1_TAC (ASSUME (--`n = CARD (s:'a set)`--)) THEN
     REWRITE_TAC [LESS_REFL],
     SUBST1_TAC
       (ASSUME (--`x:'a = (if n < CARD (s:'a set) then f n else e)`--)) THEN
     DISJ2_TAC THEN EXISTS_TAC (--`n:num`--) THEN
     REWRITE_TAC [ASSUME (--`n < CARD (s:'a set)`--)]]]]);

open simpLib boolSimps mesonLib SingleStep
infix ++
val AP = numLib.ARITH_PROVE
val arith_ss = bool_ss ++ numSimps.ARITH_ss

val FINITE_WEAK_ENUMERATE = store_thm(
  "FINITE_WEAK_ENUMERATE",
  ``!s. FINITE s = ?f b. !e. e IN s = ?n. n < b /\ (e = f n)``,
  ONCE_REWRITE_TAC [EQ_IMP_THM] THEN
  SIMP_TAC bool_ss [FORALL_AND_THM] THEN CONJ_TAC THENL [
    HO_MATCH_MP_TAC FINITE_INDUCT THEN
    SIMP_TAC bool_ss [IN_INSERT, NOT_IN_EMPTY] THEN
    REPEAT STRIP_TAC THENL [
      Q.EXISTS_TAC `0` THEN SIMP_TAC arith_ss [],
      Q.EXISTS_TAC `\n. if n = b then e else f n` THEN
      Q.EXISTS_TAC `b + 1` THEN GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL [
        Q.EXISTS_TAC `b` THEN ASM_SIMP_TAC arith_ss [],
        RES_TAC THEN Q.EXISTS_TAC `n` THEN ASM_SIMP_TAC arith_ss [],
        POP_ASSUM MP_TAC THEN BETA_TAC THEN COND_CASES_TAC THEN
        ASM_MESON_TAC [AP ``~(x = y) /\ x < y + 1 ==> x < y``]
      ]
    ],

    SIMP_TAC bool_ss [GSYM LEFT_FORALL_IMP_THM] THEN REPEAT GEN_TAC THEN
    MAP_EVERY Q.ID_SPEC_TAC [`f`, `s`, `b`] THEN numLib.INDUCT_TAC THENL [
      SIMP_TAC (bool_ss ++ numSimps.ARITH_ss) [] THEN
      GEN_TAC THEN
      STRIP_ASSUME_TAC (Q.SPEC `s` SET_CASES) THEN
      ASM_SIMP_TAC bool_ss [IN_INSERT, FINITE_EMPTY] THEN
      DISCH_THEN (MP_TAC o Q.SPEC `x`) THEN REWRITE_TAC [],
      REPEAT STRIP_TAC THEN
      Q.ASM_CASES_TAC `?x. x IN s /\ !m. m < b ==> ~(f m = x)` THENL [
        POP_ASSUM STRIP_ASSUME_TAC THEN
        Q.SUBGOAL_THEN `f b = x` ASSUME_TAC THENL [
          `?n. n < SUC b /\ (x = f n)` by ASM_MESON_TAC [] THEN
          `~(n < b)` by ASM_MESON_TAC [] THEN
          `n = b` by ASM_SIMP_TAC arith_ss [] THEN
          ASM_SIMP_TAC bool_ss [],
          ALL_TAC
        ] THEN
        `s = x INSERT (s DELETE x)` by ASM_MESON_TAC [INSERT_DELETE] THEN
        POP_ASSUM SUBST1_TAC THEN
        SIMP_TAC bool_ss [FINITE_INSERT] THEN
        FIRST_X_ASSUM MATCH_MP_TAC THEN
        Q.EXISTS_TAC `f` THEN SIMP_TAC bool_ss [IN_DELETE] THEN
        GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL [
          `?n. n < SUC b /\ (e = f n)` by ASM_MESON_TAC [] THEN
          `~(n = b)` by ASM_MESON_TAC [] THEN
          `n < b` by ASM_SIMP_TAC arith_ss [] THEN
          ASM_MESON_TAC [],
          `n < SUC b` by ASM_SIMP_TAC arith_ss [] THEN
          ASM_MESON_TAC []
        ],
        FIRST_X_ASSUM MATCH_MP_TAC THEN Q.EXISTS_TAC `f` THEN
        POP_ASSUM (ASSUME_TAC o SIMP_RULE bool_ss []) THEN
        ASM_MESON_TAC [AP ``!x y. x < y ==> x < SUC y``]
      ]
    ]
  ]);

(* ===================================================================== *)
(* Big union (union of set of sets)                                      *)
(* ===================================================================== *)

val BIGUNION = new_definition(
  "BIGUNION",
  Term`BIGUNION P = { x | ?p. p IN P /\ x IN p}`);

val IN_BIGUNION = store_thm(
  "IN_BIGUNION",
  ``!x sos. x IN (BIGUNION sos) = ?s. x IN s /\ s IN sos``,
  SIMP_TAC bool_ss [GSPECIFICATION, BIGUNION, pairTheory.PAIR_EQ] THEN
  MESON_TAC []);

val BIGUNION_EMPTY = store_thm(
  "BIGUNION_EMPTY",
  ``BIGUNION EMPTY = EMPTY``,
  SIMP_TAC bool_ss [EXTENSION, IN_BIGUNION, NOT_IN_EMPTY]);

val BIGUNION_SING = store_thm(
  "BIGUNION_SING",
  ``!x. BIGUNION {x} = x``,
  SIMP_TAC bool_ss [EXTENSION, IN_BIGUNION, IN_INSERT, NOT_IN_EMPTY] THEN
  SIMP_TAC bool_ss [GSYM EXTENSION]);

val BIGUNION_UNION = store_thm(
  "BIGUNION_UNION",
  ``!s1 s2. BIGUNION (s1 UNION s2) = (BIGUNION s1) UNION (BIGUNION s2)``,
  SIMP_TAC bool_ss [EXTENSION, IN_UNION, IN_BIGUNION, LEFT_AND_OVER_OR,
                    EXISTS_OR_THM]);

val DISJOINT_BIGUNION_lemma = prove(
  ``!s t. DISJOINT (BIGUNION s) t =
          !s'. s' IN s ==> DISJOINT s' t``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC bool_ss [DISJOINT_DEF, EXTENSION, IN_BIGUNION, IN_INTER,
                    NOT_IN_EMPTY] THEN MESON_TAC []);

(* above with DISJOINT x y both ways round *)
val DISJOINT_BIGUNION = save_thm(
  "DISJOINT_BIGUNION",
  CONJ DISJOINT_BIGUNION_lemma
       (ONCE_REWRITE_RULE [DISJOINT_SYM] DISJOINT_BIGUNION_lemma));

val BIGUNION_INSERT = store_thm(
  "BIGUNION_INSERT",
  ``!s P. BIGUNION (s INSERT P) = s UNION (BIGUNION P)``,
  SIMP_TAC bool_ss [EXTENSION, IN_BIGUNION, IN_UNION, IN_INSERT] THEN
  MESON_TAC []);

val BIGUNION_SUBSET = store_thm(
  "BIGUNION_SUBSET",
  ``!X P. BIGUNION P SUBSET X = (!Y. Y IN P ==> Y SUBSET X)``,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  FULL_SIMP_TAC bool_ss [IN_BIGUNION, SUBSET_DEF] THEN
  PROVE_TAC []);

val FINITE_BIGUNION = store_thm(
  "FINITE_BIGUNION",
  ``!P. FINITE P /\ (!s. s IN P ==> FINITE s) ==> FINITE (BIGUNION P)``,
  SIMP_TAC bool_ss [GSYM AND_IMP_INTRO] THEN
  HO_MATCH_MP_TAC FINITE_INDUCT THEN
  SIMP_TAC bool_ss [NOT_IN_EMPTY, FINITE_EMPTY, BIGUNION_EMPTY,
                    IN_INSERT, DISJ_IMP_THM, FORALL_AND_THM,
                    BIGUNION_INSERT, FINITE_UNION]);

(* ----------------------------------------------------------------------
    BIGINTER (intersection of a set of sets)
   ---------------------------------------------------------------------- *)

val BIGINTER = new_definition(
  "BIGINTER",
  ``BIGINTER B = { x | !P. P IN B ==> x IN P}``);

val IN_BIGINTER = store_thm(
  "IN_BIGINTER",
  ``x IN BIGINTER B = !P. P IN B ==> x IN P``,
  SIMP_TAC bool_ss [BIGINTER, GSPECIFICATION, pairTheory.PAIR_EQ]);

val BIGINTER_INSERT = store_thm(
  "BIGINTER_INSERT",
  ``!P B. BIGINTER (P INSERT B) = P INTER BIGINTER B``,
  REPEAT GEN_TAC THEN CONV_TAC (REWR_CONV EXTENSION) THEN
  SIMP_TAC bool_ss [IN_BIGINTER, IN_INSERT, IN_INTER, DISJ_IMP_THM,
                    FORALL_AND_THM]);

val BIGINTER_EMPTY = store_thm(
  "BIGINTER_EMPTY",
  ``BIGINTER {} = UNIV``,
  REWRITE_TAC [EXTENSION, IN_BIGINTER, NOT_IN_EMPTY, IN_UNIV]);

val BIGINTER_INTER = store_thm(
  "BIGINTER_INTER",
  ``!P Q. BIGINTER {P; Q} = P INTER Q``,
  REWRITE_TAC [BIGINTER_EMPTY, BIGINTER_INSERT, INTER_UNIV]);

val BIGINTER_SING = store_thm(
  "BIGINTER_SING",
  ``!P. BIGINTER {P} = P``,
  SIMP_TAC bool_ss [EXTENSION, IN_BIGINTER, IN_SING] THEN
  SIMP_TAC bool_ss [GSYM EXTENSION]);

val SUBSET_BIGINTER = store_thm(
  "SUBSET_BIGINTER",
  ``!X P. X SUBSET BIGINTER P = !Y. Y IN P ==> X SUBSET Y``,
  REPEAT STRIP_TAC THEN FULL_SIMP_TAC bool_ss [IN_BIGINTER, SUBSET_DEF] THEN
  PROVE_TAC []);

val DISJOINT_BIGINTER = store_thm(
  "DISJOINT_BIGINTER",
  ``!X Y P. Y IN P /\ DISJOINT Y X ==>
            DISJOINT X (BIGINTER P) /\ DISJOINT (BIGINTER P) X``,
  SIMP_TAC bool_ss [DISJOINT_DEF, EXTENSION, NOT_IN_EMPTY, IN_INTER,
                    IN_BIGINTER] THEN PROVE_TAC []);

(* ====================================================================== *)
(* Cross product of sets                                                  *)
(* ====================================================================== *)

open pairTheory
val CROSS_DEF = new_definition(
  "CROSS_DEF",
  ``CROSS P Q = { p | FST p IN P /\ SND p IN Q }``);
val _ = set_fixity "CROSS" (Infixl 600);

val IN_CROSS = store_thm(
  "IN_CROSS",
  ``!P Q x. x IN (P CROSS Q) = FST x IN P /\ SND x IN Q``,
  SIMP_TAC bool_ss [GSPECIFICATION, CROSS_DEF, PAIR_EQ]);

val CROSS_EMPTY = store_thm(
  "CROSS_EMPTY",
  ``!P. (P CROSS {} = {}) /\ ({} CROSS P = {})``,
  SIMP_TAC bool_ss [EXTENSION, IN_CROSS, NOT_IN_EMPTY]);

val CROSS_INSERT_LEFT = store_thm(
  "CROSS_INSERT_LEFT",
  ``!P Q x. (x INSERT P) CROSS Q = ({x} CROSS Q) UNION (P CROSS Q)``,
  SIMP_TAC bool_ss [EXTENSION, IN_CROSS, IN_UNION, IN_INSERT,
                    NOT_IN_EMPTY] THEN
  MESON_TAC []);

val CROSS_INSERT_RIGHT = store_thm(
  "CROSS_INSERT_RIGHT",
  ``!P Q x. P CROSS (x INSERT Q) = (P CROSS {x}) UNION (P CROSS Q)``,
  SIMP_TAC bool_ss [EXTENSION, IN_CROSS, IN_UNION, IN_INSERT,
                    NOT_IN_EMPTY] THEN
  MESON_TAC []);

val FINITE_CROSS = store_thm(
  "FINITE_CROSS",
  ``!P Q. FINITE P /\ FINITE Q ==> FINITE (P CROSS Q)``,
  SIMP_TAC bool_ss [GSYM AND_IMP_INTRO, RIGHT_FORALL_IMP_THM] THEN
  HO_MATCH_MP_TAC FINITE_INDUCT THEN
  SIMP_TAC bool_ss [CROSS_EMPTY, FINITE_EMPTY] THEN
  REPEAT STRIP_TAC THEN ONCE_REWRITE_TAC [CROSS_INSERT_LEFT] THEN
  ASM_SIMP_TAC bool_ss [FINITE_UNION] THEN
  REWRITE_TAC [FINITE_WEAK_ENUMERATE] THEN
  `?f b. !x. x IN Q = ?n. n < b /\ (x = f n)`
     by ASM_MESON_TAC [FINITE_WEAK_ENUMERATE] THEN
  Q.EXISTS_TAC `\m. (e, f m)` THEN Q.EXISTS_TAC `b` THEN
  ASM_SIMP_TAC bool_ss [IN_CROSS, IN_INSERT, NOT_IN_EMPTY] THEN
  GEN_TAC THEN Cases_on `e'` THEN
  SIMP_TAC bool_ss [PAIR_EQ, FST, SND] THEN MESON_TAC []);

val CROSS_SINGS = store_thm(
  "CROSS_SINGS",
  ``!x y. {x} CROSS {y} = {(x,y)}``,
  SIMP_TAC bool_ss [EXTENSION, IN_INSERT, IN_CROSS, NOT_IN_EMPTY] THEN
  MESON_TAC [PAIR, FST, SND]);

val CARD_SING_CROSS = store_thm(
  "CARD_SING_CROSS",
  ``!x P. FINITE P ==> (CARD ({x} CROSS P) = CARD P)``,
  GEN_TAC THEN HO_MATCH_MP_TAC FINITE_INDUCT THEN
  SIMP_TAC bool_ss [CROSS_EMPTY, CARD_EMPTY] THEN REPEAT STRIP_TAC THEN
  ONCE_REWRITE_TAC [CROSS_INSERT_RIGHT] THEN
  ASM_SIMP_TAC bool_ss [CROSS_SINGS, GSYM INSERT_SING_UNION] THEN
  `FINITE ({x} CROSS P)` by ASM_MESON_TAC [FINITE_SING, FINITE_CROSS] THEN
  `~((x,e) IN ({x} CROSS P))`
     by ASM_MESON_TAC [IN_CROSS, FST, SND, IN_SING] THEN
  ASM_SIMP_TAC bool_ss [CARD_INSERT]);

val CARD_CROSS = store_thm(
  "CARD_CROSS",
  ``!P Q. FINITE P /\ FINITE Q ==> (CARD (P CROSS Q) = CARD P * CARD Q)``,
  SIMP_TAC bool_ss [GSYM AND_IMP_INTRO, RIGHT_FORALL_IMP_THM] THEN
  HO_MATCH_MP_TAC FINITE_INDUCT THEN
  SIMP_TAC bool_ss [CROSS_EMPTY, CARD_EMPTY, CARD_INSERT,
                    MULT_CLAUSES] THEN
  ONCE_REWRITE_TAC [CROSS_INSERT_LEFT] THEN
  REPEAT STRIP_TAC THEN
  `FINITE (P CROSS Q)` by ASM_MESON_TAC [FINITE_CROSS] THEN
  `FINITE ({e} CROSS Q)` by ASM_MESON_TAC [FINITE_CROSS, FINITE_SING] THEN
  Q.SUBGOAL_THEN `({e} CROSS Q) INTER (P CROSS Q) = {}` ASSUME_TAC THENL [
    SIMP_TAC bool_ss [IN_INTER, EXTENSION, IN_CROSS, IN_SING,
                      NOT_IN_EMPTY] THEN
    ASM_MESON_TAC [],
    ALL_TAC
  ] THEN
  CONV_TAC (LHS_CONV (REWR_CONV (GSYM ADD_0))) THEN
  POP_ASSUM (SUBST1_TAC o GSYM o REWRITE_RULE [CARD_EMPTY] o
             Q.AP_TERM `CARD`) THEN
  ASM_SIMP_TAC bool_ss [CARD_UNION, CARD_SING_CROSS, ADD_COMM]);

val CROSS_SUBSET = store_thm(
  "CROSS_SUBSET",
  Term`!P Q P0 Q0. (P0 CROSS Q0) SUBSET (P CROSS Q) =
                   (P0 = {}) \/ (Q0 = {}) \/
                   P0 SUBSET P /\ Q0 SUBSET Q`,
  SIMP_TAC bool_ss [IN_CROSS, SUBSET_DEF, FORALL_PROD, FST, SND,
                    NOT_IN_EMPTY, EXTENSION] THEN
  MESON_TAC []);


val FINITE_CROSS_EQ_lemma0 = prove(
  Term`!x. FINITE x ==>
           !P Q. (x = P CROSS Q) ==>
                 (P = {}) \/ (Q = {}) \/ FINITE P /\ FINITE Q`,
  HO_MATCH_MP_TAC FINITE_COMPLETE_INDUCTION THEN
  REPEAT STRIP_TAC THEN POP_ASSUM SUBST_ALL_TAC THEN
  `(P = {}) \/ ?p P0. (P = p INSERT P0) /\ ~(p IN P0)` by
     MESON_TAC [SET_CASES] THEN
  `(Q = {}) \/ ?q Q0. (Q = q INSERT Q0) /\ ~(q IN Q0)` by
     MESON_TAC [SET_CASES] THEN
  ASM_SIMP_TAC bool_ss [NOT_INSERT_EMPTY, FINITE_INSERT] THEN
  REPEAT (FIRST_X_ASSUM SUBST_ALL_TAC) THEN
  Q.PAT_ASSUM `FINITE X` MP_TAC THEN
  ONCE_REWRITE_TAC [CROSS_INSERT_LEFT] THEN
  ONCE_REWRITE_TAC [CROSS_INSERT_RIGHT] THEN
  SIMP_TAC bool_ss [FINITE_UNION, FINITE_SING, CROSS_SINGS] THEN
  REPEAT STRIP_TAC THENL [
    Q.SUBGOAL_THEN
       `(P0 CROSS {q}) PSUBSET ((p INSERT P0) CROSS (q INSERT Q0)) \/
        (P0 = {})`
    STRIP_ASSUME_TAC THENL [
      ASM_SIMP_TAC bool_ss [PSUBSET_DEF, CROSS_SUBSET, SUBSET_INSERT,
                            SUBSET_REFL, EXTENSION, IN_CROSS, IN_INSERT,
                            FORALL_PROD, FST, SND, NOT_IN_EMPTY,
                            SUBSET_DEF, IN_SING] THEN
      ASM_MESON_TAC [],
      POP_ASSUM (ANTE_RES_THEN (MP_TAC o Q.SPECL [`P0`, `{q}`])) THEN
      MESON_TAC [FINITE_EMPTY, NOT_INSERT_EMPTY],
      ASM_SIMP_TAC bool_ss [FINITE_EMPTY]
    ],
    Q.SUBGOAL_THEN
       `({p} CROSS Q0) PSUBSET ((p INSERT P0) CROSS (q INSERT Q0)) \/
        (Q0 = {})`
    STRIP_ASSUME_TAC THENL [
      ASM_SIMP_TAC bool_ss [PSUBSET_DEF, CROSS_SUBSET, SUBSET_INSERT,
                            SUBSET_REFL, EXTENSION, IN_CROSS, IN_INSERT,
                            FORALL_PROD, FST, SND, NOT_IN_EMPTY,
                            SUBSET_DEF, IN_SING] THEN
      ASM_MESON_TAC [],
      POP_ASSUM (ANTE_RES_THEN (MP_TAC o Q.SPECL [`{p}`, `Q0`])) THEN
      MESON_TAC [FINITE_EMPTY, NOT_INSERT_EMPTY],
      ASM_SIMP_TAC bool_ss [FINITE_EMPTY]
    ]
  ]);

val FINITE_CROSS_EQ_lemma =
  SIMP_RULE bool_ss [GSYM RIGHT_FORALL_IMP_THM] FINITE_CROSS_EQ_lemma0

val FINITE_CROSS_EQ = store_thm(
  "FINITE_CROSS_EQ",
  ``!P Q. FINITE (P CROSS Q)
             =
          (P = {}) \/ (Q = {}) \/ FINITE P /\ FINITE Q``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  MESON_TAC [FINITE_CROSS_EQ_lemma, FINITE_CROSS, FINITE_EMPTY,
             CROSS_EMPTY]);

(* ====================================================================== *)
(* Set complements.                                                       *)
(* ====================================================================== *)

val COMPL_DEF = new_definition ("COMPL_DEF", ``COMPL P = UNIV DIFF P``);

val IN_COMPL = store_thm
  ("IN_COMPL",
   ``!(x:'a) s. x IN COMPL s = ~(x IN s)``,
   SIMP_TAC bool_ss [COMPL_DEF, IN_DIFF, IN_UNIV]);

val COMPL_COMPL = store_thm
  ("COMPL_COMPL",
   ``!(s:'a->bool). COMPL (COMPL s) = s``,
   SIMP_TAC bool_ss [EXTENSION, IN_COMPL]);

val COMPL_CLAUSES = store_thm
  ("COMPL_CLAUSES",
   ``!(s:'a->bool). (COMPL s INTER s = {})
                    /\ (COMPL s UNION s = UNIV)``,
   SIMP_TAC bool_ss [EXTENSION, IN_COMPL, IN_INTER, IN_UNION, NOT_IN_EMPTY,
                     IN_UNIV]);

val COMPL_SPLITS = store_thm
  ("COMPL_SPLITS",
   ``!(p:'a->bool) q. p INTER q UNION COMPL p INTER q = q``,
   SIMP_TAC bool_ss [EXTENSION, IN_COMPL, IN_INTER, IN_UNION, NOT_IN_EMPTY,
                     IN_UNIV]
   THEN MESON_TAC []);

val INTER_UNION_COMPL = store_thm
  ("INTER_UNION_COMPL",
   ``!(s:'a->bool) t. s INTER t
                      = COMPL (COMPL s UNION COMPL t)``,
   SIMP_TAC bool_ss [EXTENSION, IN_COMPL, IN_INTER, IN_UNION, NOT_IN_EMPTY,
                     IN_UNIV]);

val COMPL_EMPTY = store_thm
  ("COMPL_EMPTY",
   ``COMPL {} = UNIV``,
   SIMP_TAC bool_ss [EXTENSION, IN_COMPL, NOT_IN_EMPTY, IN_UNIV]);

(* ====================================================================== *)
(* Sets of size n.                                                        *)
(* ====================================================================== *)

val count_def = new_definition ("count_def", ``count (n:num) = {m | m < n}``);

val IN_COUNT = store_thm
  ("IN_COUNT",
   ``!m n. m IN count n = m < n``,
   RW_TAC bool_ss [GSPECIFICATION, count_def]);

val COUNT_ZERO = store_thm
  ("COUNT_ZERO",
   ``count 0 = {}``,
   RW_TAC bool_ss [EXTENSION, IN_COUNT, NOT_IN_EMPTY]
   THEN CONV_TAC Arith.ARITH_CONV);

val COUNT_SUC = store_thm
  ("COUNT_SUC",
   ``!n. count (SUC n) = n INSERT count n``,
   RW_TAC bool_ss [EXTENSION, IN_INSERT, IN_COUNT]
   THEN CONV_TAC Arith.ARITH_CONV);

val FINITE_COUNT = store_thm
  ("FINITE_COUNT",
   ``!n. FINITE (count n)``,
   Induct THENL
   [RW_TAC bool_ss [COUNT_ZERO, FINITE_EMPTY],
    RW_TAC bool_ss [COUNT_SUC, FINITE_INSERT]]);

val CARD_COUNT = store_thm
  ("CARD_COUNT",
   ``!n. CARD (count n) = n``,
   Induct THENL
   [RW_TAC bool_ss [COUNT_ZERO, CARD_EMPTY],
    RW_TAC bool_ss [COUNT_SUC, CARD_INSERT, FINITE_COUNT, IN_COUNT]
    THEN POP_ASSUM MP_TAC
    THEN CONV_TAC Arith.ARITH_CONV]);

(*---------------------------------------------------------------------------
    A "fold"-like operation for sets.
 ---------------------------------------------------------------------------*)

val ITSET_defn = Defn.Hol_defn "ITSET"
  `ITSET (s:'a->bool) (b:'b) =
     if FINITE s then
        if s={} then b
        else ITSET (REST s) (f (CHOICE s) b)
     else ARB`;

(*---------------------------------------------------------------------------
       Termination of ITSET.
 ---------------------------------------------------------------------------*)

val (ITSET_eqn0, ITSET_IND) =
 Defn.tprove (ITSET_defn,
   TotalDefn.WF_REL_TAC `measure (CARD o FST)` THEN
   BasicProvers.PROVE_TAC [CARD_PSUBSET, REST_PSUBSET]);

(*---------------------------------------------------------------------------
      Desired recursion equation.

     |- FINITE s ==> ITSET f s b = if s = {} then b
                                  else ITSET f (REST s) (f (CHOICE s) b)
 ---------------------------------------------------------------------------*)

val ITSET_THM =
W (GENL o rev o free_vars o concl)
  (DISCH_ALL(ASM_REWRITE_RULE [ASSUME (Term`FINITE s`)] ITSET_eqn0));

val _ = save_thm("ITSET_IND",ITSET_IND);
val _ = save_thm("ITSET_THM",ITSET_THM);
val _ = save_thm("ITSET_EMPTY",
                  REWRITE_RULE []
                      (MATCH_MP (SPEC (Term`{}`) ITSET_THM) FINITE_EMPTY));

val _ = export_rewrites
    [
     (* BIGUNION/BIGINTER theorems *)
     "IN_BIGINTER", "IN_BIGUNION", "DISJOINT_BIGUNION", "BIGUNION_EMPTY",
     "BIGUNION_INSERT", "BIGUNION_UNION",
     "DISJOINT_BIGUNION", "BIGINTER_EMPTY", "BIGINTER_INSERT",
     (* cardinality theorems *)
     "CARD_EMPTY", "CARD_DIFF", "CARD_EQ_0", "CARD_INSERT",
     "CARD_INTER_LESS_EQ", "CARD_DELETE", "CARD_DIFF",
     (* complement theorems *)
     "COMPL_CLAUSES", "COMPL_COMPL", "COMPL_EMPTY", "IN_COMPL",
     (* "DELETE" theorems *)
     "IN_DELETE", "DELETE_DELETE", "DELETE_EQ_SING", "DELETE_SUBSET",
     "EMPTY_DELETE",
     (* "DIFF" theorems *)
     "DIFF_DIFF", "DIFF_EMPTY", "DIFF_EQ_EMPTY", "DIFF_UNIV", "EMPTY_DIFF",
     (* "DISJOINT" theorems *)
     "DISJOINT_EMPTY", "DISJOINT_INSERT", "DISJOINT_UNION_BOTH",
     (* "FINITE" theorems *)
     "FINITE_DELETE", "FINITE_EMPTY", "FINITE_INSERT", "FINITE_UNION",
     (* "IMAGE" theorems *)
     "IMAGE_EMPTY", "IMAGE_DELETE", "IMAGE_FINITE", "IMAGE_ID", "IMAGE_IN",
     "IMAGE_INSERT", "IMAGE_SUBSET", "IMAGE_UNION", "IN_IMAGE",
     (* "INSERT" theorems *)
     "INSERT_DELETE", "INSERT_DIFF", "INSERT_INSERT", "INSERT_SUBSET",
     "IN_INSERT", "NOT_IN_EMPTY",
     (* "INTER" theorems *)
     "IN_INTER", "INTER_EMPTY", "INTER_FINITE", "INTER_IDEMPOT",
     "INTER_SUBSET", "INTER_UNIV", "SUBSET_INTER",
     (* "PSUBSET" *)
     "PSUBSET_IRREFL", "PSUBSET_FINITE",
     (* "REST" *)
     "REST_PSUBSET", "REST_SING", "REST_SUBSET",
     (* "SING" *)
     "SING", "SING_FINITE",
     (* "SUBSET" *)
     "SUBSET_EMPTY", "SUBSET_FINITE", "SUBSET_INSERT", "SUBSET_REFL",
     (* "UNION" *)
     "IN_UNION", "UNION_EMPTY", "UNION_IDEMPOT", "UNION_UNIV", "UNION_SUBSET",
     "SUBSET_UNION",
     (* UNIV *)
     "IN_UNIV", "EMPTY_NOT_UNIV"
];


val _ = export_theory();

end;
