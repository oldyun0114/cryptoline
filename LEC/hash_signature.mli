type t = {
  name : string;
  typ : string;
  mutable hash : Int64.t;
  mutable samples : int;
  mutable first_value : string option;
  mutable last_value : string option;
  mutable changed : bool;
}

val create : name:string -> typ:string -> t
val update_bits : t -> NBits.bits -> unit

val key : t -> string
val hex_hash : t -> string

val is_constant : t -> bool
val first_value : t -> string
val last_value : t -> string
val first_value_preview : t -> string
val last_value_preview : t -> string
