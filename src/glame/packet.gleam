import gleam/string
import gleam/bytes_builder
import glame/errors

/// How many bytes the padding (i.e., <<0x00, 0x00>>) takes up
pub const packet_padding_size_bytes: Int = 2

/// How many bytes the header (i.e., id and type) takes up
pub const packet_header_size_bytes: Int = 8

/// Returns the size of a packet with an empty body
pub fn min_packet_size_bytes() -> Int {
  packet_padding_size_bytes + packet_header_size_bytes
}

/// Returns the maximum packet size supported by the RCON protocol.
pub fn max_packet_size_bytes() -> Int {
  4096 + min_packet_size_bytes()
}

/// Represents an RCON packet
pub type Packet {
  Packet(size: Int, id: Int, typ: Int, body: BitArray)
}

pub type PacketType {
  /// The first packet sent by the client, which is used to authenticate
  /// with the server.
  ServerDataAuth

  /// A notification of the connection's current auth status.
  ServerDataAuthResponse

  /// A packet sent by the client with a command to be executed by the server.
  ServerDataExecCommand

  /// A packet sent by the server with the result of a command.
  ServerDataResponseValue
}

/// Converts a {PacketType} to its integer representation.
pub fn packet_type_to_int(pt: PacketType) -> Int {
  case pt {
    ServerDataAuth -> 3
    ServerDataAuthResponse | ServerDataExecCommand -> 2
    ServerDataResponseValue -> 0
  }
}

/// Constructs a new {Packet}
pub fn new(
  packet_type: PacketType,
  packet_id: Int,
  body: String,
) -> Result(Packet, errors.Error) {
  let body_size = string.byte_size(body)
  let size = body_size + packet_header_size_bytes + packet_padding_size_bytes
  let max = max_packet_size_bytes()

  case size {
    _ if size > max -> Error(errors.BodyTooLarge(body_size))
    _ -> {
      let bytes =
        body
        |> bytes_builder.from_string()
        |> bytes_builder.to_bit_array()

      Ok(Packet(size, packet_id, packet_type_to_int(packet_type), bytes))
    }
  }
}

/// Constructs a {Packet} from a {BitArray}
pub fn from_bytes(bytes: BitArray) -> Result(Packet, errors.Error) {
  let min_ps = min_packet_size_bytes()

  case bytes {
    <<size:size(32)-little-int, rest:bits>> -> {
      case size {
        _ if size < min_ps -> {
          Error(errors.PacketSizeTooSmall(bytes, size))
        }
        _ -> {
          let body_size_bits =
            { size - packet_header_size_bytes - packet_padding_size_bytes } * 8

          case rest {
            <<
              id:int-size(32)-little,
              typ:int-size(32)-little,
              body:size(body_size_bits)-bits,
              0,
              0,
            >> -> {
              case typ {
                3 | 2 | 0 -> {
                  Ok(Packet(size, id, typ, body))
                }

                _ -> Error(errors.InvalidPacketType(bytes, typ))
              }
            }

            _ -> {
              Error(errors.InvalidPacketStructure(bytes))
            }
          }
        }
      }
    }

    _ -> Error(errors.InvalidPacketStructure(bytes))
  }
}

/// Serializes a {Packet} to a {BitArray}
pub fn to_bytes(packet: Packet) -> BitArray {
  bytes_builder.new()
  |> bytes_builder.append(<<packet.size:int-size(32)-little>>)
  |> bytes_builder.append(<<packet.id:int-size(32)-little>>)
  |> bytes_builder.append(<<packet.typ:int-size(32)-little>>)
  |> bytes_builder.append(packet.body)
  |> bytes_builder.append(<<0x00, 0x00>>)
  |> bytes_builder.to_bit_array()
}
