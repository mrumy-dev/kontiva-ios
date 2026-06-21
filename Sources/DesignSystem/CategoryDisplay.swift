import SwiftUI
import KontivaCore

/// UI presentation for a derived bill state: localized label + calm colour.
struct BillStateDisplay {
    let labelKey: L10nKey
    let color: Color
    let affectsBalance: Bool

    init(_ state: BillState) {
        switch state {
        case .overdue:
            labelKey = .billsStateOverdue; color = KontivaTheme.swissRed; affectsBalance = true
        case .dueThisMonth:
            labelKey = .billsStateDueThisMonth; color = KontivaTheme.warning; affectsBalance = true
        case .future:
            labelKey = .billsStateFuture; color = KontivaTheme.textTertiary; affectsBalance = false
        case .paid:
            labelKey = .billsStatusPaid; color = KontivaTheme.positive; affectsBalance = false
        }
    }
}

extension FixedExpenseCategory {
    func localizedName(_ loc: Localization) -> String {
        switch self {
        case .rent:            return loc.string(.catRent)
        case .mortgage:        return loc.string(.catMortgage)
        case .healthInsurance: return loc.string(.catHealthInsurance)
        case .insurance:       return loc.string(.catInsurance)
        case .utilities:       return loc.string(.catUtilities)
        case .telecom:         return loc.string(.catTelecom)
        case .subscription:    return loc.string(.catSubscription)
        case .serafe:          return loc.string(.catSerafe)
        case .leasing:         return loc.string(.catLeasing)
        case .publicTransport: return loc.string(.catPublicTransport)
        case .childcare:       return loc.string(.catChildcare)
        case .education:       return loc.string(.catEducation)
        case .membership:      return loc.string(.catMembership)
        case .alimony:         return loc.string(.catAlimony)
        case .taxes:           return loc.string(.catTaxes)
        case .other:           return loc.string(.catOther)
        }
    }

    var systemImage: String {
        switch self {
        case .rent:            return "house.fill"
        case .mortgage:        return "key.fill"
        case .healthInsurance: return "cross.case.fill"
        case .insurance:       return "checkmark.shield.fill"
        case .utilities:       return "bolt.fill"
        case .telecom:         return "antenna.radiowaves.left.and.right"
        case .subscription:    return "repeat"
        case .serafe:          return "tv.fill"
        case .leasing:         return "car.fill"
        case .publicTransport: return "tram.fill"
        case .childcare:       return "figure.and.child.holdinghands"
        case .education:       return "graduationcap.fill"
        case .membership:      return "person.3.fill"
        case .alimony:         return "heart.fill"
        case .taxes:           return "building.columns.fill"
        case .other:           return "ellipsis.circle.fill"
        }
    }
}

extension VariableBudgetCategory {
    func localizedName(_ loc: Localization) -> String {
        switch self {
        case .groceries:     return loc.string(.catGroceries)
        case .dining:        return loc.string(.catDining)
        case .household:     return loc.string(.catHousehold)
        case .clothing:      return loc.string(.catClothing)
        case .personal:      return loc.string(.catPersonal)
        case .health:        return loc.string(.catHealth)
        case .fuel:          return loc.string(.catFuel)
        case .transport:     return loc.string(.catTransport)
        case .leisure:       return loc.string(.catLeisure)
        case .entertainment: return loc.string(.catEntertainment)
        case .children:      return loc.string(.catChildren)
        case .pets:          return loc.string(.catPets)
        case .gifts:         return loc.string(.catGifts)
        case .travel:        return loc.string(.catTravel)
        case .education:     return loc.string(.catEducation)
        case .charity:       return loc.string(.catCharity)
        case .other:         return loc.string(.catOther)
        }
    }

    var systemImage: String {
        switch self {
        case .groceries:     return "cart.fill"
        case .dining:        return "fork.knife"
        case .household:     return "house.fill"
        case .clothing:      return "tshirt.fill"
        case .personal:      return "person.fill"
        case .health:        return "heart.fill"
        case .fuel:          return "fuelpump.fill"
        case .transport:     return "tram.fill"
        case .leisure:       return "figure.run"
        case .entertainment: return "film.fill"
        case .children:      return "figure.and.child.holdinghands"
        case .pets:          return "pawprint.fill"
        case .gifts:         return "gift.fill"
        case .travel:        return "airplane"
        case .education:     return "book.fill"
        case .charity:       return "heart.circle.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }
}

extension SavingsCategory {
    func localizedName(_ loc: Localization) -> String {
        switch self {
        case .emergency:   return loc.string(.savingsCatEmergency)
        case .retirement:  return loc.string(.savingsCatRetirement)
        case .home:        return loc.string(.savingsCatHome)
        case .car:         return loc.string(.savingsCatCar)
        case .vacation:    return loc.string(.savingsCatVacation)
        case .wedding:     return loc.string(.savingsCatWedding)
        case .family:      return loc.string(.savingsCatFamily)
        case .education:   return loc.string(.savingsCatEducation)
        case .renovation:  return loc.string(.savingsCatRenovation)
        case .electronics: return loc.string(.savingsCatElectronics)
        case .taxes:       return loc.string(.savingsCatTaxes)
        case .investment:  return loc.string(.savingsCatInvestment)
        case .health:      return loc.string(.savingsCatHealth)
        case .gift:        return loc.string(.savingsCatGift)
        case .other:       return loc.string(.savingsCatOther)
        }
    }

    var systemImage: String {
        switch self {
        case .emergency:   return "lifepreserver.fill"
        case .retirement:  return "shield.fill"
        case .home:        return "house.fill"
        case .car:         return "car.fill"
        case .vacation:    return "airplane"
        case .wedding:     return "heart.fill"
        case .family:      return "figure.2.and.child.holdinghands"
        case .education:   return "graduationcap.fill"
        case .renovation:  return "hammer.fill"
        case .electronics: return "laptopcomputer"
        case .taxes:       return "building.columns.fill"
        case .investment:  return "chart.line.uptrend.xyaxis"
        case .health:      return "cross.case.fill"
        case .gift:        return "gift.fill"
        case .other:       return "banknote.fill"
        }
    }
}

extension DebtType {
    func localizedName(_ loc: Localization) -> String {
        switch self {
        case .openClaim:     return loc.string(.debtTypeOpenClaim)
        case .betreibung:    return loc.string(.debtTypeBetreibung)
        case .pfaendung:     return loc.string(.debtTypePfaendung)
        case .verlustschein: return loc.string(.debtTypeVerlustschein)
        case .other:         return loc.string(.debtTypeOther)
        }
    }

    var systemImage: String {
        switch self {
        case .openClaim:     return "envelope.fill"
        case .betreibung:    return "doc.text.fill"
        case .pfaendung:     return "hand.raised.fill"
        case .verlustschein: return "scroll.fill"
        case .other:         return "creditcard.fill"
        }
    }

    /// Calm, semantic colour. Active enforcement (Betreibung/Pfändung) is red
    /// (danger); an open claim is amber; a Verlustschein is neutral (long-term).
    var color: Color {
        switch self {
        case .pfaendung, .betreibung: return KontivaTheme.swissRed
        case .openClaim:              return KontivaTheme.warning
        case .verlustschein:          return KontivaTheme.textSecondary
        case .other:                  return KontivaTheme.accent
        }
    }
}

/// Swiss date formatting helper.
enum SwissDate {
    static func medium(_ date: Date, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = Calendar.swiss
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}
