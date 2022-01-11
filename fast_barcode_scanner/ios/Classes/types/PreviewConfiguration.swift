struct PreviewConfiguration {
    let width: Int32
    let height: Int32
    let targetRotation: Int
    let textureId: Int64

    var asDict: [String: Any] {
        ["width": height,
         "height": width,
         "targetRotation": targetRotation,
         "textureId": textureId,
         "analysisWidth": width,
         "analysisHeight": height]
    }
}
