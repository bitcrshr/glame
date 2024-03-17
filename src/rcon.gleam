import gleam/string
import gleam/bit_array
import mug
import birl/duration
import packet

pub type Connection {
  Connection(sock: mug.Socket)
}

pub fn dial(
  host: String,
  port: Int,
  password: String,
) -> Result(Connection, String) {
  let sock_result =
    mug.new(host, port)
    |> mug.connect()

  case sock_result {
    Ok(sock) -> {
      let conn = Connection(sock)

      case auth(conn, password) {
        Ok(_) -> Ok(conn)

        Error(e) -> Error(e)
      }
    }

    Error(e) -> Error(string.inspect(e))
  }
}

pub fn execute(conn: Connection, cmd: String) -> Result(String, String) {
  let cmd_len = string.length(cmd)
  case cmd_len {
    0 -> Error("cmd cannot be empty")
    _ if cmd_len > 4096 -> Error("cmd cannot be larger than 4096 bytes")
    _ -> {
      case write(conn, packet.ServerDataExecCommand, 3, cmd) {
        Ok(_) -> {
          case read(conn) {
            Ok(pkt) -> {
              case bit_array.to_string(pkt.body) {
                Ok(body) -> Ok(body)

                Error(_) -> Error("failed to read body as string")
              }
            }

            Error(e) -> Error(e)
          }
        }

        Error(e) -> Error(e)
      }
    }
  }
}

fn auth(conn: Connection, password: String) -> Result(Nil, String) {
  case write(conn, packet.ServerDataAuth, 2, password) {
    Ok(_) -> {
      case read(conn) {
        Ok(pkt) -> {
          let size = pkt.size - packet.packet_header_size_bytes

          case size {
            _ if size < 0 -> {
              Error("Invalid")
            }

            _ -> {
              case pkt.typ {
                0 -> {
                  // SERVERDATA_RESPONSE_VALUE
                  case read(conn) {
                    Ok(p) -> {
                      validate_auth_response(p, 2)
                    }

                    Error(e) -> Error(e)
                  }
                }

                _ -> {
                  validate_auth_response(pkt, 2)
                }
              }
            }
          }
        }

        Error(e) -> Error(e)
      }
    }

    Error(e) -> Error(e)
  }
}

fn validate_auth_response(
  pkt: packet.Packet,
  auth_id: Int,
) -> Result(Nil, String) {
  case pkt.typ {
    2 -> {
      case pkt.id {
        -1 -> Error("auth failed")
        _ if pkt.id == auth_id -> Ok(Nil)
        got ->
          Error(
            "invalid auth packet response id. wanted 2, got "
            <> string.inspect(got),
          )
      }
    }

    got ->
      Error(
        "auth response had wrong type. wanted"
        <> string.inspect(auth_id)
        <> ", got "
        <> string.inspect(got),
      )
  }
}

fn write(
  conn: Connection,
  packet_type: packet.PacketType,
  packet_id: Int,
  cmd: String,
) -> Result(Nil, String) {
  case packet.new(packet_type, packet_id, cmd) {
    Ok(pkt) -> {
      let bytes = packet.to_bytes(pkt)

      case mug.send(conn.sock, bytes) {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(string.inspect(e))
      }
    }

    Error(e) -> Error(e)
  }
}

fn read(conn: Connection) -> Result(packet.Packet, String) {
  case mug.receive(conn.sock, default_timeout()) {
    Ok(bytes) -> {
      packet.from_bytes(bytes)
    }

    Error(e) -> Error(string.inspect(e))
  }
}

fn default_timeout() -> Int {
  duration.seconds(5)
  |> duration.blur_to(duration.MilliSecond)
}
