(*==================================================================================================*)
(*                                                                                                  *)
(*                rmem executable model                                                             *)
(*                =====================                                                             *)
(*                                                                                                  *)
(*  This file is:                                                                                   *)
(*                                                                                                  *)
(*  Copyright Peter Sewell, University of Cambridge                          2011-2012, 2014-2017   *)
(*  Copyright Shaked Flur, University of Cambridge                                      2014-2018   *)
(*  Copyright Jon French, University of Cambridge                                       2017-2018   *)
(*  Copyright Susmit Sarkar, University of St Andrews                        2011-2012, 2014-2015   *)
(*  Copyright Christopher Pulte, University of Cambridge                                2015-2016   *)
(*  Copyright Luc Maranget, INRIA Paris                                                 2011-2012   *)
(*  Copyright Francesco Zappa Nardelli, INRIA Paris                                          2011   *)
(*  Copyright Pankaj Pawan, IIT Kanpur and INRIA (when this work was done)                   2011   *)
(*  Copyright Ohad Kammar, University of Cambridge (when this work was done)                 2013   *)
(*                                                                                                  *)
(*  All rights reserved.                                                                            *)
(*                                                                                                  *)
(*  The rmem tool is distributed under the 2-clause BSD license in LICENCE.txt.                     *)
(*  For author information see README.md.                                                           *)
(*                                                                                                  *)
(*==================================================================================================*)

(* val get_cands : bool ref *)
(* val smt : bool ref *)
(* val solver : string ref *)
(* val candidates : string option ref *)
(* val minimal : bool ref *)
(* val optoax : bool ref *)
(* val axtoop : bool ref *)

val use_new_run: bool ref

(** output options **************************************************)

type verbosity_level =
  | Quiet                  (* -q, minimal output and things important for herd-tools *)
  | Normal                 (* default, things normal users would like to see *)
  | ThrottledInformation   (* -v, normal mode for informed users, no more than one line
                           every 5 seconds or so *)
  | UnthrottledInformation (* -v -v, even more information, might render the output unusable *)
  | Debug                  (* -debug, cryptic information *)

val verbosity_levels: verbosity_level list
val pp_verbosity_level: verbosity_level -> string

val verbosity:             verbosity_level ref
val increment_verbosity:   unit -> unit
val is_verbosity_at_least: verbosity_level -> bool

val logdir: (string option) ref

val dont_tool: bool ref (* "Dont" output *)

val debug_sail_interp : bool ref

val deterministic_output : bool ref

(** model options ***************************************************)

val model_params: MachineDefTypes.model_params ref

val big_endian: (bool option) ref

(* BE CAREFUL: call get_endianness only after thread_ism (of model_params)
has been set properly (i.e. set_model_ism was called) *)
val get_endianness: unit -> Sail_impl_base.end_flag
val pp_endianness: unit -> string

val set_model_ism: MachineDefTypes.isa_info -> unit

val suppress_non_symbol_memory: bool ref (* ELF *)

val aarch64gen: bool ref

val final_cond: string option ref (* 'Some s': change the final condition to 's' *)

val branch_targets: Branch_targets_parser_base.ast list option ref
val branch_targets_parse_from_file: string -> unit
val branch_targets_parse_from_string: string -> unit

val shared_memory: Shared_memory_parser_base.footprint list option ref
val shared_memory_parse_from_file: string -> unit
val shared_memory_parse_from_string: string -> unit

val add_bt_and_sm_to_model_params: ((Sail_impl_base.address * int) * string) list -> unit

(** UI options ******************************************************)

exception Interactive_quit

val auto_follow:       bool ref
val interactive_auto:  bool ref
val breakpoint_actual: bool ref
val auto_internal:     bool ref
val dumb_terminal:     bool ref

val random_seed: int option ref   (* per ppcmem invocation seed: None for fresh, or Some n for seed n *)

val follow:     Interact_parser_base.ast list ref
val set_follow: string -> unit

val ui_commands: (string option) ref

val use_dwarf: bool ref
val dwarf_source_dir: string ref
val dwarf_show_all_variable_locations: bool ref

val isa_defs_path: (string option) ref

(** PP stuff ********************************************************)

type ppstyle =
  | Ppstyle_full
  | Ppstyle_compact
  | Ppstyle_screenshot

val ppstyles : ppstyle list

val pp_ppstyle : ppstyle -> string

type ppkind =
  | Ascii
  | Html
  | Latex
  | Hash

type graph_backend =
  | Dot
  | Tikz

val set_graph_backend: string -> unit
val pp_graph_backend: graph_backend -> string

val graph_backend:             graph_backend ref
type run_dot = (* generate execution graph... *)
  | RD_step         (* at every step *)
  | RD_final        (* when reaching a final state (and stop) *)
  | RD_final_ok     (* when reaching a final state that sat. the
                    condition (and stop) *)
  | RD_final_not_ok (* when reaching a final state that does not sat.
                    the condition (and stop) *)
val run_dot:                   (run_dot option) ref
val generateddir:              (string option) ref
val print_hex:                 bool ref


val pp_colours:                bool ref
val pp_kind:                   ppkind ref
val pp_condense_finished_instructions: bool ref
val pp_suppress_newpage:       bool ref
val pp_buffer_messages:        bool ref
val pp_style:                  ppstyle ref
val pp_prefer_symbolic_values: bool ref
val pp_hide_pseudoregister_reads: bool ref
val pp_max_finished:           int option ref
val ppg_shared:                bool ref
val ppg_regs:                  bool ref
val ppg_reg_rf:                bool ref
val ppg_trans:                 bool ref
val pp_announce_options:       bool ref
val pp_sail:                   bool ref

val set_pp_kind : string -> unit

val pp_pp_kind : ppkind -> string

type ppmode =
  { pp_kind:                           ppkind;
    pp_colours:                        bool;
    pp_condense_finished_instructions: bool;
    pp_style:                          ppstyle;
    pp_suppress_newpage:               bool;
    pp_buffer_messages:                bool;
    pp_choice_history_limit:           int option;
    pp_symbol_table: ((Sail_impl_base.address * MachineDefTypes.size) * string) list;
    pp_dwarf_static:                   Dwarf.dwarf_static option;
    pp_dwarf_dynamic:                  Types.dwarf_dynamic option;
    pp_initial_write_ioids:            MachineDefTypes.ioid list;
    pp_prefer_symbolic_values:         bool;
    pp_hide_pseudoregister_reads:      bool;
    pp_max_finished:                   int option;
    ppg_shared:                        bool;
    ppg_rf:                            bool;
    ppg_fr:                            bool;
    ppg_co:                            bool;
    ppg_addr:                          bool;
    ppg_data:                          bool;
    ppg_ctrl:                          bool;
    ppg_regs:                          bool;
    ppg_reg_rf:                        bool;
    ppg_trans:                         bool;
    pp_pretty_eiid_table:              (MachineDefTypes.eiid * string) list;
    pp_trans_prefix:                   bool;
    pp_announce_options:               bool;
    pp_sail:                           bool;
    pp_default_cmd:                    Interact_parser_base.ast option;

(*    pp_instruction : (((Sail_impl_base.address * MachineDefTypes.size) * string) list) ->
                     MachineDefTypes.instruction_ast ->
                     Sail_impl_base.address ->
                     string; *)
  }

val pp_kind_lens                            : (ppmode, ppkind)                                                          Lens.t
val pp_colours_lens                         : (ppmode, bool)                                                            Lens.t
val pp_condense_finished_instructions_lens  : (ppmode, bool)                                                            Lens.t
val pp_style_lens                           : (ppmode, ppstyle)                                                         Lens.t
val pp_suppress_newpage_lens                : (ppmode, bool)                                                            Lens.t
val pp_buffer_messages_lens                 : (ppmode, bool)                                                            Lens.t
val pp_choice_history_limit_lens            : (ppmode, int option)                                                      Lens.t
val pp_symbol_table_lens                    : (ppmode, ((Sail_impl_base.address * MachineDefTypes.size) * string) list) Lens.t
val pp_dwarf_static_lens                    : (ppmode, Dwarf.dwarf_static option)                                       Lens.t
val pp_dwarf_dynamic_lens                   : (ppmode, Types.dwarf_dynamic option)                                      Lens.t
val pp_initial_write_ioids_lens             : (ppmode, MachineDefTypes.ioid list)                                       Lens.t
val pp_prefer_symbolic_values_lens          : (ppmode, bool)                                                            Lens.t
val pp_hide_pseudoregister_reads_lens       : (ppmode, bool)                                                            Lens.t
val pp_max_finished_lens                    : (ppmode, int option)                                                      Lens.t
val ppg_shared_lens                         : (ppmode, bool)                                                            Lens.t
val ppg_rf_lens                             : (ppmode, bool)                                                            Lens.t
val ppg_fr_lens                             : (ppmode, bool)                                                            Lens.t
val ppg_co_lens                             : (ppmode, bool)                                                            Lens.t
val ppg_addr_lens                           : (ppmode, bool)                                                            Lens.t
val ppg_data_lens                           : (ppmode, bool)                                                            Lens.t
val ppg_ctrl_lens                           : (ppmode, bool)                                                            Lens.t
val ppg_regs_lens                           : (ppmode, bool)                                                            Lens.t
val ppg_reg_rf_lens                         : (ppmode, bool)                                                            Lens.t
val ppg_trans_lens                          : (ppmode, bool)                                                            Lens.t
val pp_pretty_eiid_table_lens               : (ppmode, (MachineDefTypes.eiid * string) list)                            Lens.t
val pp_trans_prefix_lens                    : (ppmode, bool)                                                            Lens.t
val pp_announce_options_lens                : (ppmode, bool)                                                            Lens.t
val pp_sail_lens                            : (ppmode, bool)                                                            Lens.t
val pp_default_cmd_lens                     : (ppmode, Interact_parser_base.ast option)                                 Lens.t

val get_ppmode : unit -> ppmode

val ppmode_for_hashing : ppmode

(** topologies ******************************************************)

val elf_threads: int ref

val flowing_topologies : MachineDefTypes.flowing_topology list ref
val topauto: bool ref

(* topologies to use for web interface (not for text)*)
val topology_2: string ref
val topology_3: string ref
val topology_4: string ref

val get_topologies : int -> MachineDefTypes.flowing_topology list

(** snapshot data ***************************************************)

val snapshot_data : (string (*log filename*) * (MachineDefTypes.ioid * MachineDefTypes.register_snapshot * MachineDefTypes.memory_snapshot) list) ref

exception Test_proper_termination
