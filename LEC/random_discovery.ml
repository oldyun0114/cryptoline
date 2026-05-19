open Ast.Cryptoline

module HS = Hash_signature
module Simulator = Sim.Simulator

type program_info = {
  file : string;
  inputs : var list;
  spec : spec;
}

type input_source =
  | Shared of string
  | Fresh
  | Const of Z.t

type explicit_input_map = {
  side1 : (string, input_source) Hashtbl.t;
  side2 : (string, input_source) Hashtbl.t;
}

let make_program_info ~file ~inputs ~spec = { file; inputs; spec }

let starts_with s prefix =
  let n = String.length prefix in
  String.length s >= n && String.sub s 0 n = prefix

let drop_prefix s prefix =
  String.sub s (String.length prefix) (String.length s - String.length prefix)

let find_opt tbl key =
  try Some (Hashtbl.find tbl key) with Not_found -> None

let nth_opt xs n =
  try Some (List.nth xs n) with _ -> None

let table_by_name vars =
  let tbl = Hashtbl.create 1024 in
  List.iter (fun v -> Hashtbl.replace tbl (string_of_var v) v) vars;
  tbl

let check_inputs_compatible p1 p2 =
  let n1 = List.length p1.inputs in
  let n2 = List.length p2.inputs in
  if n1 <> n2 then
    failwith
      (Printf.sprintf
         "Input number mismatch: %s has %d inputs, %s has %d inputs.\n\\
          V0 assumes the same input count. Use -lec-input-map auto or \\
          -lec-input-map FILE to enable mapped random inputs."
         p1.file n1 p2.file n2);
  List.iter2
    (fun v1 v2 ->
      let t1 = typ_of_var v1 in
      let t2 = typ_of_var v2 in
      if t1 <> t2 then
        failwith
          (Printf.sprintf
             "Input type mismatch: %s:%s vs %s:%s.\n\\
              V0 assumes the same input order and type. Use -lec-input-map."
             (string_of_var v1) (string_of_typ t1)
             (string_of_var v2) (string_of_typ t2)))
    p1.inputs p2.inputs

let bits_of_z_for_var v z =
  let w = size_of_var v in
  let bs = NBits.bits_of_num (Z.to_string z) in
  let extlen = w - List.length bs in
  if extlen < 0 then
    failwith
      (Printf.sprintf
         "Constant/random value is too wide for %s:%s"
         (string_of_var v) (string_of_typ (typ_of_var v)));
  let bs =
    if Z.lt z Z.zero then NBits.sext extlen bs else NBits.zext extlen bs
  in
  if List.length bs <> w then
    failwith
      (Printf.sprintf "Bit width mismatch when generating value for %s"
         (string_of_var v))
  else bs

let random_bits_for_var v =
  bits_of_z_for_var v (random_value (typ_of_var v))

let parse_input_source s =
  let s = String.trim s in
  if starts_with s "rand:" then Shared (drop_prefix s "rand:")
  else if starts_with s "shared:" then Shared (drop_prefix s "shared:")
  else if starts_with s "logical:" then Shared (drop_prefix s "logical:")
  else if s = "fresh" then Fresh
  else if starts_with s "const:" then Const (Z.of_string (drop_prefix s "const:"))
  else
    failwith
      (Printf.sprintf
         "Bad input source '%s'. Expected rand:NAME, fresh, or const:VALUE."
         s)

let empty_input_map () =
  { side1 = Hashtbl.create 1024; side2 = Hashtbl.create 1024 }

let strip_comment line =
  try String.sub line 0 (String.index line '#') with Not_found -> line

let load_input_map_file filename =
  if filename = "auto" then empty_input_map ()
  else
    let m = empty_input_map () in
    let ch = open_in filename in
    let line_no = ref 0 in
    (try
       while true do
         incr line_no;
         let line = input_line ch |> strip_comment |> String.trim in
         if line <> "" then begin
           let cols = List.map String.trim (String.split_on_char ',' line) in
           match cols with
           | [side; var_name; source] ->
               let tbl =
                 match String.lowercase_ascii side with
                 | "1" | "file1" | "left" -> m.side1
                 | "2" | "file2" | "right" -> m.side2
                 | _ ->
                     failwith
                       (Printf.sprintf
                          "%s:%d: bad side '%s'; expected 1 or 2"
                          filename !line_no side)
               in
               Hashtbl.replace tbl var_name (parse_input_source source)
           | _ ->
               failwith
                 (Printf.sprintf
                    "%s:%d: expected CSV columns side,var,source"
                    filename !line_no)
         end
       done
     with End_of_file -> close_in ch);
    m

let default_source inputs1 inputs2 side index v =
  let name = string_of_var v in
  let other_inputs = if side = 1 then inputs2 else inputs1 in
  let other_by_name = table_by_name other_inputs in
  match find_opt other_by_name name with
  | Some ov when typ_of_var ov = typ_of_var v -> Shared ("name:" ^ name)
  | _ ->
      begin match nth_opt other_inputs index with
      | Some ov when typ_of_var ov = typ_of_var v ->
          Shared ("pos:" ^ string_of_int index)
      | _ -> Fresh
      end

let explicit_source map side name =
  match map with
  | None -> None
  | Some m ->
      let tbl = if side = 1 then m.side1 else m.side2 in
      find_opt tbl name

let bits_for_source logical_tbl source v =
  match source with
  | Fresh -> random_bits_for_var v
  | Const z -> bits_of_z_for_var v z
  | Shared key ->
      begin match find_opt logical_tbl key with
      | Some (typ, bits) ->
          let my_typ = string_of_typ (typ_of_var v) in
          if typ <> my_typ then
            failwith
              (Printf.sprintf
                 "Input map type mismatch for logical input %s: saw %s and %s"
                 key typ my_typ);
          bits
      | None ->
          let bits = random_bits_for_var v in
          Hashtbl.add logical_tbl key (string_of_typ (typ_of_var v), bits);
          bits
      end

let mapped_values_for_inputs map inputs1 inputs2 side logical_tbl =
  let inputs = if side = 1 then inputs1 else inputs2 in
  List.mapi
    (fun index v ->
      let name = string_of_var v in
      let source =
        match explicit_source map side name with
        | Some source -> source
        | None -> default_source inputs1 inputs2 side index v
      in
      bits_for_source logical_tbl source v)
    inputs

let input_fingerprint values =
  values
  |> List.map NBits.string_of_bits
  |> String.concat "|"
  |> Digest.string
  |> Digest.to_hex

let simulate_once inputs values spec =
  let init_map = Simulator.make_map inputs values in
  let manager = new Simulator.shellManager init_map spec.sprog in
  manager#run;
  manager#get_map

let get_or_create_signature tbl v =
  let name = string_of_var v in
  try Hashtbl.find tbl name
  with Not_found ->
    let sigv = HS.create ~name ~typ:(string_of_typ (typ_of_var v)) in
    Hashtbl.add tbl name sigv;
    sigv

let update_signatures_from_map sig_tbl value_map =
  VM.iter
    (fun v bits ->
      let sigv = get_or_create_signature sig_tbl v in
      HS.update_bits sigv bits)
    value_map

let signatures_to_list tbl =
  Hashtbl.fold (fun _ sigv acc -> sigv :: acc) tbl []

let index_by_hash sigs =
  let index = Hashtbl.create 4096 in
  List.iter
    (fun sigv ->
      let k = HS.key sigv in
      let old = try Hashtbl.find index k with Not_found -> [] in
      Hashtbl.replace index k (sigv :: old))
    sigs;
  index

let find_matches sigs1 sigs2 =
  let index2 = index_by_hash sigs2 in
  let matches = ref [] in
  List.iter
    (fun s1 ->
      let k = HS.key s1 in
      let candidates = try Hashtbl.find index2 k with Not_found -> [] in
      List.iter (fun s2 -> matches := (s1, s2) :: !matches) candidates)
    sigs1;
  List.rev !matches

let name_set vars =
  let tbl = Hashtbl.create 1024 in
  List.iter (fun v -> Hashtbl.replace tbl (string_of_var v) true) vars;
  tbl

let in_name_set tbl name = Hashtbl.mem tbl name
let csv_escape s =
  let dq = String.make 1 (Char.chr 34) in
  let need_quote =
    String.exists
      (fun c -> c = ',' || Char.code c = 34 || Char.code c = 10 || Char.code c = 13)
      s
  in
  if need_quote then
    dq ^ String.concat (dq ^ dq) (String.split_on_char (Char.chr 34) s) ^ dq
  else s

let count_if pred xs =
  List.fold_left (fun acc x -> if pred x then acc + 1 else acc) 0 xs

let count_signature_groups matches =
  let tbl = Hashtbl.create 4096 in
  List.iter
    (fun (s1, _s2) ->
      let k = s1.HS.typ ^ ":" ^ HS.hex_hash s1 in
      Hashtbl.replace tbl k true)
    matches;
  Hashtbl.length tbl
let is_tiny_flag_type typ =
  typ = "bit" || typ = "uint1" || typ = "sint1"

let is_input_candidate input_names1 input_names2 (s1, s2) =
  in_name_set input_names1 s1.HS.name || in_name_set input_names2 s2.HS.name

let is_constant_candidate (s1, s2) =
  HS.is_constant s1 || HS.is_constant s2

let is_tiny_flag_candidate (s1, s2) =
  is_tiny_flag_type s1.HS.typ || is_tiny_flag_type s2.HS.typ

let is_basic_meaningful_candidate input_names1 input_names2 (s1, s2) =
  not (is_constant_candidate (s1, s2))
  && not (is_input_candidate input_names1 input_names2 (s1, s2))
  && not (is_tiny_flag_candidate (s1, s2))

let filtered_filename filename =
  if Filename.check_suffix filename ".csv" then
    String.sub filename 0 (String.length filename - 4) ^ "_filtered.csv"
  else filename ^ "_filtered.csv"

let write_csv filename input_names1 input_names2 matches =
  let ch = open_out filename in
  output_string ch
    "var_file1,var_file2,type,hash,samples_file1,samples_file2,const_file1,const_file2,input_file1,input_file2,same_name,first_file1,last_file1,first_file2,last_file2";
  output_char ch (Char.chr 10);
  List.iter
    (fun (s1, s2) ->
      let input1 = in_name_set input_names1 s1.HS.name in
      let input2 = in_name_set input_names2 s2.HS.name in
      let same_name = s1.HS.name = s2.HS.name in
      Printf.fprintf ch "%s,%s,%s,%s,%d,%d,%b,%b,%b,%b,%b,%s,%s,%s,%s"
        (csv_escape s1.HS.name)
        (csv_escape s2.HS.name)
        (csv_escape s1.HS.typ)
        (HS.hex_hash s1)
        s1.HS.samples
        s2.HS.samples
        (HS.is_constant s1)
        (HS.is_constant s2)
        input1
        input2
        same_name
        (csv_escape (HS.first_value_preview s1))
        (csv_escape (HS.last_value_preview s1))
        (csv_escape (HS.first_value_preview s2))
        (csv_escape (HS.last_value_preview s2));
      output_char ch (Char.chr 10))
    matches;
  close_out ch
let print_preview matches =
  let max_preview = 50 in
  Printf.printf "\nFirst %d candidate pairs:\n" max_preview;
  List.iteri
    (fun i (s1, s2) ->
      if i < max_preview then
        Printf.printf "  [%d] %s <-> %s type=%s hash=%s const=(%b,%b)\n"
          i s1.HS.name s2.HS.name s1.HS.typ
          (HS.hex_hash s1)
          (HS.is_constant s1)
          (HS.is_constant s2))
    matches

let print_debug_summary input_names1 input_names2 matches =
  let both_const =
    count_if (fun (s1, s2) -> HS.is_constant s1 && HS.is_constant s2) matches
  in
  let any_const =
    count_if (fun (s1, s2) -> HS.is_constant s1 || HS.is_constant s2) matches
  in
  let both_non_const =
    count_if
      (fun (s1, s2) -> (not (HS.is_constant s1)) && (not (HS.is_constant s2)))
      matches
  in
  let any_input =
    count_if
      (fun (s1, s2) ->
        in_name_set input_names1 s1.HS.name
        || in_name_set input_names2 s2.HS.name)
      matches
  in
  let same_name =
    count_if (fun (s1, s2) -> s1.HS.name = s2.HS.name) matches
  in
  let groups = count_signature_groups matches in
  Printf.printf "\nDebug classification\n";
  Printf.printf "Signature groups: %d\n" groups;
  Printf.printf "Candidate pairs involving any constant-like variable: %d\n" any_const;
  Printf.printf "Candidate pairs where both sides are constant-like: %d\n" both_const;
  Printf.printf "Candidate pairs where both sides are non-constant: %d\n" both_non_const;
  Printf.printf "Candidate pairs involving input variables: %d\n" any_input;
  Printf.printf "Candidate pairs with same variable name: %d\n" same_name

let run_programs
    ~trials ~out_csv ~input_map
    ~file1 ~inputs1 ~spec1 ~file2 ~inputs2 ~spec2 =
  if trials <= 0 then failwith "The number of trials must be positive.";
  Random.self_init ();
  Printf.printf "LEC random simulation candidate discovery\n";
  Printf.printf "File 1: %s\n" file1;
  Printf.printf "File 2: %s\n" file2;
  Printf.printf "Trials: %d\n" trials;
  begin match input_map with
  | None -> Printf.printf "Input mapping: strict V0\n\n%!"
  | Some "auto" -> Printf.printf "Input mapping: auto\n\n%!"
  | Some filename -> Printf.printf "Input mapping: %s\n\n%!" filename
  end;

  let p1 = make_program_info ~file:file1 ~inputs:inputs1 ~spec:spec1 in
  let p2 = make_program_info ~file:file2 ~inputs:inputs2 ~spec:spec2 in
  let mapped_input =
    match input_map with
    | None ->
        check_inputs_compatible p1 p2;
        None
    | Some filename -> Some (load_input_map_file filename)
  in

  let sig_tbl1 = Hashtbl.create 4096 in
  let sig_tbl2 = Hashtbl.create 4096 in
  let first_input_fp = ref None in
  let last_input_fp = ref None in
  let input_changed = ref false in

  for i = 1 to trials do
    if i = 1 || i mod 100 = 0 || i = trials then
      Printf.printf "  trial %d / %d\n%!" i trials;

    let values1, values2 =
      match mapped_input with
      | None ->
          let values = List.map random_bits_for_var p1.inputs in
          (values, values)
      | Some m ->
          let logical_tbl = Hashtbl.create 1024 in
          let v1 = mapped_values_for_inputs (Some m) p1.inputs p2.inputs 1 logical_tbl in
          let v2 = mapped_values_for_inputs (Some m) p1.inputs p2.inputs 2 logical_tbl in
          (v1, v2)
    in

    let fp = input_fingerprint (values1 @ values2) in
    begin match !first_input_fp with
    | None ->
        first_input_fp := Some fp;
        last_input_fp := Some fp
    | Some first ->
        if fp <> first then input_changed := true;
        last_input_fp := Some fp
    end;

    let final_map1 = simulate_once p1.inputs values1 p1.spec in
    let final_map2 = simulate_once p2.inputs values2 p2.spec in
    update_signatures_from_map sig_tbl1 final_map1;
    update_signatures_from_map sig_tbl2 final_map2
  done;

  let sigs1 = signatures_to_list sig_tbl1 in
  let sigs2 = signatures_to_list sig_tbl2 in
  let matches = find_matches sigs1 sigs2 in
  let input_names1 = name_set p1.inputs in
  let input_names2 = name_set p2.inputs in
  let filtered_matches =
    List.filter (is_basic_meaningful_candidate input_names1 input_names2) matches
  in

  Printf.printf "\nSummary\n";
  Printf.printf "Program 1 variables with signatures: %d\n" (List.length sigs1);
  Printf.printf "Program 2 variables with signatures: %d\n" (List.length sigs2);
  Printf.printf "Candidate equal variable pairs: %d\n" (List.length matches);
  Printf.printf "Filtered candidate equal variable pairs: %d\n"
    (List.length filtered_matches);

  Printf.printf "\nRandom input debug\n";
  Printf.printf "First input fingerprint: %s\n"
    (match !first_input_fp with None -> "none" | Some x -> x);
  Printf.printf "Last input fingerprint: %s\n"
    (match !last_input_fp with None -> "none" | Some x -> x);
  Printf.printf "Random input changed across trials: %b\n" !input_changed;

  print_debug_summary input_names1 input_names2 matches;

  Printf.printf "\nFiltered debug classification\n";
  Printf.printf "Filtered signature groups: %d\n"
    (count_signature_groups filtered_matches);
  Printf.printf "Filtered candidate pairs: %d\n" (List.length filtered_matches);

  print_preview filtered_matches;

  begin match out_csv with
  | None -> ()
  | Some filename ->
      let filtered = filtered_filename filename in
      write_csv filename input_names1 input_names2 matches;
      write_csv filtered input_names1 input_names2 filtered_matches;
      Printf.printf "\nRaw CSV written to: %s\n" filename;
      Printf.printf "Filtered CSV written to: %s\n" filtered
  end
