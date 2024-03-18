import gleeunit
import gleeunit/should
import packet

pub fn main() {
  gleeunit.main()
}

pub fn new_packet_test() {
  let pkt_res = packet.new(packet.ServerDataResponseValue, 42, "testdata")
  pkt_res
  |> should.be_ok()

  let assert Ok(pkt) = pkt_res

  pkt.body
  |> should.equal(<<"testdata":utf8>>)

  pkt.size
  |> should.equal(
    8 + packet.packet_header_size_bytes + packet.packet_padding_size_bytes,
  )
}

pub fn from_bytes_test() {
  let bytes = <<
    11:int-size(32)-little, 5:int-size(32)-little, 3:int-size(32)-little,
    "h":utf8, 0x00, 0x00,
  >>

  let pkt_res = packet.from_bytes(bytes)
  pkt_res
  |> should.be_ok()

  let assert Ok(pkt) = pkt_res

  pkt.body
  |> should.equal(<<"h":utf8>>)

  pkt.id
  |> should.equal(5)

  pkt.typ
  |> should.equal(3)

  pkt.size
  |> should.equal(11)
}

pub fn to_bytes_test() {
  let assert Ok(pkt) = packet.new(packet.ServerDataResponseValue, 42, "test")

  let expected = <<
    14:int-size(32)-little, 42:int-size(32)-little, 0:int-size(32)-little,
    "test":utf8, 0, 0,
  >>

  packet.to_bytes(pkt)
  |> should.equal(expected)
}
