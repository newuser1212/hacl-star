module Spec.Hash

open FStar.Mul
open Spec.Lib.IntTypes
open Spec.Lib.IntSeq

#reset-options "--max_fuel 0 --z3rlimit 25"

type algorithm =
  | SHA2_224
  | SHA2_256
  | SHA2_384
  | SHA2_512

(* Definition of the abstract state *)
val state: a:algorithm -> Type0

(* Functions to access algorithm parameters *)
(* Enforcing some constraints propagated from HMAC and HKDF *)
val size_block: a:algorithm -> n:size_nat{n <> 0}
val size_hash: a:algorithm -> s:size_nat{0 < s /\ s < size_block a /\ s + size_block a <= max_size_t /\ 255 * s <= max_size_t}
val max_input: a:algorithm -> n:nat{size_hash a + size_block a < n}

(* Ghost function to reveal the content of the abstract state to the post-conditions *)
val get_st_n: #a:algorithm -> state a -> GTot (size_nat)
val get_st_len_block: #a:algorithm -> state a -> GTot (l:size_nat{l < size_block a})
val number_blocks_padding_single: a:algorithm -> len:size_nat{len < size_block a} -> GTot size_nat


(* State initialization for Incremental APIs *)
val init: a:algorithm -> Tot (state a)

(* Block incremental API *)
val update_block: a:algorithm -> block:lbytes (size_block a) -> (st:state a{(get_st_n st + 1) * (size_block a) <= max_input a /\ get_st_n st + 1 <= max_size_t}) -> Tot (state a)
val update_multi: a:algorithm -> n:size_nat{n * (size_block a) <= max_size_t} -> blocks:lbytes (n * (size_block a)) -> (st:state a{get_st_n st + n <= max_size_t}) -> Tot (state a)
val update_last: a:algorithm -> len:size_nat -> last:lbytes len -> (st:state a{len < size_block a /\ (get_st_n st * size_block a) + len <= max_size_t}) -> Tot (state a)
val finish: a:algorithm -> st:state a -> Tot (lbytes (size_hash a))

(* Bytes incremental API *)
val update': a:algorithm -> len:size_nat -> input:lbytes len -> (st:state a{let n = len / (size_block a) in get_st_n st + n + 1 <= max_size_t}) -> Tot (state a)
val finish': a:algorithm -> (st:state a{get_st_n st + (number_blocks_padding_single a (get_st_len_block st)) <= max_size_t}) -> Tot (lbytes (size_hash a))

(* Hash function onetime *)
val hash: a:algorithm -> len:size_nat{len < max_input a} -> input:lbytes len -> Tot (lbytes (size_hash a))
