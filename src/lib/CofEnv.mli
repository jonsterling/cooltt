type reduced_env
type env
type cof = (Dim.dim, int) Cof.cof

(** Create an empty environment (uses a benign effect for now). *)
val init : unit -> env

(** Returns the consistency of the environment. *)
val consistency : env -> [`Consistent | `Inconsistent]

(** Assumes the truth of a cofibration; if it can be decomposed eagerly (conjunction of equations),
    then it does so immediately. Otherwise, it is held "on deck" and repeatedly decomposed when testing
    sequents. The function [consistency] will consider cofibrations on deck. *)
val assume : env -> cof -> env

(** Tests the validity of a sequent against the supplied environment. Equivalent to assuming
    the conjunction of the context and then testing truth. *)
val test_sequent : env -> cof list -> cof -> bool

module type PARAM = CoolBasis.Monoid.S with type key := cof

module type S =
sig
  type t
  (** Search all branches induced by unreduced joins under additional cofibrations. *)
  val left_invert_under_cofs : env -> cof list -> (env -> t) -> t
end

(** Monoidal interface *)
module Monoid (M : PARAM) : S with type t := M.t

(** Monadic interface *)
module Monad (M : CoolBasis.Monad.S) : S with type t := unit M.m

module Reduced :
sig
  (** Create an environment with no unreduced joins. *)
  val to_env : reduced_env -> env

  (** Returns the consistency of the environment. *)
  val consistency : reduced_env -> [`Consistent | `Inconsistent]

  module type S =
  sig
    type t
    (** Search all branches induced by unreduced joins under additional cofibrations. *)
    val left_invert_under_cofs : reduced_env -> cof list -> (reduced_env -> t) -> t
  end

  (** Monoidal interface *)
  module Monoid (M : PARAM) : S with type t := M.t

  (** Monadic interface *)
  module Monad (M : CoolBasis.Monad.S) : S with type t := unit M.m
end
