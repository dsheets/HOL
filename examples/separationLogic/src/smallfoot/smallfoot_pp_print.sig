signature smallfoot_pp_print =
sig
  include Abbrev



  val use_smallfoot_pretty_printer : bool ref
  val smallfoot_pretty_printer_block_indent : int ref

  val smallfoot_pretty_printer : term_pp_types.userprinter
  val temp_add_smallfoot_pp : unit -> unit  

end
