import mug

pub type Error {
  /// The packet size was less than 10
  PacketSizeTooSmall(packet: BitArray, body_size: Int)

  /// The body was larger than 4096 bytes
  BodyTooLarge(size: Int)

  /// Body was empty when trying to execute command
  BodyEmpty

  /// Body was not able to be parsed as a UTF-8
  BodyNotUTF8(body_bytes: BitArray)

  /// The packet was not terminated by <<0x00, 0x00>>
  InvalidPacketPadding(packet: BitArray)

  /// The packet type was not 0, 2, or 3
  InvalidPacketType(packet: BitArray, typ: Int)

  /// The packet could not be parsed as an RCON packet.
  InvalidPacketStructure(packet: BitArray)

  /// An error occurred at the socket level.
  SocketError(e: mug.Error)

  /// A response did not have the expected id
  WrongResponseId(wanted: Int, got: Int)

  /// A response did not have the expected type
  WrongResponseType(wanted: Int, got: Int)

  /// Server responded with an id of -1 indicating that auth failed.
  /// Likely an invalid password
  AuthFailed
}
