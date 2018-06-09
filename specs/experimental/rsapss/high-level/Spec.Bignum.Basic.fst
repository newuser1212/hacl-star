module Spec.Bignum.Basic

open FStar.Mul
open Spec.Lib.IntTypes
open Spec.Lib.IntSeq
open Spec.Lib.RawIntTypes

open FStar.Math.Lemmas

let bignum bits = n:nat{n < pow2 bits}
let bn_v #n b = b

val bn:#n:size_pos -> a:nat{a < pow2 n} -> b:bignum n{bn_v b == a}
let bn #n b = b

let bn_const_1 #n =
  assert_norm (1 < pow2 n);
  bn 1

let bn_const_0 #n =
  assert_norm (0 < pow2 n);
  bn 0

let bn_cast_le #n m b = bn #m b
let bn_cast_gt #n m b = bn #m b

val lemma_bn_add:#n:size_pos -> #m:size_pos{n >= m} -> a:bignum n -> b:bignum m -> Lemma
  (bn_v a + bn_v b < pow2 (n + 1))
let lemma_bn_add #n #m a b =
  pow2_le_compat n m;
  assert (bn_v a + bn_v b < pow2 n + pow2 n);
  pow2_double_sum n

let bn_add #n #m a b =
  lemma_bn_add #n #m a b;
  assert (a + b < pow2 (n + 1));
  let res = (a + b) % pow2 n in
  let c = (a + b) / pow2 n in
  lemma_div_lt (a + b) (n + 1) n;
  (u8 c, bn #n res)

let bn_add_carry #n #m a b =
  let res = a + b in
  lemma_bn_add #n #m a b;
  bn res

let bn_sub #n #m a b = a - b

val lemma_bn_mul:#n:size_pos -> #m:size_pos -> a:bignum n -> b:bignum m -> Lemma
  (bn_v a * bn_v b < pow2 (n + m))
let lemma_bn_mul #n #m a b =
  pow2_plus n m

let bn_mul #n #m a b =
  lemma_bn_mul #n #m a b;
  bn #(n+m) (a * b)

let bn_get_bit #n b i = (b / pow2 i) % 2
let bn_get_bits #n b i j = (b / pow2 i) % pow2 (j - i)

#reset-options "--z3rlimit 30 --max_fuel 2"
let bn_rshift #n x i =
  assert (x < pow2 n);
  lemma_div_lt x n i;
  x / (pow2 i)

let bn_to_u64 b = u64 b
let bn_from_u64 c = bn #64 (uint_to_nat c)

let bn_is_less #n #m x y = x < y

val lemma_bn_lshift_mul_add:
  #n:size_pos -> #m:size_pos -> x:bignum n -> i:size_nat -> y:bignum 64 -> z:bignum m -> Lemma
  (requires (n + i + 64 <= m))
  (ensures (bn_v x * pow2 i * bn_v y + bn_v z < pow2 (m + 1)))
  #reset-options "--z3rlimit 30 --max_fuel 0"
let lemma_bn_lshift_mul_add #n #m x i y z =
  assert (bn_v x * pow2 i * bn_v y < pow2 n * pow2 i * pow2 64);
  pow2_plus n i;
  pow2_plus (n + i) 64;
  assert (bn_v x * pow2 i * bn_v y + bn_v z < pow2 (n + i + 64) + pow2 m);
  pow2_le_compat m (n + i + 64);
  pow2_double_sum m

let bn_lshift_mul_add #n #m x i y z =
  lemma_bn_lshift_mul_add #n #m x i y z;
  let res = x * pow2 i * y + z in
  assert (res < pow2 (m + 1));
  let r = res % pow2 m in
  let c = res / pow2 m in
  lemma_div_lt res (m + 1) m;
  (u8 c, bn #m r)

val lemma_bn_lshift_add:
  #n:size_pos -> #m:size_pos -> x:bignum n -> i:size_nat -> z:bignum m -> Lemma
  (requires (n + i <= m))
  (ensures (bn_v x * pow2 i + bn_v z < pow2 (m + 1)))
  #reset-options "--z3rlimit 30 --max_fuel 0"
let lemma_bn_lshift_add #n #m x i z =
  assert (bn_v x * pow2 i < pow2 n * pow2 i);
  pow2_plus n i;
  assert (bn_v x * pow2 i+ bn_v z < pow2 (n + i) + pow2 m);
  pow2_le_compat m (n + i);
  pow2_double_sum m

let bn_lshift_add #n #m x i z =
  lemma_bn_lshift_add #n #m x i z;
  let res = x * pow2 i + z in
  assert (res < pow2 (m + 1));
  let r = res % pow2 m in
  let c = res / pow2 m in
  lemma_div_lt res (m + 1) m;
  (u8 c, bn #m r)

let bn_from_bytes_be #bBytes b =
  let res = nat_from_bytes_be b in
  bn #(8*bBytes) res

let bn_to_bytes_be #bBits n =
  assume (n < pow2 (8 * (blocks bBits 8)));
  nat_to_bytes_be (blocks bBits 8) n

let bn_pow2_r_mod #nBits n r = (pow2 r) % n