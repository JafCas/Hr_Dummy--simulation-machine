.PHONY: project open core-test test-iphone test-ipad

project:
	xcodegen generate

open: project
	open LocationSimulator.xcodeproj

core-test:
	swift test --package-path Packages/LocationSimCore

test-iphone: project
	xcodebuild test -project LocationSimulator.xcodeproj -scheme LocationSimulator \
		-destination "id=$$(scripts/pick-simulator.sh iPhone)" CODE_SIGNING_ALLOWED=NO

test-ipad: project
	xcodebuild test -project LocationSimulator.xcodeproj -scheme LocationSimulator \
		-destination "id=$$(scripts/pick-simulator.sh iPad)" CODE_SIGNING_ALLOWED=NO
