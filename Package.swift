// swift-tools-version:5.5

/*
Copyright (c) 2018-present Creaceed SPRL and other CeedNumerics contributors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Creaceed SPRL nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL CREACEED SPRL BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


import PackageDescription

let package = Package(
	name: "Numerics",
	
	// this is for simplifying Float16 handling.
	platforms: [
		.macOS(.v11),
		.iOS(.v14),
		.macCatalyst(.v14),
		.tvOS(.v14)
	],
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "Numerics",
			targets: ["Numerics"]),
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		// .package(url: /* package url */, from: "1.0.0"),
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "Numerics",
			dependencies: ["Numerics_C"]
			// , swiftSettings: [SwiftSetting.unsafeFlags(["-O"])]
		),
		.target(
			name: "Numerics_C",
			dependencies: []
			// , cSettings: [CSetting.unsafeFlags(["-O2"])]
		),
		.testTarget(
			name: "NumericsTests",
			dependencies: ["Numerics"]),
	]
)
