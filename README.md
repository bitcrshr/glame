# glame 🎮

[![Package Version](https://img.shields.io/hexpm/v/glame)](https://hex.pm/packages/glame)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glame/)


A client implementation of the [Source RCON Protocol](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol),
inpsired by [gorcon](https://github.com/gorcon/rcon).

## Adding to your project

```sh
gleam add glame
```

## Usage

```gleam
import gleam/io
import gleam/option.{None}
import gleam/string
import glame

pub fn main() {
  case glame.dial("127.0.0.1", 25_575, "password", None, None) {
    Ok(conn) -> {
      case glame.execute(conn, "ShowPlayers") {
        Ok(res) -> io.println(res)

        Error(e) -> io.println(string.inspect(e))
      }
    }

    Error(e) -> io.println(string.inspect(e))
  }
}
```
