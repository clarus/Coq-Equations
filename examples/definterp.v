Require Import Program.Basics Program.Tactics.
Require Import Equations.Equations.
Require Import Coq.Vectors.VectorDef.
Require Import List.
Import ListNotations.
Set Equations Transparent.

Derive Signature NoConfusion NoConfusionHom for t.

Inductive Ty : Set :=
| unit : Ty
| arrow (t u : Ty) : Ty
| ref : Ty -> Ty.

Derive NoConfusion for Ty.

Infix "⇒" := arrow (at level 80).

Definition Ctx := list Ty.

Reserved Notation " x ∈ s " (at level 70, s at level 10).

Inductive In {A} (x : A) : list A -> Type :=
| here {xs} : x ∈ (x :: xs)
| there {y xs} : x ∈ xs -> x ∈ (y :: xs)
where " x ∈ s " := (In x s).

Arguments here {A x xs}.
Arguments there {A x y xs} _.

Inductive Expr : Ctx -> Ty -> Set :=
| tt {Γ} : Expr Γ unit
| var {Γ} {t} : In t Γ -> Expr Γ t
| abs {Γ} {t u} : Expr (t :: Γ) u -> Expr Γ (t ⇒ u)
| app {Γ} {t u} : Expr Γ (t ⇒ u) -> Expr Γ t -> Expr Γ u
| new {Γ t} : Expr Γ t -> Expr Γ (ref t)
| deref {Γ t} : Expr Γ (ref t) -> Expr Γ t
| assign {Γ t} : Expr Γ (ref t) -> Expr Γ t -> Expr Γ unit.

Derive Signature NoConfusion NoConfusionHom for Expr.

Inductive All {A} (P : A -> Type) : list A -> Type :=
| all_nil : All P []
| all_cons {x xs} : P x -> All P xs -> All P (x :: xs).
Arguments all_nil {A} {P}.
Arguments all_cons {A P x xs} _ _.
Derive Signature NoConfusion NoConfusionHom for All.

Section MapAll.
  Context  {A} {P Q : A -> Type} (f : forall x, P x -> Q x).

  Equations map_all {l : list A} : All P l -> All Q l :=
  map_all all_nil := all_nil;
  map_all (all_cons p ps) := all_cons (f _ p) (map_all ps).
End MapAll.

Definition StoreTy := list Ty.

Inductive Val : StoreTy -> Ty -> Set :=
| val_unit {Σ} : Val Σ unit
| val_closure {Σ Γ t u} : Expr (t :: Γ) u -> All (Val Σ) Γ -> Val Σ (t ⇒ u)
| val_loc {Σ t} : t ∈ Σ -> Val Σ (ref t).

Derive Signature NoConfusion NoConfusionHom for Val.

Definition Env (Γ : Ctx) (Σ : StoreTy) : Set := All (Val Σ) Γ.

Definition Store (Σ : StoreTy) := All (Val Σ) Σ.

Equations lookup : forall {A P xs} {x : A}, All P xs -> x ∈ xs -> P x :=
  lookup (all_cons p _) here := p;
  lookup (all_cons _ ps) (there ins) := lookup ps ins.

Equations update : forall {A P xs} {x : A}, All P xs -> x ∈ xs -> P x -> All P xs :=
  update (all_cons p ps) here        p' := all_cons p' ps;
  update (all_cons p ps) (there ins) p' := all_cons p (update ps ins p').

Equations lookup_store {Σ t} : t ∈ Σ -> Store Σ -> Val Σ t :=
  lookup_store l σ := lookup σ l.

Equations update_store {Σ t} : t ∈ Σ -> Val Σ t -> Store Σ -> Store Σ :=
  update_store l v σ := update σ l v.
Import Sigma_Notations.

Definition store_incl (Σ Σ' : StoreTy) := &{ Σ'' : _ & Σ' = Σ ++ Σ'' }.
Infix "⊑" := store_incl (at level 10).

Section StoreIncl.
  Context {Σ Σ' : StoreTy} (incl : Σ ⊑ Σ').

  Lemma pres_in t : t ∈ Σ -> t ∈ Σ'.
  Proof. destruct incl. subst. induction 1. econstructor; auto.
         red in incl. destruct incl. apply List.app_inv_head in pr2. subst.
         constructor 2. simpl.
         apply IHIn. now exists pr0.
  Defined.

  Equations(noind) weaken_val {t} (v : Val Σ t) : Val Σ' t :=
   weaken_val val_unit := val_unit;
   weaken_val (val_closure b e) := val_closure b (map_all (fun t v => weaken_val v) e);
   weaken_val (val_loc H) := val_loc (pres_in _ H).

  Definition weaken_env {Γ} (v : Env Γ Σ) : Env Γ Σ' :=
    map_all (@weaken_val) v.

  Lemma trans_incl {Σ''} (incl' : Σ' ⊑ Σ'') : Σ ⊑ Σ''.
  Proof.
    destruct incl as [? ->], incl' as [? ->].
    exists (pr1 ++ pr0). now rewrite app_assoc.
  Qed.

End StoreIncl.

Infix "⊚" := trans_incl (at level 10).

Equations M : forall (Γ : Ctx) (P : StoreTy -> Set) (Σ : StoreTy), Type :=
  M Γ P Σ := forall (E : Env Σ Γ) (μ : Store Σ), option &{ Σ' : _ & Store Σ' * P Σ' * Σ ⊑ Σ'}.

Require Import Utf8.

Equations bind {Σ Γ} {P Q : StoreTy -> Type} (f : M Γ P Σ) (g : ∀ {Σ'}, P Σ' -> M Γ Q Σ') → M Γ Q Σ :=
  bind f g E μ := match m E μ with
                  | None => None
                  | Some (x => f x γ
              end.

Infix ">>=" := bind (at level 20, left associativity).

Equations ret : ∀ {Γ A}, A → M Γ A :=
  ret a γ := Some a.

Equations getEnv : ∀ {Γ}, M Γ (Env Γ) :=
  getEnv γ := Some γ.

Equations usingEnv : ∀ {Γ Γ' A}, Env Γ → M Γ A → M Γ' A :=
  usingEnv γ m γ' := m γ.

Equations timeout : ∀ {Γ A}, M Γ A :=
  timeout _ := None.

Equations eval : ∀ (n : nat) {Γ t} (e : Expr Γ t), M Γ (Val t) :=
  eval 0 _             := timeout;
  eval (S k) tt        := ret val_unit;
  eval (S k) (var x)   := getEnv >>= fun E => ret (lookup E x);
  eval (S k) (abs x)   := getEnv >>= fun E => ret (val_closure x E);
  eval (S k) (app (Γ:=Γ) f arg) := eval k f >>= (#{ | val_closure e' E =>
                                               eval k arg >>= fun a' => usingEnv (all_cons a' E) (eval k e')}).

Inductive eval_sem {Γ : Ctx} {env : Env Γ} : forall {t : Ty}, Expr Γ t -> Val t -> Prop :=
| eval_tt (e : Expr Γ unit) : eval_sem e val_unit
| eval_var t (i : t ∈ Γ) : eval_sem (var i) (lookup env i)
| eval_abs {t u} (b : Expr (t :: Γ) u) : eval_sem (abs b) (val_closure b env)
| eval_app {t u} (f : Expr Γ (t ⇒ u)) b' (a : Expr Γ t) v :
    eval_sem f (val_closure b' env) ->
    eval_sem a v ->
    forall u, @eval_sem (t :: Γ) (all_cons v env) _ b' u ->
    eval_sem (app f a) u.



Lemma eval_correct {n} Γ t (e : Expr Γ t) env v : eval n e env = Some v -> @eval_sem _ env _ e v.
Proof.
  pose proof (fun_elim (f:=eval)).
  specialize (H (fun n Γ t e m => forall env v, m env = Some v -> @eval_sem _ env _ e v)
                (fun n Γ t u f a v m => forall env v',
                     @eval_sem _ env _ f v -> m env = Some v' -> @eval_sem _ env _ (app f a) v')).
  rapply H; clear; intros.
  discriminate.
  noconf H. constructor.
  noconf H. constructor.

  noconf H. constructor.

  unfold bind in H1.
  destruct (eval n e0 env) eqn:Heq.
  specialize (H _ _ Heq).
  specialize (H0 v0 _ _ H H1). apply H0.
  discriminate.

  unfold bind in H2.
  destruct (eval k arg env) eqn:Heq.
  specialize (H _ _ Heq).
  unfold usingEnv in H2. specialize (H0 v (all_cons v a) v').
  econstructor; eauto.
Admitted.