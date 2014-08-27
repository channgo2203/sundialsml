(*
 * -----------------------------------------------------------------
 * $Revision: 1.2 $
 * $Date: 2010/12/01 23:08:49 $
 * -----------------------------------------------------------------
 * Programmer(s): Radu Serban @ LLNL
 * -----------------------------------------------------------------
 * OCaml port: Timothy Bourke, Inria, May 2014.
 * -----------------------------------------------------------------
 * This example solves a nonlinear system from robot kinematics.
 *
 * Source: "Handbook of Test Problems in Local and Global Optimization",
 *             C.A. Floudas, P.M. Pardalos et al.
 *             Kluwer Academic Publishers, 1999.
 * Test problem 6 from Section 14.1, Chapter 14
 * 
 * The nonlinear system is solved by KINSOL using the DENSE linear
 * solver.
 *
 * Constraints are imposed to make all components of the solution
 * be within .{-1,1}.
 * -----------------------------------------------------------------
 *)

module RealArray = Sundials.RealArray

let printf = Printf.printf

(* Test the Cvode.Alternate module *)

module DM = Dls.DenseMatrix
module LintArray = Sundials.LintArray

let nvwl2norm = Nvector_serial.DataOps.n_vwl2norm

let nvdotprod xd yd =
  let sum = ref 0.0 in
  for i=0 to RealArray.length xd - 1 do
    sum := !sum +. xd.{i} *. yd.{i}
  done;
  !sum

type cvdls_mem = {
  dj     : DM.t;
  pivots : LintArray.t;
}

let alternate_dense jacfn =
  let nje = ref 0 in

  let linit mem s = (nje := 0; true) in

  let lsetup mem s =
    incr nje;
    DM.set_to_zero mem.dj;
    let uu, _   = Kinsol.Alternate.get_u_uscale s in
    let fval, _ = Kinsol.Alternate.get_f_fscale s in
    (try
      jacfn uu fval mem.dj
     with Sundials.RecoverableFailure _ -> failwith "Cannot recover!");
    DM.getrf mem.dj mem.pivots
  in

  let lsolve mem s x b =
    RealArray.blit b x;
    DM.getrs mem.dj mem.pivots x;
    let fval, fscale = Kinsol.Alternate.get_f_fscale s in
    Kinsol.Alternate.set_sjpnorm s (nvwl2norm b fscale);
    RealArray.mapi (fun i v -> v *. fscale.{i} *. fscale.{i}) b;
    Kinsol.Alternate.set_sfdotjp s (nvdotprod fval b);
    None
  in

  let solver =
    Kinsol.Alternate.make_solver (fun s nv ->
        let n = match nv with
                | None -> failwith "requires initial nvector!"
                | Some nv -> RealArray.length (Sundials.unvec nv)
        in
        let mem = {
          dj     = DM.create n n;
          pivots = LintArray.create n;
        }
        in
        {
          Kinsol.Alternate.linit = Some (linit mem);
          Kinsol.Alternate.lsetup = Some (lsetup mem);
          Kinsol.Alternate.lsolve = lsolve mem;
        })
  in
  (solver, fun () -> 0, !nje)


(* Problem Constants *)

let nvar  = 8              (* variables *) 
let neq   = 3*nvar         (* equations + bounds *)

let ftol  = 1.e-5 (* function tolerance *)
let stol  = 1.e-5 (* step tolerance *)

let zero  = 0.0
let one   = 1.0
let two   = 2.0

let ith v i = v.{i - 1}
let set_ith v i e = v.{i - 1} <- e

let set_ijth m i j = Dls.DenseMatrix.set m (i - 1) (j - 1)

(* System function *)
let func yd fd =
  let x1 = yd.{0} and l1 = yd.{ 8} and u1 = yd.{16}
  and x2 = yd.{1} and l2 = yd.{ 9} and u2 = yd.{17}
  and x3 = yd.{2} and l3 = yd.{10} and u3 = yd.{18}
  and x4 = yd.{3} and l4 = yd.{11} and u4 = yd.{19}
  and x5 = yd.{4} and l5 = yd.{12} and u5 = yd.{20}
  and x6 = yd.{5} and l6 = yd.{13} and u6 = yd.{21}
  and x7 = yd.{6} and l7 = yd.{14} and u7 = yd.{22}
  and x8 = yd.{7} and l8 = yd.{15} and u8 = yd.{23} in

  (* Nonlinear equations *)
  let eq1 = - 0.1238*.x1 +. x7 -. 0.001637*.x2 
    -. 0.9338*.x4 +. 0.004731*.x1*.x3 -. 0.3578*.x2*.x3 -. 0.3571 in
  let eq2 = 0.2638*.x1 -. x7 -. 0.07745*.x2 
    -. 0.6734*.x4 +. 0.2238*.x1*.x3 +. 0.7623*.x2*.x3 -. 0.6022 in
  let eq3 = 0.3578*.x1 +. 0.004731*.x2 +. x6*.x8 in
  let eq4 = -. 0.7623*.x1 +. 0.2238*.x2 +. 0.3461 in
  let eq5 = x1*.x1 +. x2*.x2 -. 1.0 in
  let eq6 = x3*.x3 +. x4*.x4 -. 1.0 in
  let eq7 = x5*.x5 +. x6*.x6 -. 1.0 in
  let eq8 = x7*.x7 +. x8*.x8 -. 1.0 in

  (* Lower bounds ( l_i = 1 + x_i >= 0)*)
  let lb1 = l1 -. 1.0 -. x1 in
  let lb2 = l2 -. 1.0 -. x2 in
  let lb3 = l3 -. 1.0 -. x3 in
  let lb4 = l4 -. 1.0 -. x4 in
  let lb5 = l5 -. 1.0 -. x5 in
  let lb6 = l6 -. 1.0 -. x6 in
  let lb7 = l7 -. 1.0 -. x7 in
  let lb8 = l8 -. 1.0 -. x8 in

  (* Upper bounds ( u_i = 1 - x_i >= 0)*)
  let ub1 = u1 -. 1.0 +. x1 in
  let ub2 = u2 -. 1.0 +. x2 in
  let ub3 = u3 -. 1.0 +. x3 in
  let ub4 = u4 -. 1.0 +. x4 in
  let ub5 = u5 -. 1.0 +. x5 in
  let ub6 = u6 -. 1.0 +. x6 in
  let ub7 = u7 -. 1.0 +. x7 in
  let ub8 = u8 -. 1.0 +. x8 in

  fd.{0} <- eq1; fd.{ 8} <- lb1; fd.{16} <- ub1;
  fd.{1} <- eq2; fd.{ 9} <- lb2; fd.{17} <- ub2;
  fd.{2} <- eq3; fd.{10} <- lb3; fd.{18} <- ub3;
  fd.{3} <- eq4; fd.{11} <- lb4; fd.{19} <- ub4;
  fd.{4} <- eq5; fd.{12} <- lb5; fd.{20} <- ub5;
  fd.{5} <- eq6; fd.{13} <- lb6; fd.{21} <- ub6;
  fd.{6} <- eq7; fd.{14} <- lb7; fd.{22} <- ub7;
  fd.{7} <- eq8; fd.{15} <- lb8; fd.{23} <- ub8

(* System Jacobian *)
let jac yd f j =
  let x1 = yd.{0}
  and x2 = yd.{1}
  and x3 = yd.{2}
  and x4 = yd.{3}
  and x5 = yd.{4}
  and x6 = yd.{5}
  and x7 = yd.{6}
  and x8 = yd.{7} in

  (* Nonlinear equations *)

  (* 
     - 0.1238*x1 + x7 - 0.001637*x2 
     - 0.9338*x4 + 0.004731*x1*x3 - 0.3578*x2*x3 - 0.3571 
  *)
  set_ijth j 1 1 (- 0.1238 +. 0.004731*.x3);
  set_ijth j 1 2 (- 0.001637 -. 0.3578*.x3);
  set_ijth j 1 3 (0.004731*.x1 -. 0.3578*.x2);
  set_ijth j 1 4 (- 0.9338);
  set_ijth j 1 7 (1.0);

  (*
    0.2638*x1 - x7 - 0.07745*x2 
    - 0.6734*x4 + 0.2238*x1*x3 + 0.7623*x2*x3 - 0.6022
  *)
  set_ijth j 2 1 (0.2638 +. 0.2238*.x3);
  set_ijth j 2 2 (- 0.07745 +. 0.7623*.x3);
  set_ijth j 2 3 (0.2238*.x1 +. 0.7623*.x2);
  set_ijth j 2 4 (- 0.6734);
  set_ijth j 2 7 (-1.0);

  (*
    0.3578*x1 + 0.004731*x2 + x6*x8
  *)
  set_ijth j 3 1 0.3578;
  set_ijth j 3 2 0.004731;
  set_ijth j 3 6 x8;
  set_ijth j 3 8 x6;

  (*
    - 0.7623*x1 + 0.2238*x2 + 0.3461
  *)
  set_ijth j 4 1 (- 0.7623);
  set_ijth j 4 2 (0.2238);

  (*
    x1*x1 + x2*x2 - 1
  *)
  set_ijth j 5 1 (2.0*.x1);
  set_ijth j 5 2 (2.0*.x2);

  (*
    x3*x3 + x4*x4 - 1
  *)
  set_ijth j 6 3 (2.0*.x3);
  set_ijth j 6 4 (2.0*.x4);

  (*
    x5*x5 + x6*x6 - 1
  *)
  set_ijth j 7 5 (2.0*.x5);
  set_ijth j 7 6 (2.0*.x6);

  (*
    x7*x7 + x8*x8 - 1
  *)
  set_ijth j 8 7 (2.0*.x7);
  set_ijth j 8 8 (2.0*.x8);

  (*
    Lower bounds ( l_i = 1 + x_i >= 0)
    l_i - 1.0 - x_i
   *)
  for i=1 to 8 do
    set_ijth j (8+i) (i) (-1.0);
    set_ijth j (8+i) (8+i) (1.0)
  done;

  (*
    Upper bounds ( u_i = 1 - x_i >= 0)
    u_i - 1.0 + x_i
   *)
  for i=1 to 8 do
    set_ijth j (16+i) i (1.0);
    set_ijth j (16+i) (16+i) (1.0)
  done

(* Print solution *)
let print_output y =
  printf "     l=x+1          x         u=1-x\n";
  printf "   ----------------------------------\n";

  for i=1 to nvar do
    printf " %10.6g   %10.6g   %10.6g\n"
      (ith y (i+nvar))
      (ith y i)
      (ith y (i+2*nvar))
  done

(* Print final statistics *)
let print_final_stats kmem nfeD nje =
  let nni = Kinsol.get_num_nonlin_solv_iters kmem in
  let nfe = Kinsol.get_num_func_evals kmem in
  printf "\nFinal Statistics.. \n";
  printf "nni    = %5d    nfe   = %5d \n" nni nfe;
  printf "nje    = %5d    nfeD  = %5d \n" nje nfeD

(* MAIN PROGRAM *)
let main () =
  printf "\nRobot Kinematics Example\n";
  printf "8 variables; -1 <= x_i <= 1\n";
  printf "KINSOL problem size: 8 + 2*8 = 24 \n\n";

  (* Create vectors for solution, scales, and constraints *)
  let y = Nvector_serial.make neq one in
  let ydata = Sundials.unvec y in
  for i = 1 to nvar do
    set_ith ydata i (sqrt(two) /. two)
  done;
  let scale = Nvector_serial.make neq one in

  (* Initialize and allocate memory for KINSOL *)
  (* Attach dense linear solver *)
  let altdense, get_stats = alternate_dense jac in
  let kmem = Kinsol.init altdense func y in

  (* Set optional inputs *)
  let constraints = RealArray.make neq zero in
  for i=nvar+1 to neq do
    set_ith constraints i one
  done;
  Kinsol.set_constraints kmem (Nvector_serial.wrap constraints);
  Kinsol.set_func_norm_tol kmem (Some ftol);
  Kinsol.set_scaled_step_tol kmem (Some stol);

  (* Indicate exact Newton *)
  Kinsol.set_max_setup_calls kmem (Some 1);

  (* Initial guess *)
  printf "Initial guess:\n";
  print_output ydata;

  (* Call KINSol to solve problem *)
  ignore (Kinsol.solve
            kmem    (* KINSol memory block *)
            y       (* initial guess on input; solution vector *)
            true    (* global stragegy choice *)
            scale   (* scaling vector, for the variable cc *)
            scale); (* scaling vector for function values fval *)

  printf "\nComputed solution:\n";
  print_output ydata;

  (* Print final statistics and free memory *)  
  let nfeD, nje = get_stats () in
  print_final_stats kmem nfeD nje

let n =
  match Sys.argv with
  | [|_; n|] -> int_of_string n
  | _ -> 1
let _ = for i = 1 to n do main () done

let _ = Gc.compact ()