//
//  UIImage+Extensions.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//


import UIKit

extension UIImage {
    /// 将图片缩放到指定的宽度，自动计算高度以保持比例
    /// 这能极大地降低内存占用 (比如从 50MB -> 500KB)
    func resized(toWidth width: CGFloat) -> UIImage? {
        // 1. 计算新高度
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        
        // 2. 开启图形上下文
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        // 3. 在新尺寸里重绘图片
        draw(in: CGRect(origin: .zero, size: canvasSize))
        
        // 4. 获取新图片
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
