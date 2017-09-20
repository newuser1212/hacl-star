(**
   TODO: - Documentation, some cleanup.
*)
module Box.ODH
open FStar.Set
open FStar.HyperHeap
open FStar.HyperStack
open FStar.HyperStack.ST
open FStar.Monotonic.RRef
open FStar.Seq
open FStar.Monotonic.Seq
open FStar.List.Tot

open Crypto.Symmetric.Bytes

open Box.Flags
open Box.Key
open Box.Index
open Box.Plain

module MR = FStar.Monotonic.RRef
module MM = MonotoneMap
module HS = FStar.HyperStack
module HH = FStar.HyperHeap
module HSalsa = Spec.HSalsa20
module Curve = Spec.Curve25519
module Plain = Box.Plain
module Key = Box.Key
module ID = Box.Index
module LE = FStar.Endianness

let hash_length' = HSalsa.keylen
let dh_share_length' = Curve.serialized_point_length // is equal to scalar lenght in Spec.Curve25519
let dh_exponent_length' = Curve.scalar_length // Size of scalar in Curve25519. Replace with constant in spec?

//let dh_exponent = Curve.scalar // is equal to Curve.serialized_point

let smaller' n i1 i2 =
  let i1' = LE.little_endian i1 in
  let i2' = LE.little_endian i2 in
  i1' < i2'

let share_from_exponent' dh_exp = Curve.scalarmult dh_exp Curve.base_point

noeq abstract type pkey' =
  | PKEY: pk_share:dh_share' dh_share_length' -> pkey'

noeq abstract type skey' =
  | SKEY: sk_exp:dh_exponent' dh_exponent_length' -> pk:pkey'{pk.pk_share = share_from_exponent'  sk_exp} -> skey'

let skey = skey'
let pkey = pkey'


let get_hash_length om = om.hash_length
let get_dh_share_length om = om.dh_share_length
let get_dh_exponent_length om = om.dh_share_length

let get_index_module om = om.im
let get_key_index_module om = om.kim
let get_key_module om = om.km

private let zero_nonce = Seq.create HSalsa.noncelen (UInt8.uint_to_t 0)
let hash om input = HSalsa.hsalsa20 input zero_nonce
#set-options "--z3rlimit 300 --max_ifuel 0 --max_fuel 0"
let total_order_lemma om i1 i2 = admit()

//val total_order_lemma': (i1:dh_share -> i2:dh_share -> Lemma
//  (requires True)
//  (ensures
//    (b2t (smaller i1 i2) ==> (forall i. i <> i1 /\ i <> i2 /\ b2t (smaller i i1) ==> b2t (smaller i i2)))
//    /\ (~ (b2t (smaller i1 i2)) <==> (i1 = i2 \/ b2t (smaller i2 i1)))))


(**
Nonce to use with HSalsa.hsalsa20.
*)

let share_from_exponent om dh_exp = Curve.scalarmult dh_exp Curve.base_point
let dh_exponentiate om dh_exp dh_sh = Curve.scalarmult dh_exp dh_sh

let create hash_len dh_share_len dh_exp_len im kim km rgn =
  ODH rgn hash_len dh_share_len dh_exp_len im kim km

let get_pkey om sk = sk.pk

#set-options "--z3rlimit 300 --max_ifuel 1 --max_fuel 0"
let compatible_keys om sk pk =
  sk.pk =!= pk

let pk_get_share om k = k.pk_share

let lemma_pk_get_share_inj om pk = ()

let get_skeyGT om sk =
  sk.sk_exp

let sk_get_share om sk = sk.pk.pk_share

#set-options "--z3rlimit 300 --max_ifuel 1 --max_fuel 0"
let leak_skey om sk =
  sk.sk_exp

let keygen om =
  let dh_exponent = random_bytes (UInt32.uint_to_t 32) in
  let dh_pk = PKEY (share_from_exponent om dh_exponent) in
  let dh_sk = SKEY dh_exponent dh_pk in
  dh_pk,dh_sk

let coerce_pkey om dh_sh =
  PKEY dh_sh

let coerce_keypair om dh_ex =
  let dh_sh = share_from_exponent om dh_ex in
  let pk = PKEY dh_sh in
  let sk = SKEY dh_ex pk in
  pk,sk

let compose_ids om s1 s2 =
  if smaller om s1 s2 then
     let i = (s1,s2) in
     i
  else
    (total_order_lemma om s1 s2;
    let i = (s2,s1) in
    i)

let prf_odhGT om sk pk =
  let raw_k = Curve.scalarmult sk.sk_exp pk.pk_share in
  let k = HSalsa.hsalsa20 raw_k zero_nonce in
  k

let lemma_shares om sk = ()


let prf_odh om sk pk =
  let i1 = pk.pk_share in
  let i2 = sk.pk.pk_share in
  let i = compose_ids om i1 i2 in
  recall_log om.im;
  recall_log om.kim;
  lemma_honest_or_dishonest om.kim i;
  let honest_i = get_honest om.kim i in
  match honest_i && Flags.prf_odh with
  | true ->
    let k = Key.gen om.kim om.km i in
    k
  | false ->
    let raw_k = Curve.scalarmult sk.sk_exp pk.pk_share in
    let hashed_raw_k = HSalsa.hsalsa20 raw_k zero_nonce in
    if not honest_i then
      Key.coerce om.kim om.km i hashed_raw_k
    else
      Key.set om.kim om.km i hashed_raw_k
