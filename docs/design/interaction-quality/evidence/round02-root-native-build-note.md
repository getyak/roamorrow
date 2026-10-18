# Round02 parent native build checkpoint

Primary iPhone 17 Pro / iOS26.5, Xcode26.6, arm64 Debug build-for-testing exited0.
Source: efcb8fc5 plus parent CompanionPostActionService/discovery sheets, Today/CityOS/score badge changes present before the build. Pi route/voice/content changes were not imported. Not a final-source build. Since then the service error enum visibility and one409 regression test changed; those later test changes are not included in this build.

First affected XCTest attempt did not enter test cases. Xcode reported NSMachErrorDomain -308, IDELaunchiPhoneSimulatorLauncher server died, after392978ms launch. Resource pressure was also observed (swap17GiB/free24.5GiB); causality is not established. Parent requested termination of its own dev-ios-session PID28773 only. This is not a passing test run; no current screenshot/click evidence is claimed. The final integration requires another build/test after accepting the Pi changes. Historic03/04b/05 evidence stays separate.
