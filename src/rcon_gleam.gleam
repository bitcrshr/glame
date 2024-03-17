import gleam/io
import gleam/bit_array
import packet
import rcon

pub fn main() {
  let assert Ok(_) = rcon.dial("127.0.0.1", 25_575, "password")
}
