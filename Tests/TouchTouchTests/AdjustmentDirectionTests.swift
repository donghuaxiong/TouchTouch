import Testing
@testable import TouchTouch

struct AdjustmentDirectionTests {
    @Test func reversedDirectionSwapsIncreaseAndDecrease() {
        #expect(AdjustmentDirection.increase.reversed == .decrease)
        #expect(AdjustmentDirection.decrease.reversed == .increase)
    }
}
