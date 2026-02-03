//
//  CameraView.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import SwiftUI
import UIKit

// 这是一个“桥梁”，把 UIKit 的相机功能包装给 SwiftUI 使用
struct CameraView: UIViewControllerRepresentable {
    
    // 用来把拍到的照片传回给父视图
    @Binding var selectedImage: UIImage?
    // 用来控制相机界面的关闭
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // 核心设置：使用相机，而不是相册
        // 如果是在模拟器上跑，这里会崩溃（模拟器没相机），所以为了安全可以加个判断
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            print("⚠️ 警告：当前设备不支持相机，正在回退到相册模式")
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 协调器：负责处理“拍完照片后干什么”
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        // ✅ 这是 UIImagePickerController 唯一会调用的“拍照完成”回调
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            // 1. 拿到原始照片
            if let image = info[.originalImage] as? UIImage {
                
                // 🔥 关键修改：在这里立刻缩小图片！(防止内存爆炸)
                // 注意：这需要你之前创建了 UIImage+Extensions.swift 文件
                // 如果没有那个文件，请把 .resized(toWidth: 512) 去掉，直接赋值 image
                let smallImage = image.resized(toWidth: 512) ?? image
                
                parent.selectedImage = smallImage
            }
            
            // 2. 关闭相机界面
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        // ❌ 已删除：photoOutput 方法
        // (那个方法是给 AVCaptureSession 用的，UIImagePickerController 用不着)
    }
}

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
