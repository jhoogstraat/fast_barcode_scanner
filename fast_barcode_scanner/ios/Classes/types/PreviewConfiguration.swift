struct PreviewConfiguration {
    let width: Int32
    let height: Int32
    let targetRotation: Int
    let textureId: Int64

    var asDict: [String: Any] {
        ["width": height,
         "height": width,
         "analysis": "\(width)x\(height)",
         "targetRotation": targetRotation,
         "textureId": textureId]
    }
}
