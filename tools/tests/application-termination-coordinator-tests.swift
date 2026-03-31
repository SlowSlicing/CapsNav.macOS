import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

@MainActor
private func runApplicationTerminationCoordinatorTests() {
    var events: [String] = []

    let coordinator = ApplicationTerminationCoordinator(
        cleanup: {
            events.append("cleanup")
        },
        terminate: {
            events.append("terminate")
        }
    )

    coordinator.requestTermination()
    expect(events == ["cleanup", "terminate"], "requestTermination 应先 cleanup 再 terminate")

    coordinator.applicationWillTerminate()
    expect(events == ["cleanup", "terminate"], "applicationWillTerminate 不应重复 cleanup")

    events.removeAll()

    let secondCoordinator = ApplicationTerminationCoordinator(
        cleanup: {
            events.append("cleanup")
        },
        terminate: {
            events.append("terminate")
        }
    )

    secondCoordinator.applicationWillTerminate()
    secondCoordinator.requestTermination()
    expect(events == ["cleanup", "terminate"], "先收到 willTerminate 后再 requestTermination，也只应 cleanup 一次")

    print("ApplicationTerminationCoordinator tests passed")
}

@main
enum ApplicationTerminationCoordinatorTestsMain {
    @MainActor
    static func main() {
        runApplicationTerminationCoordinatorTests()
    }
}
