import Foundation
import Testing
import HouseholdCore

/// The counterparts of the web app's Unpaid Balance tests, and Card-Paid Bills. The clock is
/// `.testing`: September 15, 2026 in New York.
@Suite("Credit card Dues, Unpaid Balance and Card-Paid Bills")
struct CreditCardTests {
    /// September 2026 with Visa at 5000.00, not yet Paid, Mastercard and City Power with no Amount,
    /// and the `others` Bills.
    func september(with others: (Household) -> [NewBill] = { _ in [] }) throws -> Household {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.visa(in: household))
        try household.addBill(.mastercard(in: household))
        try household.addBill(.cityPower(in: household))
        for bill in others(household) {
            try household.addBill(bill)
        }
        try household.enterAmount(Decimal(string: "5000.00"), on: try household.due(named: "Visa").id, by: "Mircea")
        return household
    }

    @Test("the Dues of the Bills in the Credit Cards Category are credit card Dues, and take a Paid Amount")
    func creditCardsCategoryDuesTakeAPaidAmount() throws {
        var household = try september()
        let board = try household.openBillingMonth(.september)

        #expect(household.categories[2].isCreditCards)
        #expect(!household.categories[0].isCreditCards && !household.categories[1].isCreditCards)
        #expect(board.takesPaidAmount(try household.due(named: "Visa")))
        #expect(board.takesPaidAmount(try household.due(named: "Mastercard")))
        #expect(!board.takesPaidAmount(try household.due(named: "City Power")))
    }

    @Test("paying part of a credit card Due marks it Paid and leaves an Unpaid Balance")
    func payingPartLeavesAnUnpaidBalance() throws {
        var household = try september()

        try household.markPaid(try household.due(named: "Visa").id, paying: Decimal(string: "1000.00"), by: "Mircea")

        let visa = try household.due(named: "Visa")
        let paid = try #require(visa.paid)
        #expect(paid.by == "Mircea")
        #expect(paid.at == WallClock.testing.now)
        #expect(paid.paidAmount == Decimal(string: "1000.00"))
        #expect(visa.unpaidBalance == Decimal(string: "4000.00"))
    }

    @Test(
        "paying the whole Amount, more, nothing or leaving the Paid Amount empty is a full payment",
        arguments: [Decimal(string: "5000.00"), Decimal(string: "6000.00"), 0, nil]
    )
    func aFullPayment(paidAmount: Decimal?) throws {
        var household = try september()

        try household.markPaid(try household.due(named: "Visa").id, paying: paidAmount, by: "Mircea")

        let visa = try household.due(named: "Visa")
        #expect(visa.paid != nil)
        #expect(visa.paid?.paidAmount == nil)
        #expect(visa.unpaidBalance == 0)
    }

    @Test("a Paid Amount on a credit card Due without an Amount is a full payment")
    func aPaidAmountWithoutAnAmountIsAFullPayment() throws {
        var household = try september()

        try household.markPaid(
            try household.due(named: "Mastercard").id, paying: Decimal(string: "100.00"), by: "Mircea"
        )

        let mastercard = try household.due(named: "Mastercard")
        #expect(mastercard.paid != nil)
        #expect(mastercard.paid?.paidAmount == nil)
        #expect(mastercard.unpaidBalance == 0)
    }

    @Test("only credit card Dues take a Paid Amount")
    func onlyCreditCardDuesTakeAPaidAmount() throws {
        var household = try september()
        let cityPower = try household.due(named: "City Power")
        try household.enterAmount(Decimal(string: "200.00"), on: cityPower.id, by: "Mircea")

        try household.markPaid(cityPower.id, paying: Decimal(string: "50.00"), by: "Mircea")

        let paid = try household.due(named: "City Power")
        #expect(paid.paid != nil)
        #expect(paid.paid?.paidAmount == nil)
        #expect(paid.unpaidBalance == 0)
    }

    @Test("a Paid Amount below zero is refused with a readable message and the Due is not Paid")
    func aNegativePaidAmountIsRefused() throws {
        var household = try september()
        let visa = try household.due(named: "Visa")

        let refusal = #expect(throws: DueRefusal.negativePaidAmount) {
            try household.markPaid(visa.id, paying: -1, by: "Mircea")
        }

        #expect(refusal?.localizedDescription == "Paid Amount must be 0 or more")
        #expect(try household.due(named: "Visa").paid == nil)
    }

    @Test("Edit takes the Paid Amount away")
    func editTakesThePaidAmountAway() throws {
        var household = try september()
        let visa = try household.due(named: "Visa")
        try household.markPaid(visa.id, paying: Decimal(string: "1000.00"), by: "Mircea")

        try household.undoPaid(visa.id)

        let edited = try household.due(named: "Visa")
        #expect(edited.paid == nil)
        #expect(edited.unpaidBalance == 0)
    }

    @Test("the Paid Amount changes only by Edit and marking Paid again")
    func thePaidAmountChangesOnlyByEditAndMarkingPaidAgain() throws {
        var household = try september()
        let visa = try household.due(named: "Visa")
        try household.markPaid(visa.id, paying: Decimal(string: "1000.00"), by: "Mircea")

        try household.markPaid(visa.id, paying: Decimal(string: "2000.00"), by: "Ana")
        #expect(try household.due(named: "Visa").paid?.paidAmount == Decimal(string: "1000.00"))

        try household.undoPaid(visa.id)
        try household.markPaid(visa.id, paying: Decimal(string: "2000.00"), by: "Ana")
        #expect(try household.due(named: "Visa").unpaidBalance == Decimal(string: "3000.00"))
    }

    @Test("the Amount of a Due with a Paid Amount cannot be changed until Edit")
    func theAmountIsLockedUntilEdit() throws {
        var household = try september()
        let visa = try household.due(named: "Visa")
        try household.markPaid(visa.id, paying: Decimal(string: "1000.00"), by: "Mircea")

        #expect(throws: DueRefusal.paidNotEditable) {
            try household.enterAmount(Decimal(string: "5100.00"), on: visa.id, by: "Mircea")
        }
        #expect(try household.due(named: "Visa").unpaidBalance == Decimal(string: "4000.00"))

        try household.undoPaid(visa.id)
        try household.enterAmount(Decimal(string: "800.00"), on: visa.id, by: "Mircea")
        #expect(try household.due(named: "Visa").amount == Decimal(string: "800.00"))
    }

    @Test("the month's Unpaid Balance sums every credit card Due paid for less than its Amount")
    func theMonthsUnpaidBalanceSumsTheCards() throws {
        var household = try september { [.homeDepot(in: $0, defaultAmount: Decimal(string: "900.00"))] }
        try household.markPaid(try household.due(named: "Visa").id, paying: Decimal(string: "1000.00"), by: "Mircea")
        let mastercard = try household.due(named: "Mastercard")
        try household.enterAmount(Decimal(string: "3000.00"), on: mastercard.id, by: "Mircea")
        try household.markPaid(mastercard.id, paying: Decimal(string: "1000.00"), by: "Mircea")
        try household.markPaid(try household.due(named: "Home Depot").id, by: "Mircea")

        #expect(try household.openBillingMonth(.september).unpaidBalance == Decimal(string: "6000.00"))
    }

    @Test("the month's Unpaid Balance shows no warning when every card was paid in full")
    func theMonthsUnpaidBalanceIsZeroWhenPaidInFull() throws {
        var household = try september()
        try household.markPaid(try household.due(named: "Visa").id, by: "Mircea")

        #expect(try household.openBillingMonth(.september).unpaidBalance == nil)
    }

    @Test("Unpaid Remaining drops a Due with a Paid Amount, whatever its Unpaid Balance")
    func unpaidRemainingDropsADueWithAPaidAmount() throws {
        var household = try september()
        let before = try household.openBillingMonth(.september).unpaidRemaining

        try household.markPaid(try household.due(named: "Visa").id, paying: Decimal(string: "1000.00"), by: "Mircea")

        let board = try household.openBillingMonth(.september)
        #expect(board.unpaidRemaining.amount == before.amount - 5000)
        #expect(board.unpaidRemaining.withoutAmount == before.withoutAmount)
        #expect(board.state(of: try household.due(named: "Visa")) == .paid)
    }

    @Test("the next Billing Month's Due starts with no Amount and no Paid Amount, whatever the Unpaid Balance")
    func theUnpaidBalanceIsNeverCarriedToTheNextMonth() throws {
        var household = try september()
        try household.markPaid(try household.due(named: "Visa").id, paying: Decimal(string: "1000.00"), by: "Mircea")

        let october = try household.due(named: "Visa", in: .october)

        #expect(october.amount == nil)
        #expect(october.paid == nil)
        #expect(october.unpaidBalance == 0)
        #expect(try household.openBillingMonth(.october).unpaidBalance == nil)
        #expect(try household.openBillingMonth(.september).unpaidBalance == Decimal(string: "4000.00"))
    }

    @Test("Unpaid Remaining leaves out Card-Paid Dues, even when they are not Paid")
    func unpaidRemainingLeavesOutCardPaidDues() throws {
        var household = try september { household in
            var homeDepot = NewBill.homeDepot(in: household, defaultAmount: nil)
            homeDepot.isCardPaid = true
            return [.danceStudio(in: household), homeDepot]
        }
        let danceStudio = try household.due(named: "Dance Studio")
        #expect(danceStudio.isCardPaid)
        #expect(danceStudio.paid == nil)

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        // Visa 5000.00; Mastercard and City Power without an Amount. Dance Studio's 200.00 and Home
        // Depot's missing Amount are left out.
        #expect(remaining == UnpaidRemaining(amount: try #require(Decimal(string: "5000.00")), withoutAmount: 2))
    }

    @Test("clearing Card-Paid leaves the Dues already generated Card-Paid and later ones not")
    func clearingCardPaidLeavesExistingDues() throws {
        var household = try september { [.danceStudio(in: $0)] }
        let danceStudio = try household.bill(named: "Dance Studio")

        var details = NewBill(danceStudio)
        #expect(details.isCardPaid)
        details.isCardPaid = false
        try household.editBill(danceStudio.id, to: details)

        #expect(try !household.bill(named: "Dance Studio").isCardPaid)
        #expect(try household.due(named: "Dance Studio").isCardPaid)
        #expect(try !household.due(named: "Dance Studio", in: .october).isCardPaid)
        #expect(try household.openBillingMonth(.october).unpaidRemaining.amount == 200)
    }

    @Test("Card-Paid and the Paid Amount are still there when the Household is opened again")
    func everythingIsKeptInTheStore() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.visa(in: household))
        try household.addBill(.danceStudio(in: household))
        let visa = try household.due(named: "Visa")
        try household.enterAmount(Decimal(string: "5000.00"), on: visa.id, by: "Mircea")
        try household.markPaid(visa.id, paying: Decimal(string: "1000.00"), by: "Mircea")

        var reopened = try Household.open(in: store, clock: .testing)

        #expect(try reopened.bill(named: "Dance Studio").isCardPaid)
        #expect(try reopened.due(named: "Dance Studio").isCardPaid)
        #expect(try reopened.due(named: "Visa").unpaidBalance == Decimal(string: "4000.00"))
    }
}
