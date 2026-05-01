type t = {
  name : string;
  typ : string;
  mutable hash : Int64.t;
  mutable samples : int;
}

val create : name:string -> typ:string -> t
val update_bits : t -> NBits.bits -> unit
val key : t -> string
val hex_hash : t -> string
