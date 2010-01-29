val () = PolyML.print_depth 0;
local
  val fifoPath = Globals.HOLDIR^"/fifo"
  structure Queue :> (* Modified from http://mlton.org/MLtonThread *)
     sig
        type 'a t
        val new: unit -> 'a t
        val enque: 'a t * 'a -> unit
        val deque: 'a t -> 'a option
     end =
     struct
        datatype 'a t = T of {front: 'a list ref, back: 'a list ref}
        fun new() = T{front = ref [], back = ref []}
        fun enque(T{back, ...}, x) = back := x :: !back
        fun deque(T{front, back}) =
           case !front of
              [] => (case !back of
                        [] => NONE
                      | l => let val l = rev l in
                                back := []; front := (tl l); SOME (hd l)
                             end)
            | x :: l => (front := l; SOME x)
     end
  open TextIO Thread FileSys Unix
  fun warn s = output(stdErr, s)
  local open Process Posix.FileSys Globals in
    fun die s = (warn s; exit failure)
    val () = case getEnv "HOLDIR" of
               NONE => die "Please set HOLDIR environment variable\n"
             | SOME s => if s <> HOLDIR then
                           die ("HOLDIR environment variable "^s^" should be "^HOLDIR^"\n")
                         else ()
    val () = if access(fifoPath, []) then let
               val st = stat fifoPath
             in
               if ST.isFIFO st then ()
               else die (fifoPath^" is not a fifo\n")
             end else let
               open S val urw = flags [irusr, iwusr]
             in
               mkfifo(fifoPath, urw)
             end
  end
  val m = Mutex.mutex ()
  val c = ConditionVar.conditionVar ()
  val q = Queue.new ()
  fun tryRemove s = remove s handle SysErr _ => ()
  fun tryRemoveAll() = let
    fun loop() = case Queue.deque q of
      NONE => () |
      SOME tmp => (tryRemove tmp; loop())
    open Mutex
  in
    lock m; loop(); unlock m
  end
  local
    fun removeAfterUse tmp =
      (use tmp handle e => (tryRemove tmp; raise e);
       tryRemove tmp)
    open Mutex ConditionVar
  in
    fun runner () =
      (lock m;
       case Queue.deque q of
          NONE => (wait(c,m); unlock m)
        | SOME tmp => (unlock m; removeAfterUse tmp);
       runner ())
  end
  val rpid = ref (Thread.fork(fn () => (), []))
  val tail = ref (execute("/usr/bin/env",["tail","/dev/null"]))
  val fifo = ref (openString "")
  fun stopTail () = (kill(!tail,Posix.Signal.term); reap (!tail); ())
  fun restartTail () = (stopTail();
                        tail := execute("/usr/bin/env", ["tail", "-f", fifoPath]);
                        fifo := textInstreamOf (!tail))
  fun poller () = let in
    case inputLine (!fifo) of
      NONE => (warn "Vimhol's tail gave eof\n"; restartTail())
    | SOME line =>
      case String.tokens Char.isSpace line of
          ["Interrupt"] => (warn "Vim interrupt\n"; Thread.broadcastInterrupt ())
        | ["ReadFile",tmp] => let open Thread Mutex ConditionVar in
            warn ("Vim input "^tmp^"\n");
            lock m;
            Queue.enque(q,tmp);
            unlock m;
            if isActive (!rpid) then ()
            else rpid := fork(runner,
                              [InterruptState InterruptAsynch,
                               EnableBroadcastInterrupt true]);
            signal c
          end
        | [] => ()
        | _ => warn ("Got this rubbish from Vim: "^line);
    Thread.testInterrupt () handle Interrupt => (tryRemoveAll(); Thread.exit());
    poller ()
  end
  val () = Process.atExit stopTail
  val () = restartTail ()
  val ppid = ref (Thread.fork(poller,[]))
in
  structure Vimhol = struct
    fun pActive() = Thread.isActive (!ppid)
    fun rActive() = Thread.isActive (!rpid)
    val stopTail = stopTail
    val restartTail = restartTail
    fun stop() = (if rActive() then Thread.interrupt (!rpid) else ();
                  if pActive() then Thread.interrupt (!ppid) else ())
    fun restart() = (stop(); ppid := Thread.fork(poller,[]))
    val queue = q
    val tryRemoveAll = tryRemoveAll
  end
end