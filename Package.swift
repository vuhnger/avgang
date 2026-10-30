// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Avgang",
  platforms: [.macOS("26.0")],
  products: [.executable(name: "Avgang", targets: ["Avgang"])],
  dependencies: [
    .package(
      url: "https://github.com/sparkle-project/Sparkle",
      exact: "2.10.1"
    )
  ],
  targets: [
    .target(name: "AvgangCore"),
    .executableTarget(
      name: "Avgang",
      dependencies: ["AvgangCore", .product(name: "Sparkle", package: "Sparkle")]),
    .testTarget(
      name: "AvgangCoreTests", dependencies: ["AvgangCore"], resources: [.copy("Fixtures")]),
  ],
  swiftLanguageModes: [.v6]
)
