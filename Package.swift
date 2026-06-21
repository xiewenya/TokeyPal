// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "tokeypal-mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokeyPalNative", targets: ["TokeyPalNativeApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.17.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "TokeyPalNative"
        ),
        .executableTarget(
            name: "TokeyPalNativeApp",
            dependencies: [
                "TokeyPalNative",
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder")
            ],
            resources: [
                .copy("UI/BrandIcons"),
                .copy("UI/OnboardingAssets")
            ]
        ),
        .testTarget(
            name: "TokeyPalNativeTests",
            dependencies: ["TokeyPalNative"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
