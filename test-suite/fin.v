Require Import Program Equations.Equations.

Inductive ilist (A : Set) : nat -> Set :=
| Nil : ilist A 0
| Cons : forall {n}, A -> ilist A n -> ilist A (S n).
Arguments Nil [A].
Arguments Cons [A n _ _].

Inductive fin : nat -> Set :=
| fz : forall {n}, fin (S n)
| fs : forall {n}, fin n -> fin (S n).

Equations fin_to_nat {n : nat} (i : fin n) : nat :=
fin_to_nat fz := 0;
fin_to_nat (fs j) := S (fin_to_nat j).

Lemma fin_lt_n : forall (n : nat) (i : fin n), fin_to_nat i < n.
Proof.
  intros. funelim (fin_to_nat i).
    - apply Le.le_n_S; apply Le.le_0_n.
    - apply Lt.lt_n_S; assumption.
Defined.

Equations nat_to_fin {n : nat} (m : nat) (p : m < n) : fin n :=
nat_to_fin {n:=(S n)} 0 _ := fz;
nat_to_fin {n:=(S n)} (S m) _ := fs (nat_to_fin m _).
Next Obligation. apply Lt.lt_S_n; assumption. Defined.

(*
Equations fin_to_nat {n : nat} (i : fin n) : {m : nat | m < n} :=
fin_to_nat _ fz := exist _ 0 _;
fin_to_nat _ (fs j) := let (m, p) := fin_to_nat j in exist _ (S m) _.
Next Obligation. apply Le.le_n_S; apply Le.le_0_n. Defined.
Next Obligation. apply Lt.lt_n_S; assumption. Defined.

(*
Equations nat_to_fin {n : nat} (m : nat) (p : m < n) : fin n :=
nat_to_fin (S n) 0 _ := fz;
nat_to_fin (S n) (S m) _ := fs (nat_to_fin m _).
Next Obligation. apply Lt.lt_S_n; assumption. Defined.
*)


Equations nat_to_fin {n : nat} (m : {m : nat | m < n}) : fin n :=
nat_to_fin 0 m :=! m;
nat_to_fin (S n) (exist ?(fun m => m < S n) 0 _) := fz;
nat_to_fin (S n) (exist ?(fun m => m < S n) (S m) _) := fs (nat_to_fin (exist _ m _)).
*)
(*
nat_to_fin (S n) m <= proj1_sig m => {
  nat_to_fin (S n) m 0 := fz;
  nat_to_fin (S n) m (S m') := fs (nat_to_fin (exist _ m' _))
}.
Obligation Tactic := idtac.
Next Obligation. intros.
*)
(*
nat_to_fin (S n) m <= m => {
  nat_to_fin (S n) m (exist _ 0 _) := fz;
  nat_to_fin (S n) m (exist _ (S m') _) := fs (nat_to_fin (exist _ m' _ ))
}.
*)

Lemma fin__nat : forall (n : nat) (m : nat) (p : m < n),
  fin_to_nat (nat_to_fin m p) = m.
Proof.
  intros.
  funelim (fin_to_nat (nat_to_fin m p));
  funelim (nat_to_fin m p).
    - reflexivity.
    - inversion H1.
    - inversion H1.
    - clear H. f_equal. inversion H2. apply inj_pair2 in H4. subst. apply H1; reflexivity.
Qed.

Lemma nat__fin : forall (n : nat) (i : fin n),
  nat_to_fin (fin_to_nat i) (fin_lt_n n i) = i.
Proof.
  intros.
  funelim (nat_to_fin (fin_to_nat i) (fin_lt_n n i));
  funelim (fin_to_nat i).
    - reflexivity.
    - inversion H1.
    - inversion H1.
    - clear H. unfold nat_to_fin_obligation_1 in *. f_equal.
        simp fin_to_nat in H2. depelim H2.
        replace (Lt.lt_S_n (fin_to_nat f) n p) with (fin_lt_n n f) in * by (apply proof_irrelevance).
        apply H1; reflexivity.
Qed.

Equations iget {A : Set} {n : nat} (l : ilist A n) (i : fin n) : A :=
iget (Cons x _) fz := x;
iget (Cons _ t) (fs j) := iget t j.

Equations isnoc {A : Set} {n : nat} (l : ilist A n) (x : A) : ilist A (S n) :=
isnoc Nil x := Cons x Nil;
isnoc (Cons y t) x := Cons y (isnoc t x).

Lemma append_get : forall (A : Set) (n : nat) (l : ilist A n) (x : A),
  iget (isnoc l x) (nat_to_fin n (Lt.lt_n_Sn n)) = x.
Proof.
  induction n ; intros.
    - depelim l. simp isnoc nat_to_fin iget.
    - depelim l. simp isnoc nat_to_fin iget.
      unfold nat_to_fin_obligation_1.
      replace (Lt.lt_S_n n (S n) (Lt.lt_n_Sn (S n))) with (Lt.lt_n_Sn n) by (apply proof_irrelevance).
      apply IHn.
Qed.

Definition convert_ilist {A : Set} {n m : nat} (p : n = m) (l : ilist A n) : ilist A m.
Proof. rewrite <- p. assumption. Defined.

Lemma convert_ilist_trans : forall {A : Set} {n m o : nat} (p : n = m) (r : m = o) (l : ilist A n),
  convert_ilist r (convert_ilist p l) = convert_ilist (eq_trans p r) l.
Proof. intros. simplify_eqs. reflexivity. Qed.

Equations irev_aux {A : Set} {i j : nat} (l : ilist A i) (acc : ilist A j) : ilist A (i + j) :=
irev_aux Nil acc := acc;
irev_aux (Cons x t) acc := convert_ilist _ (irev_aux t (Cons x acc)).

Program Definition irev {A : Set} {n : nat} (l : ilist A n) : ilist A n := irev_aux l Nil.

Ltac match_refl :=
match goal with
| [ |- context[ match ?P with _ => _ end ] ] => rewrite UIP_refl with (p := P)
end.

Example rev_ex : forall (A : Set) (x y : A), irev (Cons x (Cons y Nil)) = Cons y (Cons x Nil).
Proof.
  intros.
  unfold irev; simp irev_aux.
  compute; repeat match_refl; reflexivity.
Qed.

Equations iapp {A : Set} {n m : nat} (l1 : ilist A n) (l2 : ilist A m) : ilist A (n + m) :=
iapp Nil l := l;
iapp (Cons x t) l := Cons x (iapp t l).


Lemma iapp_cons : forall (A : Set) (i j : nat) (l1 : ilist A i) (l2 : ilist A j) (x : A),
  iapp (Cons x l1) l2 = Cons x (iapp l1 l2).
Proof. simp iapp. Qed.

Program Definition rev_aux_app_stmt := forall (A : Set) (i j1 j2 : nat) (l : ilist A i)
  (acc1 : ilist A j1) (acc2 : ilist A j2),
  convert_ilist _ (irev_aux l (iapp acc1 acc2)) = iapp (irev_aux l acc1) acc2.
Next Obligation. auto with arith. Defined.

Lemma rev_aux_app : rev_aux_app_stmt.
Proof.
  unfold rev_aux_app_stmt.
  intros.
  funelim (irev_aux l acc1).
    - simp irev_aux iapp. compute; match_refl; reflexivity.
    - simp irev_aux iapp. rewrite convert_ilist_trans.
      rewrite <- iapp_cons.
Admitted.

Equations irev' {A : Set} {n : nat} (l : ilist A n) : ilist A n :=
irev' Nil := Nil;
irev' (Cons x t) := isnoc (irev' t) x.

Lemma rev__rev' : forall (A : Set) (i : nat) (l : ilist A i), irev l = irev' l.
Proof.
  intros.
  funelim (irev' l); unfold irev; simplify_eqs; simp irev_aux.
  unfold eq_rect. unfold irev_aux_obligation_1. unfold eq_sym.
Admitted.

Equations rev_range (n : nat) : ilist nat n :=
rev_range 0 := Nil;
rev_range (S n) := Cons n (rev_range n).

Equations(noind) negb (b : bool) : bool :=
negb true := false;
negb false := true.

Inductive fle : forall {n}, fin n -> fin n -> Prop :=
| flez : forall {n j}, @fle (S n) fz j
| fles : forall {n i j}, fle i j -> @fle (S n) (fs i) (fs j).

Equations fin0_empty (i : fin 0) : False :=
fin0_empty i :=! i.

Lemma fle_trans' : forall n (j i k : fin n), fle i j -> fle j k -> fle i k.
Proof.
  induction j; intros.
    - depelim H. constructor.
    - depelim H0; depelim H; constructor. apply IHj; assumption.
Qed.

Derive NoConfusion for fin.

Equations(nocomp noind) fle_trans {n : nat} {i j k : fin n} (p : fle i j) (q : fle j k) : fle i k :=
fle_trans flez _ := flez;
fle_trans (fles p') (fles q') := fles (fle_trans p' q').
