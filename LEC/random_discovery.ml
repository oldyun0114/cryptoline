open Ast.Cryptoline

module HS = Hash_signature
module Simulator = Sim.Simulator

type program_info = {
  file : string;
  inputs : var list;
  spec : spec;
}

let make_program_info ~file ~inputs ~spec =
  { file; inputs; spec }

let check_inputs_compatible p1 p2 =
  let n1 = List.length p1.inputs in
  let n2 = List.length p2.inputs in

  if n1 <> n2 then
    failwith
      (Printf.sprintf
         "Input number mismatch: %s has %d inputs, %s has %d inputs. V0 assumes the same input count."
         p1.file n1 p2.file n2);

  List.iter2
    (fun v1 v2 ->
      let t1 = typ_of_var v1 in
      let t2 = typ_of_var v2 in
      if t1 <> t2 then
        failwith
          (Printf.sprintf
             "Input type mismatch: %s:%s vs %s:%s. V0 assumes the same input order and type."
             (string_of_var v1)
             (string_of_typ t1)
             (string_of_var v2)
             (string_of_typ t2)))
    p1.inputs
    p2.inputs

let random_bits_for_var v =
  let z = random_value (typ_of_var v) in
  let w = size_of_var v in
  let bs = NBits.bits_of_num (Z.to_string z) in
  let extlen = w - List.length bs in
  let bs =
    if Z.lt z Z.zero then
      NBits.sext extlen bs
    else
      NBits.zext extlen bs
  in
  if List.length bs <> w then
    failwith
      (Printf.sprintf
         "Bit width mismatch when generating random input for %s"
         (string_of_var v))
  else
    bs

let simulate_once inputs values spec =
  let init_map = Simulator.make_map inputs values in
  let manager = new Simulator.shellManager init_map spec.sprog in
  manager#run;
  manager#get_map

let get_or_create_signature tbl v =
  let name = string_of_var v in
  try Hashtbl.find tbl name
  with Not_found ->
    let sigv =
      HS.create
        ~name
        ~typ:(string_of_typ (typ_of_var v))
    in
    Hashtbl.add tbl name sigv;
    sigv

let update_signatures_from_map sig_tbl value_map =
  VM.iter
    (fun v bits ->
      let sigv = get_or_create_signature sig_tbl v in
      HS.update_bits sigv bits)
    value_map

let signatures_to_list tbl =
  Hashtbl.fold
    (fun _ sigv acc -> sigv :: acc)
    tbl
    []

let index_by_hash sigs =
  let index = Hashtbl.create 4096 in
  List.iter
    (fun sigv ->
      let k = HS.key sigv in
      let old =
        try Hashtbl.find index k
        with Not_found -> []
      in
      Hashtbl.replace index k (sigv :: old))
    sigs;
  index

let find_matches sigs1 sigs2 =
  let index2 = index_by_hash sigs2 in
  let matches = ref [] in

  List.iter
    (fun s1 ->
      let k = HS.key s1 in
      let candidates =
        try Hashtbl.find index2 k
        with Not_found -> []
      in
      List.iter
        (fun s2 ->
          matches := (s1, s2) :: !matches)
        candidates)
    sigs1;

  List.rev !matches

let write_csv filename matches =
  let ch = open_out filename in
  output_string ch "var_file1,var_file2,type,hash,samples_file1,samples_file2\n";
  List.iter
    (fun (s1, s2) ->
      Printf.fprintf ch "%s,%s,%s,%s,%d,%d\n"
        s1.HS.name
        s2.HS.name
        s1.HS.typ
        (HS.hex_hash s1)
        s1.HS.samples
        s2.HS.samples)
    matches;
  close_out ch

let print_preview matches =
  let max_preview = 50 in
  Printf.printf "\nFirst %d candidate pairs:\n" max_preview;
  List.iteri
    (fun i (s1, s2) ->
      if i < max_preview then
        Printf.printf
          "  [%d] %s  <->  %s    type=%s hash=%s\n"
          i
          s1.HS.name
          s2.HS.name
          s1.HS.typ
          (HS.hex_hash s1))
    matches

let run_programs
    ~trials
    ~out_csv
    ~file1
    ~inputs1
    ~spec1
    ~file2
    ~inputs2
    ~spec2 =
  if trials <= 0 then
    failwith "The number of trials must be positive.";

  Random.self_init ();

  Printf.printf "LEC random simulation candidate discovery\n";
  Printf.printf "File 1: %s\n" file1;
  Printf.printf "File 2: %s\n" file2;
  Printf.printf "Trials: %d\n\n%!" trials;

  let p1 = make_program_info ~file:file1 ~inputs:inputs1 ~spec:spec1 in
  let p2 = make_program_info ~file:file2 ~inputs:inputs2 ~spec:spec2 in

  check_inputs_compatible p1 p2;

  let sig_tbl1 = Hashtbl.create 4096 in
  let sig_tbl2 = Hashtbl.create 4096 in

  for i = 1 to trials do
    if i = 1 || i mod 100 = 0 || i = trials then
      Printf.printf "  trial %d / %d\n%!" i trials;

    let values = List.map random_bits_for_var p1.inputs in

    let final_map1 = simulate_once p1.inputs values p1.spec in
    let final_map2 = simulate_once p2.inputs values p2.spec in

    update_signatures_from_map sig_tbl1 final_map1;
    update_signatures_from_map sig_tbl2 final_map2;
  done;

  let sigs1 = signatures_to_list sig_tbl1 in
  let sigs2 = signatures_to_list sig_tbl2 in
  let matches = find_matches sigs1 sigs2 in

  Printf.printf "\nSummary\n";
  Printf.printf "Program 1 variables with signatures: %d\n" (List.length sigs1);
  Printf.printf "Program 2 variables with signatures: %d\n" (List.length sigs2);
  Printf.printf "Candidate equal variable pairs: %d\n" (List.length matches);

  print_preview matches;

  begin match out_csv with
  | None -> ()
  | Some filename ->
      write_csv filename matches;
      Printf.printf "\nCSV written to: %s\n" filename
  end
