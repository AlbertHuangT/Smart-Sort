//
//  AccountSheetRouting.swift
//  Smart Sort
//

import Foundation

enum AccountSheetRoute: String, Identifiable {
    case bindPhone
    case bindEmail
    case changePassword
    case upgradeGuest
    case editUsername

    var id: String { rawValue }
}

struct AccountSheetInputs {
    var phone = "+1"
    var email = ""
    var otp = ""
    var username = ""
    var upgradeEmail = ""
    var upgradePassword = ""
    var upgradeConfirmPassword = ""
}
