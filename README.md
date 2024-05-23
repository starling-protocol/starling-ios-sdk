# Starling IOS SDK

To build the SDK, the [Starling protocol](https://github.com/starling-protocol/starling) must first be compiled for iOS
using the following [Gomobile](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile) command.

```sh
$ gomobile bind -target=ios -prefix=Proto -o ./StarlingProtocol.xcframework github.com/starling-protocol/starling/mobile
```

The produced `StarlingProtocol.xcframework` must be placed at `./Starling/StarlingProtocol.xcframework`.
