import Testing
@testable import TokeyPalNative

@Test func dashboardLifecycleLoadsHiddenUntilReady() {
    var lifecycle = DashboardLifecycle()

    #expect(lifecycle.isCreated == false)

    let firstOpen = lifecycle.open()

    #expect(firstOpen == [.createHidden, .load])
    #expect(lifecycle.isCreated == true)
    #expect(lifecycle.isVisible == false)

    let ready = lifecycle.ready()

    #expect(ready == [.show])
    #expect(lifecycle.isVisible == true)
}

@Test func dashboardLifecycleReusesWindowBeforeIdleTimeout() {
    var lifecycle = DashboardLifecycle()
    _ = lifecycle.open()
    _ = lifecycle.ready()

    let close = lifecycle.close()

    #expect(close == [.hide, .scheduleDestroy])
    #expect(lifecycle.isCreated == true)
    #expect(lifecycle.isVisible == false)

    let reopen = lifecycle.open()

    #expect(reopen == [.cancelDestroy, .show])
    #expect(lifecycle.isCreated == true)
    #expect(lifecycle.isVisible == true)
}

@Test func dashboardLifecycleDestroysWindowAfterIdleTimeout() {
    var lifecycle = DashboardLifecycle()
    _ = lifecycle.open()
    _ = lifecycle.ready()
    _ = lifecycle.close()

    let timeout = lifecycle.idleTimeout()

    #expect(timeout == [.destroy])
    #expect(lifecycle.isCreated == false)
    #expect(lifecycle.isVisible == false)

    let reopen = lifecycle.open()

    #expect(reopen == [.createHidden, .load])
}
