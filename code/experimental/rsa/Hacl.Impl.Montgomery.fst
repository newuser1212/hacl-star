module Hacl.Impl.Montgomery

open FStar.HyperStack.All
open Spec.Lib.IntBuf.Lemmas
open Spec.Lib.IntBuf
open Spec.Lib.IntTypes
open FStar.Mul

open Hacl.Impl.Lib
open Hacl.Impl.Addition
open Hacl.Impl.Multiplication

module Buffer = Spec.Lib.IntBuf

val mod_inv_u64_:
  alpha:uint64 -> beta:uint64 -> uv:lbignum 2 -> Stack unit
  (requires (fun h -> live h uv))
  (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies1 uv h0 h1))
  [@ "substitute"]
let mod_inv_u64_ alpha beta uv =
  iteri_simple #uint64 #2 (size 64)
  (fun i uv ->
    let ub = uv.(size 0) in
    let vb = uv.(size 1) in
    let u_is_odd = u64 0 -. (ub &. u64 1) in
    let beta_if_u_is_odd = beta &. u_is_odd in
    uv.(size 0) <- add_mod #U64 (shift_right #U64 (ub ^. beta_if_u_is_odd) (u32 1)) (ub &. beta_if_u_is_odd);

    let alpha_if_u_is_odd = alpha &. u_is_odd in
    uv.(size 1) <- add_mod #U64 (shift_right #U64 vb (u32 1)) alpha_if_u_is_odd
  ) uv

val mod_inv_u64: n0:uint64 -> Stack uint64
  (requires (fun h -> True))
  (ensures (fun h0 _ h1 -> modifies0 h0 h1))
  [@"c_inline"]
let mod_inv_u64 n0 =
  let alpha = shift_left #U64 (u64 1) (u32 63) in
  let beta = n0 in
  alloc #uint64 #uint64 #2 (size 2) (u64 0) [] []
  (fun h0 _ h1 -> True)
  (fun uv ->
    uv.(size 0) <- u64 1;
    uv.(size 1) <- u64 0;
    mod_inv_u64_ alpha beta uv;
    uv.(size 1)
  )

val bn_mult_by_limb_addj_carry:
  #aLen:size_nat -> aaLen:size_t{v aaLen == aLen} -> a:lbignum aLen ->
  l:uint64 -> carry:uint64 -> i:size_t{v i <= aLen} -> j:size_t ->
  resLen:size_t{aLen + v j < v resLen} -> res:lbignum (v resLen) -> Stack uint64
  (requires (fun h -> live h a /\ live h res /\ disjoint res a))
  (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies1 res h0 h1))
  [@"c_inline"]
let rec bn_mult_by_limb_addj_carry #aLen aaLen a l carry i j resLen res =
  let ij = add #SIZE i j in
  if (i <. aaLen) then begin
    let res_ij = res.(ij) in
    let (carry', res_ij) = bn_mul_by_limb_addj_f a.(i) l carry res_ij in
    res.(ij) <- res_ij;
    bn_mult_by_limb_addj_carry aaLen a l carry' (add #SIZE i (size 1)) j resLen res end
  else begin
    let res_ij = res.(ij) in
    let (c', res_ij) = addcarry_u64 (u64 0) res_ij carry in
    res.(ij) <- res_ij;
    c' end

val mont_reduction_:
  #nLen:size_nat -> #rLen:size_nat{nLen < rLen} ->
  nnLen:size_t{v nnLen == nLen} ->
  rrLen:size_t{v rrLen == rLen /\ nLen + rLen < max_size_t} ->
  c:lbignum (nLen + rLen) -> n:lbignum nLen -> nInv_u64:uint64 ->
  i:size_t{v i < rLen}  -> Stack unit
    (requires (fun h -> live h c /\ live h n /\ disjoint c n))
    (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies1 c h0 h1))
  [@"c_inline"]
let rec mont_reduction_ #nLen #rLen nnLen rrLen c n nInv_u64 i =
  if (i <. nnLen) then begin
    let ci = c.(i) in
    let qi = mul_mod #U64 nInv_u64 ci in
    let carry = bn_mult_by_limb_addj_carry nnLen n qi (u64 0) (size 0) i (add #SIZE nnLen rrLen) c in
    let c_i1 = c.(add #SIZE (add #SIZE nnLen i) (size 1)) in
    c.(add #SIZE (add #SIZE nnLen i) (size 1)) <- add_mod #U64 c_i1 carry;
    mont_reduction_ nnLen rrLen c n nInv_u64 (add #SIZE i (size 1))
  end else begin
    let ci = c.(i) in
    let qi = mul_mod #U64 nInv_u64 ci in
    let carry = bn_mult_by_limb_addj_carry nnLen n qi (u64 0) (size 0) i (add #SIZE nnLen rrLen) c in ()
  end

val mont_reduction:
  #nLen:size_nat -> #rLen:size_nat{nLen < rLen} ->
  nnLen:size_t{v nnLen == nLen} ->
  rrLen:size_t{v rrLen == rLen /\ nLen + rLen < max_size_t} ->
  n:lbignum nLen -> nInv_u64:uint64 ->
  c:lbignum (nLen + nLen) -> tmp:lbignum (nLen + rLen) -> res:lbignum nLen ->
  Stack unit
    (requires (fun h -> live h n /\ live h c /\ live h tmp /\ live h res /\ disjoint tmp n))
    (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies2 res tmp h0 h1))
  [@"c_inline"]
let mont_reduction #nLen #rLen nnLen rrLen n nInv_u64 c tmp res =
  let nLen2 = add #SIZE nnLen nnLen in
  let tmp' = Buffer.sub #uint64 #(nLen +rLen) #(v nLen2) tmp (size 0) nLen2 in
  copy nLen2 c tmp';
  tmp.(nLen2) <- u64 0;
  mont_reduction_ nnLen rrLen tmp n nInv_u64 (size 0);
  //bn_rshift rLen2 tmp (mul #SIZE (size 64) rrLen) tmp; // tmp = tmp / r
  let tmp' = Buffer.sub #uint64 #(nLen + rLen) #nLen tmp rrLen nnLen in
  copy nnLen tmp' res

val to_mont:
  #nLen:size_nat -> #rLen:size_nat{nLen < rLen} ->
  nnLen:size_t{v nnLen == nLen} ->
  rrLen:size_t{v rrLen == rLen /\ nLen + rLen < max_size_t} ->
  pow2_i:size_t{2 * nLen + 4 * v pow2_i < max_size_t /\ nLen <= v pow2_i /\ rLen < 2 * v pow2_i} ->
  n:lbignum nLen -> nInv_u64:uint64 ->
  r2:lbignum nLen -> a:lbignum nLen ->
  st_kara:lbignum (2 * nLen + 4 * v pow2_i) -> aM:lbignum nLen ->
  Stack unit
    (requires (fun h -> live h n /\ live h r2 /\ live h a /\ live h aM /\ live h st_kara /\
                      disjoint st_kara a /\ disjoint st_kara r2 /\ disjoint st_kara n))
    (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies2 aM st_kara h0 h1))
  [@"c_inline"]
let to_mont #nLen #rLen nnLen rrLen pow2_i n nInv_u64 r2 a st_kara aM =
  let cLen = add #SIZE nnLen nnLen in
  let stLen = add #SIZE cLen (mul #SIZE (size 4) pow2_i) in
  let c = Buffer.sub #uint64 #(v stLen) #(v cLen) st_kara (size 0) cLen in
  karatsuba pow2_i nnLen a r2 st_kara; // c = a * r2
  let tmp = Buffer.sub #uint64 #(v stLen) #(nLen + rLen) st_kara cLen (add #SIZE nnLen rrLen) in
  assume (disjoint tmp n);
  let h0 = FStar.HyperStack.ST.get() in
  mont_reduction #nLen #rLen nnLen rrLen n nInv_u64 c tmp aM; // aM = c % n
  let h1 = FStar.HyperStack.ST.get() in
  assume (modifies2 aM st_kara h0 h1)

val from_mont:
  #nLen:size_nat -> #rLen:size_nat{nLen < rLen} ->
  nnLen:size_t{v nnLen == nLen} ->
  rrLen:size_t{v rrLen == rLen /\ nLen + rLen < max_size_t} ->
  pow2_i:size_t{2 * nLen + 4 * v pow2_i < max_size_t /\ nLen <= v pow2_i /\ rLen < 2 * v pow2_i} ->
  n:lbignum nLen -> nInv_u64:uint64 ->
  aM:lbignum nLen -> tmp:lbignum (nLen + rLen) -> a:lbignum nLen ->
  Stack unit
    (requires (fun h -> live h n /\ live h a /\ live h aM /\ live h tmp /\ disjoint tmp n))
    (ensures (fun h0 _ h1 -> preserves_live h0 h1 /\ modifies2 a tmp h0 h1))
  [@"c_inline"]
let from_mont #nLen #rLen nnLen rrLen pow2_i n nInv_u64 aM tmp a =
  let tmpLen = add #SIZE nnLen rrLen in
  fill tmpLen tmp (u64 0);
  let tmp' = Buffer.sub #uint64 #(v tmpLen) #nLen tmp (size 0) nnLen in
  copy nnLen aM tmp';
  mont_reduction_ nnLen rrLen tmp n nInv_u64 (size 0);
  //bn_rshift rLen2 tmp (mul #SIZE (size 64) rrLen) tmp; // tmp = tmp / r
  let tmp' = Buffer.sub #uint64 #(v tmpLen) #nLen tmp rrLen nnLen in
  copy nnLen tmp' a