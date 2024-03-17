import gleam/string
import gleam/bit_array
import mug
import birl/duration
import packet
import errors

pub type Connection {
  Connection(sock: mug.Socket)
}

pub fn dial(
  host: String,
  port: Int,
  password: String,
) -> Result(Connection, errors.Error) {
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

    Error(e) -> Error(errors.SocketError(e))
  }
}

pub fn execute(conn: Connection, cmd: String) -> Result(String, errors.Error) {
  let cmd_len = string.length(cmd)
  case cmd_len {
    0 -> Error(errors.BodyEmpty)
    _ if cmd_len > 4096 -> Error(errors.BodyTooLarge(cmd_len))
    _ -> {
      case write(conn, packet.ServerDataExecCommand, 3, cmd) {
        Ok(_) -> {
          case read(conn) {
            Ok(pkt) -> {
              case bit_array.to_string(pkt.body) {
                Ok(body) -> Ok(body)

                Error(_) -> Error(errors.BodyNotUTF8(pkt.body))
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

fn auth(conn: Connection, password: String) -> Result(Nil, errors.Error) {
  case write(conn, packet.ServerDataAuth, 2, password) {
    Ok(_) -> {
      case read(conn) {
        Ok(pkt) -> {
          case pkt.typ {
            0 -> {
              // Some servers will send an empty SERVERDATA_RESPONSE_VALUE packet
              // immediately followed by an auth response, so we need to discard the first
              // packet if necessary
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

        Error(e) -> Error(e)
      }
    }

    Error(e) -> Error(e)
  }
}

fn validate_auth_response(
  pkt: packet.Packet,
  auth_id: Int,
) -> Result(Nil, errors.Error) {
  case pkt.typ {
    2 -> {
      case pkt.id {
        -1 -> Error(errors.AuthFailed)
        _ if pkt.id == auth_id -> Ok(Nil)
        got -> Error(errors.WrongResponseId(auth_id, got))
      }
    }

    got -> Error(errors.WrongResponseType(2, got))
  }
}

fn write(
  conn: Connection,
  packet_type: packet.PacketType,
  packet_id: Int,
  cmd: String,
) -> Result(Nil, errors.Error) {
  case packet.new(packet_type, packet_id, cmd) {
    Ok(pkt) -> {
      let bytes = packet.to_bytes(pkt)

      case mug.send(conn.sock, bytes) {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(errors.SocketError(e))
      }
    }

    Error(e) -> Error(e)
  }
}

fn read(conn: Connection) -> Result(packet.Packet, errors.Error) {
  case mug.receive(conn.sock, default_timeout()) {
    Ok(bytes) -> {
      packet.from_bytes(bytes)
    }

    Error(e) -> Error(errors.SocketError(e))
  }
}

fn default_timeout() -> Int {
  duration.seconds(5)
  |> duration.blur_to(duration.MilliSecond)
}
