//
//  ReportView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct ReportView: View {
    let predictedResult: TrashAnalysisResult
    let image: UIImage
    let userId: UUID?
    
    @Environment(\.dismiss) var dismiss
    
    let bins = ["Recycle (Blue Bin)", "Compost (Green Bin)", "Landfill (Black Bin)", "Hazardous"]
    
    @State private var selectedBin = "Landfill (Black Bin)"
    @State private var itemName = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                // AI 结果部分
                Section(header: Text("AI 预测结果")) {
                    HStack {
                        Text("识别物品")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(predictedResult.itemName)
                            .bold()
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Text("分类")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(predictedResult.category)
                            .bold()
                            .foregroundColor(predictedResult.color)
                    }
                }
                
                // 人工修正部分
                Section(header: Text("Human Feedback")) {
                    Picker("实际分类", selection: $selectedBin) {
                        ForEach(bins, id: \.self) { bin in
                            Text(bin)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("正确物品名称 (optional)", text: $itemName)
                        .autocapitalization(.none)
                }
                
                // 提交按钮
                Section {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("正在提交...")
                            Spacer()
                        }
                    } else {
                        Button(action: submit) {
                            Text("提交反馈")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.blue) // 蓝色按钮背景
                    }
                }
            }
            .navigationTitle("报告错误")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
            .alert("submit success", isPresented: $showSuccess) {
                Button("好的") { dismiss() }
            } message: {
                Text("感谢您的反馈，这有助于让 AI 变得更聪明！")
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
                    correctCategory: selectedBin,
                    comment: itemName,
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
                }
            }
        }
    }
}
