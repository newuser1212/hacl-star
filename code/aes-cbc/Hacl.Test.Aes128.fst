module Hacl.Test.Aes128
open FStar.HyperStack.All

#set-options "--lax"

open LowStar.Buffer

val main: unit -> ST C.exit_code
  (requires (fun h -> True))
  (ensures  (fun h0 r h1 -> True))
let main () =
  push_frame();
  let input = alloca_of_list [0x6buy;0xc1uy;0xbeuy;0xe2uy;0x2euy;0x40uy;0x9fuy;0x96uy;0xe9uy;0x3duy;0x7euy;0x11uy;0x73uy;0x93uy;0x17uy;0x2auy] in
  let key = alloca_of_list
[0x2buy;0x7euy;0x15uy;0x16uy;0x28uy;0xaeuy;0xd2uy;0xa6uy;0xabuy;0xf7uy;0x15uy;0x88uy;0x09uy;0xcfuy;0x4fuy;0x3cuy] in
  let iv = alloca_of_list
[0x00uy;0x01uy;0x02uy;0x03uy;0x04uy;0x05uy;0x06uy;0x07uy;0x08uy;0x09uy;0x0Auy;0x0Buy;0x0Cuy;0x0Duy;0x0Euy;0x0Fuy] in
  let cip = alloca_of_list
[0x76uy;0x49uy;0xabuy;0xacuy;0x81uy;0x19uy;0xb2uy;0x46uy;0xceuy;0xe9uy;0x8euy;0x9buy;0x12uy;0xe9uy;0x19uy;0x7duy] in
  let comp = alloca 0uy 32ul in
  Hacl.Aes128.aes128_cbc_encrypt comp key iv input 16ul;
  C.String.(print (of_literal "computed aes-cbc:\n"));
  C.print_bytes comp 32ul;
  C.String.(print (of_literal "\nexpected aes-cbc:\n"));
  C.print_bytes cip 32ul;
  pop_frame();
  C.EXIT_SUCCESS
