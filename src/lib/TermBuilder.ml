open CoolBasis

exception CFHM
exception CCHM
exception CJHM

module S = Syntax

module M : sig
  include Monad.S

  val scope : (S.t m -> 'a m) -> 'a m
  val run : tplen:int -> conlen:int-> 'a m -> 'a
  val lvl : int -> S.t m
  val tplvl : int -> S.tp m

  val test : S.t m -> unit
end =
struct
  type local = {tplen : int; conlen : int}
  type token = {lvl : int}

  type 'a m = local -> 'a

  let ret a : _ m =
    fun _ -> a

  let bind m f : _ m =
    fun loc ->
    let x = m loc in
    f x loc

  let var tok : _ m =
    fun loc ->
    S.Var (loc.conlen - tok.lvl - 1)

  let tpvar tok : _ m =
    fun loc ->
    S.TpVar (loc.tplen - tok.lvl - 1)

  let lvl l = var {lvl = l}
  let tplvl l = tpvar {lvl = l}

  let scope (k : S.t m -> 'a m) : 'a m =
    fun loc ->
    let tok = {lvl = loc.conlen} in
    k (var tok) {loc with conlen = loc.conlen + 1}

  let run ~tplen ~conlen m =
    m {tplen; conlen}

  let test m =
    let tm = run ~tplen:0 ~conlen:0 m in
    Format.printf
      "@[<v>Testing:@ %a@]@."
      (S.pp Pp.Env.emp) tm
end


include M
open Monad.Notation (M)
module MU = Monad.Util (M)

type 'a b = S.t m -> 'a m

let el_in m : _ m =
  let+ tm = m in
  S.ElIn tm

let el_out m : _ m =
  let+ tm = m in
  S.ElOut tm

let lam ?(ident = `Anon) mbdy : _ m =
  scope @@ fun var ->
  let+ bdy = mbdy var in
  S.Lam (ident, bdy)

let rec ap m0 ms : _ m =
  match ms with
  | [] -> m0
  | m1 :: ms ->
    let* x0 = m0 in
    let* x1 = m1 in
    ap (ret (S.Ap (x0, x1))) ms

let coe mline mr ms mbdy =
  let+ line = mline
  and+ r = mr
  and+ s = ms
  and+ bdy = mbdy in
  S.Coe (line, r, s, bdy)


let hcom mcode mr ms mphi mbdy =
  let+ code = mcode
  and+ r = mr
  and+ s = ms
  and+ phi = mphi
  and+ bdy = mbdy in
  S.HCom (code, r, s, phi, bdy)

let com mline mr ms mphi mbdy =
  let+ line = mline
  and+ r = mr
  and+ s = ms
  and+ phi = mphi
  and+ bdy = mbdy in
  S.Com (line, r, s, phi, bdy)


let let_ ?(ident = `Anon) m k : _ m =
  let+ t = m
  and+ bdy = scope k in
  S.Let (t, ident, bdy)

let pair m0 m1 =
  let+ x0 = m0
  and+ x1 = m1 in
  S.Pair (x0, x1)

let fst m =
  let+ x = m in
  S.Fst x

let snd m =
  let+ x = m in
  S.Snd x

let cof_abort =
  ret S.CofAbort

let cof_split mtp mbranches =
  let mphis, mtms = List.split mbranches in
  let+ tp = mtp
  and+ phis = MU.commute_list mphis
  and+ tms = MU.map scope mtms in
  S.CofSplit (tp, List.combine phis tms)

let sub_out mtm =
  let+ tm = mtm in
  S.SubOut tm

let sub_in mtm =
  let+ tm = mtm in
  S.SubIn tm

let univ : _ m =
  ret S.Univ

let nat : _ m =
  ret S.Nat

let code_nat =
  ret S.CodeNat

let nat_elim mmot mzero msuc mscrut =
  let+ mot = mmot
  and+ zero = mzero
  and+ suc = msuc
  and+ scrut = mscrut in
  S.NatElim (mot, zero, suc, scrut)


let zero =
  ret S.Zero

let suc m =
  let+ x = m in
  S.Suc x

let pi ?(ident = `Anon) mbase mfam : _ m =
  let+ base = mbase
  and+ fam = scope mfam in
  S.Pi (base, ident, fam)

let sg ?(ident = `Anon) mbase mfam : _ m =
  let+ base = mbase
  and+ fam = scope mfam in
  S.Sg (base, ident, fam)

let sub mbase mphi mbdry =
  let+ base = mbase
  and+ phi = mphi
  and+ bdry = scope mbdry in
  S.Sub (base, phi, bdry)

let el mcode : _ m =
  let+ code = mcode in
  S.El code

let tp_prf mphi =
  let+ phi = mphi in
  S.TpPrf phi

let prf =
  ret S.Prf


let eq mr ms =
  let+ r = mr
  and+ s = ms in
  S.Cof (Cof.Eq (r, s))

let join mphis =
  let+ phis = MU.commute_list mphis in
  S.Cof (Cof.Join phis)

let meet mphis =
  let+ phis = MU.commute_list mphis in
  S.Cof (Cof.Meet phis)

let forall mphi =
  let+ phi = scope mphi in
  S.ForallCof phi

let tp_dim = ret S.TpDim
let dim0 = ret S.Dim0
let dim1 = ret S.Dim1

let boundary mr =
  join [eq mr dim0; eq mr dim1]

let box mr ms mphi msides mcap =
  let+ r = mr
  and+ s = ms
  and+ phi = mphi
  and+ sides = msides
  and+ cap = mcap in
  S.Box (r, s, phi, sides, cap)

let cap mr ms mphi mcode mbox =
  let+ r = mr
  and+ s = ms
  and+ phi = mphi
  and+ code = mcode
  and+ box = mbox in
  S.Cap (r, s, phi, code, box)




module Kan =
struct
  type coe = r:S.t m -> r':S.t m -> bdy:S.t m -> S.t m
  type hcom = r:S.t m -> r':S.t m -> phi:S.t m -> bdy:S.t m -> S.t m

  let coe_pi ~base_line ~fam_line ~r ~r' ~bdy : _ m =
    el_in @@
    lam @@ fun arg ->
    let_ (lam @@ fun i -> coe base_line r' i arg) @@ fun coe_base_line ->
    let fib_line = lam @@ fun i -> ap fam_line [i; ap coe_base_line [i]] in
    coe fib_line r r' @@
    ap (el_out bdy) [ap coe_base_line [r]]

  let hcom_pi ~base ~fam ~r ~r' ~phi ~bdy : _ m =
    el_in @@
    lam @@ fun arg ->
    let tfib = ap fam [arg] in
    hcom tfib r r' phi @@
    lam @@ fun i ->
    lam @@ fun prf ->
    ap (el_out (ap bdy [i; prf])) [arg]

  let coe_sg ~base_line ~fam_line ~r ~r' ~bdy : _ m =
    let fst_line = lam @@ fun i -> coe base_line r i @@ fst @@ el_out bdy in
    let fib_line = lam @@ fun i -> ap fam_line [i; ap fst_line [i]] in
    el_in @@
    pair
      (ap fst_line [r'])
      (coe fib_line r r' @@ snd @@ el_out bdy)

  let hcom_sg ~base ~fam ~r ~r' ~phi ~bdy : _ m =
    let p0_line =
      lam @@ fun i ->
      hcom base r i phi @@
      lam @@ fun j ->
      lam @@ fun prf ->
      fst @@ el_out @@ ap bdy [j; prf]
    in
    let p0 = ap p0_line [r'] in
    let fib_line =
      lam @@ fun i ->
      ap fam [ap p0_line [i]]
    in
    let p1 =
      com fib_line r r' phi @@
      lam @@ fun i ->
      lam @@ fun prf ->
      snd @@ el_out @@ ap bdy [i; prf]
    in
    el_in @@
    pair p0 p1


  let coe_path ~(fam_line : S.t m) ~(bdry_line : S.t m) ~(r : S.t m) ~(r' : S.t m) ~(bdy : S.t m) : S.t m =
    el_in @@
    lam @@ fun j ->
    sub_in @@
    let_ (boundary j) @@ fun d_j ->
    com (lam @@ fun i -> ap fam_line [i; j]) r r' d_j @@
    lam @@ fun i ->
    lam @@ fun _ ->
    cof_split
      (el @@ ap fam_line [i; j])
      [ d_j, (fun q -> ap bdry_line [i; j; q])
      ; eq i r, (fun q -> sub_out @@ ap (el_out bdy) [j])
      ]

  let hcom_path ~fam ~bdry ~r ~r' ~phi ~bdy =
    el_in @@
    lam @@ fun i ->
    sub_in @@
    let_ (boundary i) @@ fun d_i ->
    let_ (ap fam [i]) @@ fun fam_i ->
    hcom fam_i r r' (join [phi; d_i]) @@
    lam @@ fun k ->
    lam @@ fun p ->
    cof_split
      (el fam_i)
      [ d_i , (fun q -> ap bdry [i; q])
      ; join [phi; eq k r] , (fun q -> sub_out (ap (el_out (ap bdy [k;q])) [i]))
      ]

  module FHCom :
  sig
    type fhcom_u = {r : S.t m; r' : S.t m; phi : S.t m; bdy : S.t m}
    val hcom_fhcom : fhcom:fhcom_u -> r:S.t m -> r':S.t m -> phi:S.t m -> bdy:S.t m -> S.t m
    val coe_fhcom : fhcom:fhcom_u -> r:S.t m -> r':S.t m -> bdy:S.t m -> S.t m
  end =
  struct
    type fhcom_u = {r : S.t m; r' : S.t m; phi : S.t m; bdy : S.t m}

    let hcom_fhcom ~(fhcom : fhcom_u) ~(r : S.t m) ~(r' : S.t m) ~(phi : S.t m) ~(bdy : S.t m) : S.t m =
      let_ ~ident:(`Machine "O")
        begin
          lam ~ident:(`Machine "i") @@ fun i ->
          lam @@ fun _ ->
          cap fhcom.r fhcom.r' fhcom.phi fhcom.bdy @@ ap bdy [i; prf]
        end
      @@ fun o_tilde ->
      let_ ~ident:(`Machine "P")
        begin
          lam ~ident:(`Machine "i") @@ fun i ->
          lam @@ fun _ ->
          hcom (ap fhcom.bdy [fhcom.r'; prf]) r i phi bdy
        end
      @@ fun p_tilde ->
      box fhcom.r fhcom.r' fhcom.phi (lam @@ fun _ -> ap p_tilde [r'; prf]) @@
      hcom (ap fhcom.bdy [fhcom.r; prf]) r r' (join [phi; fhcom.phi; eq fhcom.r fhcom.r']) @@
      lam ~ident:(`Machine "i") @@ fun i ->
      lam @@ fun _ ->
      cof_split
        (el @@ ap fhcom.bdy [fhcom.r'; prf])
        [ join [eq i r; phi],
          (fun _ -> ap o_tilde [i; prf])
        ; fhcom.phi,
          (fun _ -> coe (lam ~ident:(`Machine "j") @@ fun j -> ap fhcom.bdy [j; prf]) fhcom.r' fhcom.r (ap p_tilde [i; prf]))
        ; eq fhcom.r fhcom.r',
          (fun _ -> ap p_tilde [i; prf])
        ]

    (* [fhcom] below is an fhcom of binders; so you need to write [ap fhcom.r [r]] etc. *)
    let coe_fhcom ~(fhcom : fhcom_u) ~(r : S.t m) ~(r' : S.t m) ~(bdy : S.t m) : S.t m =
      let s_ x = ap fhcom.r [x] in
      let s'_ x = ap fhcom.r' [x] in
      let psi_ x = ap fhcom.phi [x] in
      let code_ x = ap fhcom.bdy [x] in
      box (s_ r') (s'_ r') (psi_ r')
        (raise CFHM)
        begin
          hcom (code_ r') (s_ r') (s'_ r') (join [psi_ r'; eq r r']) @@
          lam @@ fun i ->
          lam @@ fun _ ->
          cof_split (el @@ code_ r')
            [eq i (s_ r'), raise CFHM;
             psi_ r', raise CFHM;
             eq r r', raise CFHM]
            (* I think the r=r' and i = s_r' branches can be combined *)
        end
  end
end

module Test =
struct
  let closed_form =
    lam ~ident:(`Machine "s") @@ fun h_r ->
    lam ~ident:(`Machine "s'") @@ fun h_r' ->
    lam ~ident:(`Machine "ψ") @@ fun h_phi ->
    lam ~ident:(`Machine "A") @@ fun h_bdy ->
    lam ~ident:(`Machine "r") @@ fun r ->
    lam ~ident:(`Machine "r'") @@ fun r' ->
    lam ~ident:(`Machine "φ") @@ fun phi ->
    lam ~ident:(`Machine "M") @@ fun bdy ->
    Kan.FHCom.hcom_fhcom ~fhcom:{r = h_r; r' = h_r'; phi = h_phi; bdy = h_bdy} ~r ~r' ~phi ~bdy

  let print_example () =
    test closed_form
end
