(***********************************************************************)
(*                                                                     *)
(*                   OCaml interface to Sundials                       *)
(*                                                                     *)
(*  Timothy Bourke (Inria), Jun Inoue (Inria), and Marc Pouzet (LIENS) *)
(*                                                                     *)
(*  Copyright 2014 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under a BSD 2-Clause License, refer to the file LICENSE.           *)
(*                                                                     *)
(***********************************************************************)

(* basic cvode types *)

type ('data, 'kind) nvector = ('data, 'kind) Sundials.nvector
type real_array = Sundials.RealArray.t

type root_array = Sundials.Roots.t
type root_val_array = Sundials.Roots.val_array

type 'a single_tmp = 'a
type 'a triple_tmp = 'a * 'a * 'a

type ('t, 'a) jacobian_arg =
  {
    jac_t   : float;
    jac_y   : 'a;
    jac_fy  : 'a;
    jac_tmp : 't
  }

type 'a prec_solve_arg =
  {
    rhs   : 'a;
    gamma : float;
    delta : float;
    left  : bool;
  }

type 'a spils_callbacks =
  {
    prec_solve_fn : (('a single_tmp, 'a) jacobian_arg -> 'a prec_solve_arg
                     -> 'a -> unit) option;
    prec_setup_fn : (('a triple_tmp, 'a) jacobian_arg -> bool -> float -> bool)
                    option;
    jac_times_vec_fn :
      (('a single_tmp, 'a) jacobian_arg
       -> 'a (* v *)
       -> 'a (* Jv *)
       -> unit) option;
  }

type bandrange = { mupper : int; mlower : int; }

type dense_jac_fn = (real_array triple_tmp, real_array) jacobian_arg
                        -> Dls.DenseMatrix.t -> unit

type band_jac_fn = bandrange -> (real_array triple_tmp, real_array) jacobian_arg
                             -> Dls.BandMatrix.t -> unit

type 'a quadrhsfn = float -> 'a -> 'a -> unit

type 'a sensrhsfn =
    AllAtOnce of
      (float -> 'a -> 'a -> 'a array -> 'a array -> 'a -> 'a -> unit) option
  | OneByOne of
      (float -> 'a -> 'a -> int -> 'a -> 'a -> 'a -> 'a -> unit) option

type 'a quadsensrhsfn =
   float -> 'a -> 'a array -> 'a -> 'a array -> 'a -> 'a -> unit

module B =
  struct
    type 'a brhsfn =
            Basic of (float -> 'a -> 'a -> 'a -> unit)
          | WithSens of (float -> 'a -> 'a array -> 'a -> 'a -> unit)

    type 'a bquadrhsfn =
            Basic of (float -> 'a -> 'a -> 'a -> unit)
          | WithSens of (float -> 'a -> 'a array -> 'a -> 'a -> unit)

    type ('t, 'a) jacobian_arg =
      {
        jac_t   : float;
        jac_u   : 'a;
        jac_ub  : 'a;
        jac_fub : 'a;
        jac_tmp : 't
      }

    type 'a prec_solve_arg =
      {
        rvec   : 'a;
        gamma  : float;
        delta  : float;
        left   : bool
      }

    type 'a spils_callbacks =
      (* NB: field order must match (normal) spils_callbacks!
         (see precsetupfn in cvodes_ml.c) *)
      {
        prec_solve_fn : (('a single_tmp, 'a) jacobian_arg -> 'a prec_solve_arg
                         -> 'a -> unit) option;
        prec_setup_fn : (('a triple_tmp, 'a) jacobian_arg -> bool -> float
                        -> bool) option;
        jac_times_vec_fn :
          (('a single_tmp, 'a) jacobian_arg
           -> 'a (* v *)
           -> 'a (* Jv *)
           -> unit) option;
      }

    type dense_jac_fn =
          (real_array triple_tmp, real_array) jacobian_arg
              -> Dls.DenseMatrix.t -> unit

    type band_jac_fn =
          bandrange -> (real_array triple_tmp, real_array) jacobian_arg
              -> Dls.BandMatrix.t -> unit
  end

(* the session type *)

type cvode_mem
type cvode_file
type c_weak_ref

type ('a, 'kind) linsolv_callbacks =
  | NoCallbacks

  | DenseCallback of dense_jac_fn
  | BandCallback  of band_jac_fn
  | SpilsCallback of 'a spils_callbacks

  | BDenseCallback of B.dense_jac_fn
  | BBandCallback  of B.band_jac_fn
  | BSpilsCallback of 'a B.spils_callbacks

type ('a, 'kind) session = {
      cvode      : cvode_mem;
      backref    : c_weak_ref;
      nroots     : int;
      err_file   : cvode_file;

      mutable exn_temp     : exn option;
  
      mutable rhsfn        : float -> 'a -> 'a -> unit;
      mutable rootsfn      : float -> 'a -> root_val_array -> unit;
      mutable errh         : Sundials.error_details -> unit;
      mutable errw         : 'a -> 'a -> unit;

      mutable ls_callbacks : ('a, 'kind) linsolv_callbacks;

      mutable sensext      : ('a, 'kind) sensext (* Used by CVODES *)
    }

and ('a, 'kind) sensext =
      NoSensExt
    | FwdSensExt of ('a, 'kind) fsensext
    | BwdSensExt of ('a, 'kind) bsensext

and ('a, 'kind) fsensext = {
    (* Quadrature *)
    mutable quadrhsfn       : 'a quadrhsfn;

    (* Sensitivity *)
    mutable num_sensitivities : int;
    mutable sensarray1        : 'a array;
    mutable sensarray2        : 'a array;
    mutable senspvals         : Sundials.RealArray.t option;
                            (* keep a reference to prevent garbage collection *)

    mutable sensrhsfn         : (float -> 'a -> 'a -> 'a array
                                 -> 'a array -> 'a -> 'a -> unit);
    mutable sensrhsfn1        : (float -> 'a -> 'a -> int -> 'a
                                 -> 'a -> 'a -> 'a -> unit);
    mutable quadsensrhsfn     : 'a quadsensrhsfn;

    (* Adjoint *)
    mutable bsessions         : ('a, 'kind) session list;
                                (* hold references to prevent garbage collection
                                   of backward sessions which are needed for
                                   callbacks. *)
  }

and ('a, 'kind) bsensext = {
    (* Adjoint *)
    parent                : ('a, 'kind) session ;
    which                 : int;

    bnum_sensitivities    : int;
    bsensarray            : 'a array;

    mutable brhsfn        : (float -> 'a -> 'a -> 'a -> unit);
    mutable brhsfn1       : (float -> 'a -> 'a array -> 'a -> 'a -> unit);
    mutable bquadrhsfn    : (float -> 'a -> 'a -> 'a -> unit);
    mutable bquadrhsfn1   : (float -> 'a -> 'a array -> 'a -> 'a -> unit);
  }

