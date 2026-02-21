import CoreML
import Foundation
import UIKit

@objc(MobileClipModule)
final class MobileClipModule: NSObject {
  private let queue = DispatchQueue(
    label: "com.thetrash.mobileclip.queue",
    qos: .userInitiated
  )

  private var model: MLModel?
  private var compiledModelURL: URL?

  @objc
  static func requiresMainQueueSetup() -> Bool {
    false
  }

  @objc(embedImage:resolver:rejecter:)
  func embedImage(
    _ imageUri: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async {
      do {
        let cgImage = try self.loadImage(from: imageUri)
        let loadedModel = try self.ensureModel()
        let embedding = try self.predictEmbedding(model: loadedModel, cgImage: cgImage)

        resolve([
          "embedding": embedding,
          "dimension": embedding.count,
          "source": "ios-mobileclip-image"
        ])
      } catch {
        reject("ERR_MOBILECLIP_EMBED", error.localizedDescription, error)
      }
    }
  }

  private func ensureModel() throws -> MLModel {
    if let cachedModel = model {
      return cachedModel
    }

    let packageURL = try modelPackageURL()
    let compiledURL: URL
    if let cachedCompiledURL = compiledModelURL {
      compiledURL = cachedCompiledURL
    } else {
      compiledURL = try MLModel.compileModel(at: packageURL)
      compiledModelURL = compiledURL
    }

    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all

    let loaded = try MLModel(contentsOf: compiledURL, configuration: configuration)
    model = loaded
    return loaded
  }

  private func modelPackageURL() throws -> URL {
    if let modelURL = Bundle.main.url(
      forResource: "MobileCLIPImage",
      withExtension: "mlpackage",
      subdirectory: "Models"
    ) {
      return modelURL
    }

    if let fallbackURL = Bundle.main.url(
      forResource: "MobileCLIPImage",
      withExtension: "mlpackage"
    ) {
      return fallbackURL
    }

    throw NSError(
      domain: "MobileClipModule",
      code: 1001,
      userInfo: [
        NSLocalizedDescriptionKey: "MobileCLIPImage.mlpackage is missing from app bundle"
      ]
    )
  }

  private func loadImage(from imageUri: String) throws -> CGImage {
    let strippedPath = imageUri.replacingOccurrences(of: "file://", with: "")
    let normalizedPath = strippedPath.removingPercentEncoding ?? strippedPath

    guard
      let image = UIImage(contentsOfFile: normalizedPath),
      let cgImage = image.cgImage
    else {
      throw NSError(
        domain: "MobileClipModule",
        code: 1002,
        userInfo: [
          NSLocalizedDescriptionKey: "Unable to decode image at path: \(normalizedPath)"
        ]
      )
    }

    return cgImage
  }

  private func predictEmbedding(model: MLModel, cgImage: CGImage) throws -> [Double] {
    guard
      let inputDescription = model.modelDescription.inputDescriptionsByName["image"],
      let imageConstraint = inputDescription.imageConstraint
    else {
      throw NSError(
        domain: "MobileClipModule",
        code: 1003,
        userInfo: [
          NSLocalizedDescriptionKey: "Model input \"image\" is unavailable"
        ]
      )
    }

    let imageValue = try MLFeatureValue(
      cgImage: cgImage,
      constraint: imageConstraint,
      options: nil
    )
    let inputs = try MLDictionaryFeatureProvider(dictionary: ["image": imageValue])
    let prediction = try model.prediction(from: inputs)

    let outputName: String
    if prediction.featureNames.contains("final_emb_1") {
      outputName = "final_emb_1"
    } else if let fallbackName = prediction.featureNames.first {
      outputName = fallbackName
    } else {
      throw NSError(
        domain: "MobileClipModule",
        code: 1004,
        userInfo: [
          NSLocalizedDescriptionKey: "Model prediction has no outputs"
        ]
      )
    }

    guard
      let outputValue = prediction.featureValue(for: outputName),
      let embedding = outputValue.multiArrayValue
    else {
      throw NSError(
        domain: "MobileClipModule",
        code: 1005,
        userInfo: [
          NSLocalizedDescriptionKey: "Model output \(outputName) is not a multi-array"
        ]
      )
    }

    return toDoubleArray(embedding)
  }

  private func toDoubleArray(_ multiArray: MLMultiArray) -> [Double] {
    var values = [Double]()
    values.reserveCapacity(multiArray.count)

    for index in 0 ..< multiArray.count {
      values.append(multiArray[index].doubleValue)
    }

    return values
  }
}
