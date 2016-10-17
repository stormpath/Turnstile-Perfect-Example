import PackageDescription

let package = Package(
  name: "PerfectAuth",
  targets: [],
  dependencies: [
    .Package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", majorVersion:2),
    .Package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", majorVersion:2),
    .Package(url: "https://github.com/stormpath/Turnstile-Perfect.git", majorVersion:0, minor: 2)
    ]
)
