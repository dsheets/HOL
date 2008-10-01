(* This file has been generated by java2opSem from /home/helen/Recherche/hol/HOL/examples/opsemTools/java2opsem/testFiles/javaFiles/BsearchKO.java*)


open HolKernel Parse boolLib
stringLib IndDefLib IndDefRules
finite_mapTheory relationTheory
newOpsemTheory
computeLib bossLib;

val _ = new_theory "BsearchKO";

(* Method binarySearch*)
val MAIN_def =
  Define `MAIN =
    RSPEC
    (\state.
      (!i . (((i>=0)/\(i<Num(ScalarOf (state ' "aLength"))-1)))==>(((ArrayOf (state ' "a") ' (i))<=(ArrayOf (state ' "a") ' (i+1))))))
      (Seq
        (Assign "result"
          (Const ~1)
        )
        (Seq
          (Assign "mid"
            (Const 0)
          )
          (Seq
            (Assign "left"
              (Const 0)
            )
            (Seq
              (Assign "right"
                (Sub 
                  (Var "aLength")
                  (Const 1)
                )
              )
              (Seq
                (While 
                  (And 
                    (Equal 
                      (Var "result")
                      (Const ~1)
                    )
                    (LessEq 
                      (Var "left")
                      (Var "right")
                    )
                  )
                  (Seq
                    (Assign "mid"
                      (Div 
                        (Plus 
                          (Var "left")
                          (Var "right")
                        )
                        (Const 2)
                      )
                    )
                    (Cond 
                      (Equal 
                        (Arr "a"
                          (Var "mid")
                        )
                        (Var "x")
                      )
                      (Assign "result"
                        (Var "mid")
                      )
                      (Cond 
                        (Less 
                          (Var "x")
                          (Arr "a"
                            (Var "mid")
                          )
                        )
                        (Assign "right"
                          (Sub 
                            (Var "mid")
                            (Const 1)
                          )
                        )
                        (Assign "right"
                          (Sub 
                            (Var "mid")
                            (Const 1)
                          )
                        )
                      )
                    )
                  )
                )
                (Assign "Result"
                  (Var "result")
                )
              )
            )
          )
        )
      )
    (\state1 state2.
      ((((ScalarOf (state2 ' "Result")=~1))) ==> ((!i . (((i>=0)/\(i<Num(ScalarOf (state1 ' "aLength")))))==>(~((ArrayOf (state2 ' "a") ' (i))=ScalarOf (state1 ' "x"))))))/\(((~(ScalarOf (state2 ' "Result")=~1))) ==> ((((ArrayOf (state2 ' "a") ' (Num(ScalarOf (state2 ' "Result"))))=ScalarOf (state1 ' "x"))))))
    `

  val _ = export_theory();
