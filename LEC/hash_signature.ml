type t = {
  name : string;
  typ : string;
  mutable hash : Int64.t;
  mutable samples : int;
}

let fnv_offset = 0xcbf29ce484222325L
let fnv_prime  = 0x100000001b3L

let create ~name ~typ =
  {
    name;
    typ;
    hash = fnv_offset;
    samples = 0;
  }

let update_byte h b =
  Int64.mul (Int64.logxor h (Int64.of_int b)) fnv_prime

let update_string h s =
  let h = ref h in
  String.iter
    (fun c -> h := update_byte !h (Char.code c))
    s;
  !h

let update_bits sigv bs =
  let width = List.length bs in
  sigv.hash <- update_string sigv.hash (string_of_int width);
  sigv.hash <- update_string sigv.hash ":";
  sigv.hash <- update_string sigv.hash (NBits.string_of_bits bs);
  sigv.hash <- update_string sigv.hash ";";
  sigv.samples <- sigv.samples + 1

let hex_hash sigv =
  Printf.sprintf "%Lx" sigv.hash

let key sigv =
  sigv.typ ^ ":" ^ hex_hash sigv
