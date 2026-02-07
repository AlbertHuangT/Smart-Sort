//
//  BindPhoneSheet.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                if !authVM.showOTPInput {
                    Section {
                        TextField("Phone (+1...)", text: $inputPhone).keyboardType(.phonePad)
                        Button("Send Code") { Task { await authVM.bindPhone(phone: inputPhone) } }
                    }
                } else {
                    Section {
                        TextField("Code", text: $inputOTP).keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                if authVM.errorMessage == nil {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Bind Phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authVM.showOTPInput = false
                        authVM.errorMessage = nil
                        inputOTP = ""
                        isPresented = false
                    }
                }
            }
        }
    }
}
