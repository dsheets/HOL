(* Holdep -- computing dependencies for a (list of) Moscow ML
   source files. Also has knowledge of HOL script and theory files.
   Handles strings and nested comments correctly;

   DOES NOT normalize file names under DOS. (yet)

  This has been adapted from the mosmldep in the MoscowML compiler
  sources, first by Ken Larsen and later by Konrad Slind and
  Michael Norrish.
*)
structure Holdep = struct

structure SimpleSMLLrVals =
  SimpleSMLLrValsFun(structure Token = LrParser.Token)
structure SimpleSMLLex =
  SimpleSMLLexFun(structure Tokens = SimpleSMLLrVals.Tokens)
structure SimpleSMLParser=
  Join(structure ParserData = SimpleSMLLrVals.ParserData
       structure Lex=SimpleSMLLex
       structure LrParser=LrParser)

fun normPath s = OS.Path.toString(OS.Path.fromString s)
fun manglefilename s = normPath s
fun errMsg str = TextIO.output(TextIO.stdErr, str ^ "\n\n")
fun fail()     = OS.Process.exit OS.Process.failure

fun addExt s ""  = normPath s
  | addExt s ext = normPath s^"."^ext;
fun addDir dir s = OS.Path.joinDirFile{dir=normPath dir,file=s}
val srev = String.implode o List.rev o String.explode

val space = " ";
fun spacify [] = []
  | spacify [x] = [x]
  | spacify (h::t) = h::space::spacify t;

  (*
fun createLexerStream (is : TextIO.instream) =
  LexBuffer.createLexer (fn buff => fn n => Nonstdio.buff_input is buff 0 n)

fun parsePhraseAndClear (file, stream) parsingFun lexingFun lexbuf = let
  val phr = parsingFun lexingFun lexbuf handle
    Parsing.ParseError f => let
      val pos1 = LexBuffer.getLexemeStart lexbuf
      val pos2 = LexBuffer.getLexemeEnd lexbuf
    in
      Location.errMsg (file, stream, lexbuf) (Location.Loc(pos1, pos2))
      "Syntax error."
    end
  | Lexer.LexicalError(msg, pos1, pos2) =>
    if pos1 >= 0 andalso pos2 >= 0 then
      Location.errMsg (file, stream, lexbuf)
      (Location.Loc(pos1, pos2))
      ("Lexical error: " ^ msg)
    else
      (Location.errPrompt ("Lexical error: " ^ msg ^ "\n\n");
       raise Fail "Lexical error")
  | x => (Parsing.clearParser(); raise x)
in
  Parsing.clearParser();
  phr
end;

fun parseFile (f:string, strm:instream) : lexbuf -> string list =
  parsePhraseAndClear (f, strm) Parser.MLtext Lexer.Token;

  *)

fun parseFile (f:string, strm:TextIO.instream) : string list =
let val lexer = SimpleSMLParser.makeLexer (fn n => TextIO.inputN(strm,n))
    fun print_error (s,i1,i2) =
      (print ("Parse error in " ^ s ^ " at " ^ Int.toString i1 ^ " to " ^
              Int.toString i2 ^ "\n");
       raise (Fail "Syntax Error."))
in
  #1 (SimpleSMLParser.parse(15,lexer,print_error,()))
  handle SimpleSMLLex.UserDeclarations.LexicalError(msg, text, pos) =>
    (print ("Lex error: " ^ msg ^ " at text " ^ text ^
            " and at position " ^ Int.toString pos ^ "\n");
     raise (Fail "Lexical error"))
end

local val path    = ref [""]
      fun lpcl []                = (errMsg "No filenames"; fail())
        | lpcl ("-I"::dir::tail) = (path := dir :: !path ; lpcl tail)
        | lpcl l                 = l
in
fun parseComLine l =
  let val s = lpcl l
  in
    path := List.rev (!path);
    s
  end

fun access assumes cdir s ext = let
  val sext = addExt s ext
  fun inDir dir = OS.FileSys.access (addDir dir sext, [])
in
  if inDir cdir orelse List.exists (fn nm => nm = sext) assumes then SOME s
  else
    case List.find inDir (!path) of
      SOME dir => SOME(addDir dir s)
    | NONE     => NONE
end

end (* local *)

local val res = ref [];
in
fun isTheory s =
  case List.rev(String.explode s) of
    #"y" :: #"r" :: #"o" :: #"e" :: #"h" :: #"T" :: n::ame =>
      SOME(String.implode(List.rev (n::ame)))
  | _ => NONE

fun addThExt s s' ext = addExt (addDir (OS.Path.dir s') s) ext
fun outname assumes cdir s =
  case isTheory s of
    SOME n => let
    in
      (* allow a dependency on a theory if we can see a script.sml file *)
      case access assumes cdir (n^"Script") "sml" of
        SOME s' => res := addThExt s s' "ui" :: !res
      | NONE => let
        in
          (* or, if we can see the theory.ui file already; which might
             happen if the theory file is in sigobj *)
          case access assumes cdir (n^"Theory") "ui" of
            SOME s' => res := addThExt s s' "ui" :: !res
          | NONE => ()
        end
    end
  | _ => let
    in
      case access assumes cdir s "sig" of
        SOME s' => res := addExt s' "ui" :: !res
      | _       => let
        in
          case access assumes cdir s "sml" of
            (* this case handles the situation where there is no .sig file
               locally, but a .sml file instead; compiling this will generate
               the .ui file too.  We have to say that we're dependent
               on the .uo file because the automatic logic will then
               correctly hunt back to the .sml file *)
            SOME s' => res := addExt s' "uo" :: !res
          | _       => let
            in
              (* this case added to cover the situations where we think we
                 are dependent on module foo, but we can't find foo.sml or
                 foo.sig.  This can happen when foo.sml exists in some
                 HOL directory but no foo.sig.  In this situation, the HOL
                 build process only copies foo.ui and foo.uo across to
                 sigobj (and not the .sig file that we usually find there),
                 so making the dependency analysis ignore foo.  We cover
                 this possibility by looking to see if we can see a .ui
                 file; if so, we can retain the dependency *)
              case access assumes cdir s "ui" of
                SOME s' => res := addExt s' "ui" :: !res
              | NONE => ()
            end
        end
    end

fun beginentry objext target = let
  val targetname = addExt target objext
in
  res := [targetname ^ ":"];
  if objext = "uo" andalso OS.FileSys.access(addExt target "sig", []) then
    res := addExt target "ui" :: !res
  else ()
end;

val escape_spaces = let
  fun translation c = if c = #" " then "\\ "
                      else if c = #"\\" then "\\\\"
                      else str c
  val escape_space = String.translate translation
in
  map escape_space
end

fun endentry() = (* for non-file-based Holdep *)
  if length (!res) > 1 then (* the first entry is the name of the file for
                               which we are computing dependencies *)
    String.concat (spacify (rev ("\n" :: escape_spaces (!res))))
  else ""
end;

fun read (assumes:string list) (srcext:string)
         (objext:string) (filename:string) : string = let
  open OS.FileSys Systeml
  val op ^ = OS.Path.concat
  val unquote = xable_string(Systeml.HOLDIR ^ "bin" ^ "unquote")
  val file0 = addExt filename srcext
  fun try_remove f =
    if file0 <> f then
      ((OS.FileSys.remove f) handle OS.SysErr _ => ())
    else
      ();
  val actualfile =
      if access (unquote, [A_EXEC]) then let
          val newname = tmpName();
        in
          (if OS.Process.isSuccess (Systeml.systeml [unquote, file0, newname]) then
             newname
           else file0)
          handle e => (try_remove newname; raise e)
        end
      else file0
  in let
  val is       = TextIO.openIn actualfile
  val mentions = ref (Binaryset.empty String.compare)
  fun insert s = mentions := Binaryset.addList (!mentions, s)
  val names    = parseFile (filename, is)
  val _        = TextIO.closeIn is
  val _        = try_remove actualfile
  val curr_dir = OS.Path.dir filename
in
  beginentry objext (manglefilename filename);
  insert names;
  Binaryset.app (outname assumes curr_dir o manglefilename) (!mentions);
  endentry ()
end
handle e => (try_remove actualfile; raise e)
end
(*
  handle (e as Parsing.ParseError _) => (print "Parse error!\n"; raise e)

  *)

fun processfile assumes filename =
    let (* val _ = output(std_err, "Processing " ^ filename ^ "\n"); *)
	val {base, ext} = OS.Path.splitBaseExt filename
    in
	case ext of
	    SOME "sig" => read assumes "sig" "ui" base
	  | SOME "sml" => read assumes "sml" "uo" base
	  | _          => ""
    end

(* assumes parameter is a list of files that we assume can be built in this
   directory *)
fun main assumes debug sl =
  let val cl_args = parseComLine sl
      val results = List.map (processfile assumes) cl_args
      val final = String.concat results
  in
    if debug then print ("Holdep: "^final^"\n") else ();
    final
  end
   handle e as OS.SysErr (str, _) => (errMsg str; raise e)

end (* struct *)

