// macOS Vision framework OCR: image -> text (with optional JSON boxes)
import Foundation
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write("usage: vision_ocr <image> [--json] [--fast]\n".data(using:.utf8)!); exit(2) }
let path = args[1]
let wantJSON = args.contains("--json")
let fast = args.contains("--fast")

guard let img = NSImage(contentsOfFile: path),
      let tiff = img.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff),
      let cg = bmp.cgImage else {
    FileHandle.standardError.write("cannot load image\n".data(using:.utf8)!); exit(1)
}

let req = VNRecognizeTextRequest()
req.recognitionLevel = fast ? .fast : .accurate
req.usesLanguageCorrection = true
if #available(macOS 13.0, *) { req.revision = VNRecognizeTextRequestRevision3 }

let handler = VNImageRequestHandler(cgImage: cg, options: [:])
do { try handler.perform([req]) } catch { FileHandle.standardError.write("perform failed\n".data(using:.utf8)!); exit(1) }

guard let obs = req.results else { exit(0) }
let W = Double(cg.width), H = Double(cg.height)

if wantJSON {
    var items: [[String: Any]] = []
    for o in obs {
        guard let c = o.topCandidates(1).first else { continue }
        let bb = o.boundingBox   // normalized, origin bottom-left
        items.append([
            "text": c.string,
            "confidence": c.confidence,
            "x": bb.minX * W,
            "y": (1.0 - bb.maxY) * H,   // convert to top-left origin
            "width": bb.width * W,
            "height": bb.height * H,
        ])
    }
    let out = ["width": W, "height": H, "items": items] as [String: Any]
    let d = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted])
    FileHandle.standardOutput.write(d)
} else {
    // reading order: top-to-bottom, then left-to-right
    let sorted = obs.sorted { a, b in
        let ay = 1.0 - a.boundingBox.maxY, by = 1.0 - b.boundingBox.maxY
        if abs(ay - by) > 0.01 { return ay < by }
        return a.boundingBox.minX < b.boundingBox.minX
    }
    for o in sorted { if let c = o.topCandidates(1).first { print(c.string) } }
}
