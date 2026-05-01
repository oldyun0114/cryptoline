let trials = ref 100
let out_csv = ref None
let input_files_rev = ref []

let anon_fun file =
  input_files_rev := file :: !input_files_rev

let parse_file file =
  let ((inputs, _outputs), spec) = Main.Common.parse_and_check file in
  (inputs, spec)

let args =
  [
    ("-trials",
     Arg.Int (fun n -> trials := n),
     "N Number of random inputs.");

    ("-out",
     Arg.String (fun s -> out_csv := Some s),
     "FILE Output CSV file.");
  ]

let usage =
  "Usage: lec_discover.exe -trials N -out result.csv FILE1.cl FILE2.cl"

let () =
  Arg.parse args anon_fun usage;
  match List.rev !input_files_rev with
  | [file1; file2] ->
      let (inputs1, spec1) = parse_file file1 in
      let (inputs2, spec2) = parse_file file2 in
      Lec.Random_discovery.run_programs
        ~trials:!trials
        ~out_csv:!out_csv
        ~file1
        ~inputs1
        ~spec1
        ~file2
        ~inputs2
        ~spec2
  | _ ->
      Arg.usage args usage;
      exit 1
