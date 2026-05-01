val run_programs :
  trials:int ->
  out_csv:string option ->
  file1:string ->
  inputs1:Ast.Cryptoline.var list ->
  spec1:Ast.Cryptoline.spec ->
  file2:string ->
  inputs2:Ast.Cryptoline.var list ->
  spec2:Ast.Cryptoline.spec ->
  unit
