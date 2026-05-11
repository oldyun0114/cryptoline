type t = {
  name : string;
  typ : string;
  mutable hash : Int64.t;
  mutable samples : int;
  mutable first_value : string option;
  mutable last_value : string option;
  mutable changed : bool;
}

let fnv_offset = 0xcbf29ce484222325L
let fnv_prime = 0x100000001b3L

let create ~name ~typ =
  {
    name;
    typ;
    hash = fnv_offset;
    samples = 0;
    first_value = None;
    last_value = None;
    changed = false;
  }

let update_byte h b =
  Int64.mul (Int64.logxor h (Int64.of_int b)) fnv_prime

let update_string h s =
  let h = ref h in
  String.iter (fun c -> h := update_byte !h (Char.code c)) s;
  !h

let update_bits sigv bs =
  let width = List.length bs in
  let value = NBits.string_of_bits bs in
  let token = (string_of_int width) ^ ":" ^ value ^ ";" in

  sigv.hash <- update_string sigv.hash token;

  begin
    match sigv.first_value with
    | None ->
        sigv.first_value <- Some value;
        sigv.last_value <- Some value
    | Some first ->
        if value <> first then sigv.changed <- true;
        sigv.last_value <- Some value
  end;

  sigv.samples <- sigv.samples + 1

let hex_hash sigv =
  Printf.sprintf "%Lx" sigv.hash

let key sigv =
  sigv.typ ^ ":" ^ hex_hash sigv

let is_constant sigv =
  sigv.samples >= 2 && not sigv.changed

let first_value sigv =
  match sigv.first_value with
  | None -> ""
  | Some v -> v

let last_value sigv =
  match sigv.last_value with
  | None -> ""
  | Some v -> v

let preview s =
  let n = String.length s in
  if n <= 64 then s
  else String.sub s 0 64 ^ "...(" ^ string_of_int n ^ " bits)"

let first_value_preview sigv =
  preview (first_value sigv)

let last_value_preview sigv =
  preview (last_value sigv)
