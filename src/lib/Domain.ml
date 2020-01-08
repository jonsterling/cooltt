module S = Syntax

open CoolBasis
open Bwd 
open TLNat

type env = {locals : con bwd}

and ('n, 't, 'o, 'sp) clo = Clo of {bdy : 't; env : env; spine : 'sp} | ConstClo of 'o
[@@deriving show]

and 'n tm_clo = ('n, S.t, con, frm list) clo
and 'n tp_clo = ('n, S.tp, tp, unit) clo


and con =
  | Lam of (ze su) tm_clo
  | Cut of {tp : tp; cut : cut * lazy_con ref option}
  | Zero
  | Suc of con
  | Pair of con * con
  | Refl of con
[@@deriving show]

and lazy_con = [`Do of con * frm list | `Done of con]
[@@deriving show]

and cut = hd * frm list 
[@@deriving show]

and tp =
  | Nat
  | Id of tp * con * con
  | Pi of tp * ze su tp_clo
  | Sg of tp * ze su tp_clo
[@@deriving show]

and hd =
  | Global of Symbol.t 
  | Var of int (* De Bruijn level *)
[@@deriving show]

and frm = 
  | KAp of nf
  | KFst 
  | KSnd
  | KNatElim of ze su tp_clo * con * ze su su tm_clo
  | KIdElim of ze su su su tp_clo * ze su tm_clo * tp * con * con
[@@deriving show]

and nf = Nf of {tp : tp; con : con} [@@deriving show]

let push frm (hd, sp) = 
  hd, sp @ [frm]

let mk_var tp lev = Cut {tp; cut = (Var lev, []), None}