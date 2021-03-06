(**********************************************************************)
(* Equations                                                          *)
(* Copyright (c) 2009-2015 Matthieu Sozeau <matthieu.sozeau@inria.fr> *)
(**********************************************************************)
(* This file is distributed under the terms of the                    *)
(* GNU Lesser General Public License Version 2.1                      *)
(**********************************************************************)

From Equations Require Import Init Signature DepElim EqDec.

(** Alternative implementation of generalization using sigma types only,
   allowing to use K on decidable domains. *)

(** Decompose existential packages. *)

(* Definition sigT_elim {A} {P : A -> Type} {P0 : sigma _ P -> Type} : *)
(*   (forall (x : A) (p : P x), P0 (sigmaI P x p)) -> forall s, P0 s := sigma_rect P0. *)

Ltac decompose_exists id := hnf in id ;
  match type of id with
    | sigma _ _ => let xn := fresh id "'" in 
      destruct id as [xn id]; decompose_exists xn; 
        cbv beta delta [ pr1 pr2 ] iota in id;
          decompose_exists id
    | _ => cbv beta delta [ pr1 pr2 ] iota in id
  end.

(** Dependent generalization using existentials only. *)

Ltac generalize_sig id cont :=
  let id' := fresh id in
  get_signature_pack id id';
  hnf in (value of id'); hnf in (type of id');
  match goal with
  | |- context[ id ] =>
    generalize (@eq_refl _ id' : id' = id') ;
    unfold id' at 1;
    clearbody id'; simpl in id'; move id' after id;
    revert_until id'; rename id' into id;
      cont id
  | |- _ =>
    let id'1 := fresh id' in let id'2 := fresh id' in
    set (id'2 := pr2 id'); set (id'1 := pr1 id') in id'2;
    hnf in (value of id'1), (value of id'2);
    generalize (@eq_refl _ id'1 : id'1 = id'1);
    unfold id'1 at 1; clearbody id'2 id'1;
    clear id' id; compute in id'2;
    rename id'2 into id;
      cont id'1
  end.

(* Ltac generalize_sig id cont := *)
(*   (* Check if goal is dependent or not. *) *)
(*   match goal with *)
(*   | |- _ => try (try (clear id; gfail 1); fail 1); *)
(*     let id' := fresh id in *)
(*     get_signature_pack id id'; *)
(*     hnf in (value of id'), (type of id'); *)
(*     let id'1 := fresh id' in let id'2 := fresh id' in *)
(*     set (id'2 := pr2 id'); set (id'1 := pr1 id') in id'2; *)
(*     hnf in (value of id'1), (value of id'2), (type of id'2); *)
(*     generalize (@eq_refl _ id'1 : id'1 = id'1); *)
(*     unfold id'1 at 1; clearbody id'2 id'1; *)
(*     clear id' id; rename id'2 into id; *)
(*     unfold projT2, projT1 in id; *)
(*       cont id'1 *)
(*   | |- _ => *)
(*     let id' := fresh id in *)
(*     get_signature_pack id id'; *)
(*     hnf in (value of id'), (type of id'); *)
(*     generalize (@eq_refl _ id' : id' = id') ; *)
(*     unfold id' at 1; *)
(*     clearbody id'; simpl in id'; move id' after id; *)
(*     revert_until id'; rename id' into id; *)
(*       cont id *)
(*   end. *)

Ltac generalize_sig_dest id :=
  generalize_sig id ltac:(fun id => decompose_exists id).

Ltac generalize_eqs_sig id :=
  (needs_generalization id ; generalize_sig_dest id) || idtac.

Ltac generalize_eqs_vars_sig id :=
  generalize_eqs_sig id.

Ltac generalize_by_eqs id ::= generalize_eqs_sig id.
Ltac generalize_by_eqs_vars id ::= generalize_eqs_vars_sig id.

(** Any signature made up entirely of decidable types is decidable. *)

Instance eqdec_sig {A} {B : A -> Type} `(EqDec A) `(forall a, EqDec (B a)) : EqDec { x : A & B x }.
Proof.
  intros. intros x y. decompose_exists x. decompose_exists y.
  case (eq_dec x' y'). simpdep. case (eq_dec x y). simpdep. left. reflexivity.
  intros. right. red. simpdep. apply n. auto.
  intros. right. red. simpdep. apply n. auto.
Defined.
