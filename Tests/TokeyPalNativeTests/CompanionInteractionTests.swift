import Testing
@testable import TokeyPalNative

@Test func companionTokenBubbleFormatsTodayTokens() {
    #expect(formatCompanionTokenBubble(0) == "Today 0 tokens")
    #expect(formatCompanionTokenBubble(1250) == "Today 1.3K tokens")
    #expect(formatCompanionTokenBubble(1_250_000) == "Today 1.3M tokens")
}

@Test func companionTransientActionReturnsToStaticAfterDelay() {
    var interaction = CompanionInteraction()

    let click = interaction.trigger("click")

    #expect(click == .playAction("click"))
    #expect(interaction.currentAction == "click")

    let timeout = interaction.animationTimeout()

    #expect(timeout == .clearAction)
    #expect(interaction.currentAction == nil)
}

@Test func companionInteractionCanClearCurrentActionExplicitly() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("hover") == .playAction("hover"))
    #expect(interaction.clearAction() == .clearAction)
    #expect(interaction.currentAction == nil)
    #expect(interaction.clearAction() == nil)
}

@Test func companionInteractionForceClearsAfterPriorityInterruption() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("idle") == .playAction("idle"))
    #expect(interaction.trigger("evolve") == .playAction("evolve"))
    #expect(interaction.clearAction() == .clearAction)
    #expect(interaction.currentAction == nil)
}

@Test func companionIdleDoesNotInterruptTransientActions() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("click") == .playAction("click"))
    #expect(interaction.trigger("idle") == nil)
    #expect(interaction.currentAction == "click")
}

@Test func companionSamePriorityDoesNotInterruptCurrentAction() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("hover") == .playAction("hover"))
    #expect(interaction.trigger("click") == nil)
    #expect(interaction.currentAction == "hover")
}

@Test func companionHigherPriorityInterruptsLowerPriorityAction() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("idle") == .playAction("idle"))
    #expect(interaction.trigger("hover") == .playAction("hover"))
    #expect(interaction.trigger("evolve") == .playAction("evolve"))
    #expect(interaction.currentAction == "evolve")
}

@Test func companionIgnoresUnknownActions() {
    var interaction = CompanionInteraction()

    #expect(interaction.trigger("sleep") == nil)
    #expect(interaction.currentAction == nil)
}
