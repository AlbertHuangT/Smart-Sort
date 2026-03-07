//
//  ReportView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct ReportView: View {
    let predictedResult: TrashAnalysisResult
    let image: UIImage
    let userId: UUID?

    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    let bins = ["Recycle (Blue Bin)", "Compost (Green Bin)", "Landfill (Black Bin)", "Hazardous"]

    @State private var selectedBin = "Landfill (Black Bin)"
    @State private var itemName = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    // 🔥 FIX: 添加错误状态
    @State private var showError = false
    @State private var errorMessage = ""

    private var reportRows: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            reportRow(
                label: "Recognized Item",
                value: predictedResult.itemName,
                valueColor: theme.palette.textPrimary
            )
            reportRow(
                label: "Category",
                value: predictedResult.category,
                valueColor: predictedResult.color
            )
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // AI Result Section
                Section(header: Text("AI Prediction Result")) {
                    reportRows
                }

                // Human Feedback Section
                Section(header: Text("Human Feedback")) {
                    TrashFormPicker(
                        title: "Actual Category",
                        selection: $selectedBin,
                        options: bins.map { TrashPickerOption(value: $0, title: $0, icon: nil) }
                    )

                    TrashFormTextField(
                        title: "Correct Item Name (optional)",
                        text: $itemName,
                        textInputAutocapitalization: .never
                    )
                }

                // Submit Button
                Section {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("Submitting...")
                            Spacer()
                        }
                    } else {
                        TrashButton(baseColor: theme.accents.blue, action: submit) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                                .trashOnAccentForeground()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Report Error")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel", variant: .accent) { dismiss() }
                }
            }
            .sheet(isPresented: $showSuccess) {
                TrashNoticeSheet(
                    title: "Submit Success",
                    message: "Thank you for your feedback. This will help make the AI smarter!",
                    onClose: {
                        showSuccess = false
                        dismiss()
                    }
                )
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .sheet(isPresented: $showError) {
                TrashNoticeSheet(
                    title: "Submit Failed",
                    message: errorMessage,
                    buttonColor: theme.semanticDanger,
                    onClose: { showError = false }
                )
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .onAppear {
                if bins.contains(predictedResult.category) {
                    selectedBin = predictedResult.category
                }
            }
        }
    }

    func submit() {
        isSubmitting = true
        Task {
            do {
                try await FeedbackService.shared.submitFeedback(
                    image: image,
                    predictedLabel: predictedResult.itemName,
                    predictedCategory: predictedResult.category,
                    correctedName: itemName,
                    userId: userId
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                print("Feedback Error: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    // 🔥 FIX: 显示错误信息给用户
                    errorMessage = "Failed to submit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func reportRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
            Text(label)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: theme.components.minimumHitTarget, alignment: .center)
    }
}
