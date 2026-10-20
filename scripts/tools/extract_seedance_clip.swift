#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let outputSize = 256
private let rootX = 128
private let rootY = 232
private let targetHeight = 198.0
private let helmetTargetY = 84.0

private enum VerticalAnchor: String {
    case sourceFloor
    case bottom
    case helmet
}

private struct Frame {
    let width: Int
    let height: Int
    var pixels: [UInt8]
    var bounds: CGRect
    var helmetCenterX: Double
    var helmetCenterY: Double
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
    let t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)
}

private func rgbaFrame(from image: CGImage, preserveSecondary: Bool = false) -> Frame {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    for pixelIndex in 0..<(width * height) {
        let offset = pixelIndex * 4
        let red = Double(pixels[offset]) / 255.0
        let green = Double(pixels[offset + 1]) / 255.0
        let blue = Double(pixels[offset + 2]) / 255.0
        let greenExcess = green - max(red, blue)
        let amber = red > 0.34 && red > green * 1.18 && red > blue * 1.75
        var alpha = 1.0 - smoothstep(0.08, 0.31, greenExcess)
        if amber {
            alpha = max(alpha, 0.96)
        }
        if alpha < 0.035 {
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
        } else {
            if !amber {
                pixels[offset] = 1
                pixels[offset + 1] = 2
                pixels[offset + 2] = 3
            }
            pixels[offset + 3] = UInt8(round(alpha * 255.0))
        }
    }

    let keep = connectedComponentMask(
        pixels: pixels,
        width: width,
        height: height,
        preserveSecondary: preserveSecondary
    )
    var cleaned = pixels
    for pixelIndex in 0..<(width * height) {
        if !keep[pixelIndex] {
            let offset = pixelIndex * 4
            cleaned[offset] = 0
            cleaned[offset + 1] = 0
            cleaned[offset + 2] = 0
            cleaned[offset + 3] = 0
        }
    }
    let bounds = alphaBounds(pixels: cleaned, width: width, height: height)
    let helmetCenter = detectHelmetCenter(
        pixels: cleaned,
        width: width,
        height: height,
        bounds: bounds
    )
    return Frame(
        width: width,
        height: height,
        pixels: cleaned,
        bounds: bounds,
        helmetCenterX: helmetCenter.x,
        helmetCenterY: helmetCenter.y
    )
}

private func connectedComponentMask(
    pixels: [UInt8],
    width: Int,
    height: Int,
    preserveSecondary: Bool
) -> [Bool] {
    let pixelCount = width * height
    var visited = [Bool](repeating: false, count: pixelCount)
    var components: [[Int]] = []
    var queue: [Int] = []
    queue.reserveCapacity(pixelCount / 4)

    for start in 0..<pixelCount {
        if visited[start] || pixels[start * 4 + 3] < 84 {
            continue
        }
        visited[start] = true
        queue.removeAll(keepingCapacity: true)
        queue.append(start)
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let x = current % width
            let y = current / width
            for offsetY in -1...1 {
                for offsetX in -1...1 {
                    if offsetX == 0 && offsetY == 0 {
                        continue
                    }
                    let nextX = x + offsetX
                    let nextY = y + offsetY
                    if nextX < 0 || nextX >= width || nextY < 0 || nextY >= height {
                        continue
                    }
                    let next = nextY * width + nextX
                    if visited[next] || pixels[next * 4 + 3] < 84 {
                        continue
                    }
                    visited[next] = true
                    queue.append(next)
                }
            }
        }
        if queue.count >= 12 {
            components.append(queue)
        }
    }

    var keep = [Bool](repeating: false, count: pixelCount)
    guard let main = components.max(by: { $0.count < $1.count }) else {
        return keep
    }
    let mainBounds = componentBounds(main, width: width)
    let minimumSecondarySize = max(180, main.count / 90)
    for component in components {
        var preserve = component.count == main.count
        if preserveSecondary && !preserve && component.count >= minimumSecondarySize {
            let bounds = componentBounds(component, width: width)
            preserve = rectangleGap(mainBounds, bounds) <= 250.0
        }
        if !preserve {
            continue
        }
        for index in component {
            let x = index % width
            let y = index / width
            for offsetY in -2...2 {
                for offsetX in -2...2 {
                    let nextX = x + offsetX
                    let nextY = y + offsetY
                    if nextX >= 0 && nextX < width && nextY >= 0 && nextY < height {
                        keep[nextY * width + nextX] = true
                    }
                }
            }
        }
    }
    return keep
}

private func componentBounds(_ component: [Int], width: Int) -> CGRect {
    var minimumX = Int.max
    var minimumY = Int.max
    var maximumX = Int.min
    var maximumY = Int.min
    for index in component {
        let x = index % width
        let y = index / width
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
    }
    return CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX + 1,
        height: maximumY - minimumY + 1
    )
}

private func rectangleGap(_ first: CGRect, _ second: CGRect) -> Double {
    let horizontal = max(0.0, max(first.minX - second.maxX, second.minX - first.maxX))
    let vertical = max(0.0, max(first.minY - second.maxY, second.minY - first.maxY))
    return hypot(horizontal, vertical)
}

private func alphaBounds(pixels: [UInt8], width: Int, height: Int) -> CGRect {
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
        for x in 0..<width {
            if pixels[(y * width + x) * 4 + 3] < 24 {
                continue
            }
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }
    if maximumX < minimumX || maximumY < minimumY {
        return .zero
    }
    return CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX + 1,
        height: maximumY - minimumY + 1
    )
}

private func detectHelmetCenter(
    pixels: [UInt8],
    width: Int,
    height: Int,
    bounds: CGRect
) -> (x: Double, y: Double) {
    let minimumY = max(0, Int(bounds.minY))
    let maximumY = min(height, minimumY + Int(bounds.height * 0.62))
    var bestWidth = 0
    var bestCenter = bounds.midX
    var bestY = bounds.minY + bounds.height * 0.28
    for y in minimumY..<maximumY {
        var rowMinimum = width
        var rowMaximum = -1
        for x in max(0, Int(bounds.minX))..<min(width, Int(bounds.maxX)) {
            if pixels[(y * width + x) * 4 + 3] < 84 {
                continue
            }
            rowMinimum = min(rowMinimum, x)
            rowMaximum = max(rowMaximum, x)
        }
        let rowWidth = rowMaximum - rowMinimum
        if rowWidth > bestWidth {
            bestWidth = rowWidth
            bestCenter = Double(rowMinimum + rowMaximum) * 0.5
            bestY = Double(y)
        }
    }
    return (bestCenter, bestY)
}

private func resample(
    frame: Frame,
    scale: Double,
    sourceFloor: Double,
    anchor: VerticalAnchor,
    sourceCenterX: Double? = nil,
    outputWidth: Int = outputSize,
    outputHeight: Int = outputSize,
    destinationRoot: CGPoint = CGPoint(x: rootX, y: rootY)
) -> [UInt8] {
    var output = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
    let destinationX = destinationRoot.x - (sourceCenterX ?? frame.helmetCenterX) * scale
    let destinationY: Double
    matchAnchor: switch anchor {
    case .sourceFloor:
        destinationY = destinationRoot.y - sourceFloor * scale
    case .bottom:
        destinationY = destinationRoot.y - frame.bounds.maxY * scale
    case .helmet:
        destinationY = helmetTargetY - frame.helmetCenterY * scale
    }

    for y in 0..<outputHeight {
        let sourceY = (Double(y) - destinationY) / scale
        let y0 = Int(floor(sourceY))
        if y0 < 0 || y0 >= frame.height {
            continue
        }
        for x in 0..<outputWidth {
            let sourceX = (Double(x) - destinationX) / scale
            let x0 = Int(floor(sourceX))
            if x0 < 0 || x0 >= frame.width {
                continue
            }
            let sourceOffset = (y0 * frame.width + x0) * 4
            let alpha = frame.pixels[sourceOffset + 3]
            if alpha == 0 {
                continue
            }
            let destinationOffset = (y * outputWidth + x) * 4
            let red = frame.pixels[sourceOffset]
            let green = frame.pixels[sourceOffset + 1]
            let blue = frame.pixels[sourceOffset + 2]
            let amber = red > 72 && Int(red) > Int(green) * 6 / 5 && Int(red) > Int(blue) * 7 / 4
            if amber {
                output[destinationOffset] = red
                output[destinationOffset + 1] = green
                output[destinationOffset + 2] = blue
            } else {
                output[destinationOffset] = 1
                output[destinationOffset + 1] = 2
                output[destinationOffset + 2] = 3
            }
            output[destinationOffset + 3] = alpha > 42 ? 255 : UInt8(Int(alpha) * 6)
        }
    }
    return output
}

private func savePNG(pixels: [UInt8], width: Int, height: Int, url: URL) throws {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
    let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "SeedanceExtractor", code: 2)
    }
}

private func extractVideo(
    inputPath: String,
    outputDirectory: String,
    startSeconds: Double,
    frameCount: Int,
    sourceFPS: Double,
    fixedScale: Double? = nil,
    fixedCenterX: Double? = nil,
    fixedSourceFloor: Double? = nil,
    preserveSecondary: Bool = false,
    anchor: VerticalAnchor = .sourceFloor
) throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    var frames: [Frame] = []
    for frameIndex in 0..<frameCount {
        let seconds = startSeconds + Double(frameIndex) / sourceFPS
        let time = CMTime(seconds: seconds, preferredTimescale: 2400)
        let image = try generator.copyCGImage(at: time, actualTime: nil)
        frames.append(rgbaFrame(from: image, preserveSecondary: preserveSecondary))
    }
    let sortedHeights = frames.map(\.bounds.height).sorted()
    let medianHeight = sortedHeights[sortedHeights.count / 2]
    let sortedCenters = frames.map(\.helmetCenterX).sorted()
    let medianCenterX = sortedCenters[sortedCenters.count / 2]
    let scale = fixedScale ?? targetHeight / medianHeight
    let sourceFloor = fixedSourceFloor ?? frames.map(\.bounds.maxY).max()!
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    for (frameIndex, frame) in frames.enumerated() {
        let pixels = resample(
            frame: frame,
            scale: scale,
            sourceFloor: sourceFloor,
            anchor: anchor,
            sourceCenterX: fixedCenterX
        )
        try savePNG(
            pixels: pixels,
            width: outputSize,
            height: outputSize,
            url: outputURL.appendingPathComponent(String(format: "frame_%02d.png", frameIndex))
        )
    }
    print(
        "Extracted \(frameCount) frames | start=\(startSeconds)s | sourceFPS=\(sourceFPS) " +
        "| medianHeight=\(String(format: "%.1f", medianHeight)) | scale=\(String(format: "%.4f", scale)) " +
        "| sourceFloor=\(String(format: "%.1f", sourceFloor)) " +
        "| centerX=\(fixedCenterX.map { String(format: "%.1f", $0) } ?? String(format: "%.1f", medianCenterX)) " +
        "| anchor=\(anchor.rawValue) | root=(\(rootX),\(rootY))"
    )
}

private func extractStill(inputPath: String, outputPath: String) throws {
    guard
        let image = NSImage(contentsOfFile: inputPath),
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let cgImage = bitmap.cgImage
    else {
        throw NSError(domain: "SeedanceExtractor", code: 3)
    }
    let frame = rgbaFrame(from: cgImage)
    let scale = targetHeight / frame.bounds.height
    let pixels = resample(
        frame: frame,
        scale: scale,
        sourceFloor: frame.bounds.maxY,
        anchor: .bottom
    )
    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try savePNG(pixels: pixels, width: outputSize, height: outputSize, url: outputURL)
    print(
        "Extracted still | height=\(String(format: "%.1f", frame.bounds.height)) " +
        "| scale=\(String(format: "%.4f", scale)) | root=(\(rootX),\(rootY))"
    )
}

private func extractSamples(
    inputPath: String,
    outputDirectory: String,
    anchor: VerticalAnchor,
    scale: Double,
    times: [Double],
    preserveSecondary: Bool
) throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    for (frameIndex, seconds) in times.enumerated() {
        let time = CMTime(seconds: seconds, preferredTimescale: 2400)
        let image = try generator.copyCGImage(at: time, actualTime: nil)
        let frame = rgbaFrame(from: image, preserveSecondary: preserveSecondary)
        let pixels = resample(
            frame: frame,
            scale: scale,
            sourceFloor: frame.bounds.maxY,
            anchor: anchor
        )
        try savePNG(
            pixels: pixels,
            width: outputSize,
            height: outputSize,
            url: outputURL.appendingPathComponent(String(format: "frame_%02d.png", frameIndex))
        )
    }
    print(
        "Extracted \(times.count) samples | anchor=\(anchor.rawValue) " +
        "| scale=\(String(format: "%.4f", scale)) | secondary=\(preserveSecondary) " +
        "| root=(\(rootX),\(rootY))"
    )
}

private func usage() -> Never {
    fputs(
        """
        Usage:
          swift extract_seedance_clip.swift video INPUT OUTPUT_DIR START_SECONDS FRAME_COUNT SOURCE_FPS [FIXED_SCALE FIXED_CENTER_X FIXED_SOURCE_FLOOR [keepSecondary [ANCHOR]]]
          swift extract_seedance_clip.swift still INPUT OUTPUT_PNG
          swift extract_seedance_clip.swift samples INPUT OUTPUT_DIR ANCHOR SCALE TIMES_CSV [keepSecondary]
          swift extract_seedance_clip.swift study INPUT OUTPUT_DIR CONFIG_JSON

        """,
        stderr
    )
    exit(64)
}

// A review-only batch keeps one scale/floor and an explicit authored root-motion track.
// It never rescales or recenters individual frame bounding boxes.
private func extractStudy(inputPath: String, outputDirectory: String, configPath: String) throws {
    let config = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: configPath))) as! [String: Any]
    let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let fps = 24.0
    let count = config["frames"] as! Int
    let scale = config["scale"] as! Double
    let floor = config["floor"] as! Double
    let rootKeys = config["root_keys"] as! [[Double]]
    let clips = config["clips"] as! [[String: Any]]
    let rodStart = config["rod_start"] as! Int
    let canvas = config["canvas"] as! [Int]
    let root = config["root"] as! [Double]
    let destinationRoot = CGPoint(x:root[0],y:root[1])
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory)
    let out = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: out.appendingPathComponent("source-keyed"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: out.appendingPathComponent("master"), withIntermediateDirectories: true)
    var rows: [[String: Any]] = []
    var rendered: [[UInt8]] = []
    for index in 0..<count {
        let time = Double(index) / fps
        let image: CGImage
        if isDirectory.boolValue {
            let url = URL(fileURLWithPath: inputPath).appendingPathComponent(String(format: "frame_%03d.png",index))
            guard let source = CGImageSourceCreateWithURL(url as CFURL,nil), let decoded = CGImageSourceCreateImageAtIndex(source,0,nil) else {
                throw NSError(domain: "SeedanceExtractor",code: 4,userInfo:[NSLocalizedDescriptionKey:"Cannot read \(url.path)"])
            }
            image = decoded
        } else {
            image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 2400), actualTime: nil)
        }
        var frame = rgbaFrame(from: image, preserveSecondary: true)
        let originalBounds = frame.bounds
        try savePNG(pixels: frame.pixels, width: frame.width, height: frame.height,
                    url: out.appendingPathComponent(String(format: "source-keyed/frame_%03d.png", index)))
        var cutX = frame.width
        if index >= rodStart {
            // The generated prop is a thin horizontal tail. Stop before the thick glove.
            for x in stride(from: frame.width - 1, through: 0, by: -1) {
                var occupied = 0
                var minY = frame.height
                var maxY = -1
                for y in 0..<frame.height where frame.pixels[(y * frame.width + x) * 4 + 3] > 84 {
                    occupied += 1
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
                if occupied > 30 || (occupied > 0 && (minY < 500 || maxY > 750)) { break }
                cutX = x
            }
            if cutX < frame.width {
                for y in 0..<frame.height {
                    for x in cutX..<frame.width {
                        let offset = (y * frame.width + x) * 4
                        frame.pixels[offset...offset+3] = [0,0,0,0]
                    }
                }
            }
            frame.bounds = alphaBounds(pixels: frame.pixels, width: frame.width, height: frame.height)
        }
        var center = rootKeys.last![1]
        for k in 1..<rootKeys.count where Double(index) <= rootKeys[k][0] {
            let a = rootKeys[k-1], b = rootKeys[k]
            let weight = min(1.0, max(0.0, (Double(index)-a[0])/(b[0]-a[0])))
            center = a[1] + (b[1]-a[1])*weight
            break
        }
        let pixels = resample(frame: frame, scale: scale, sourceFloor: floor, anchor: .sourceFloor, sourceCenterX: center,
                              outputWidth:canvas[0],outputHeight:canvas[1],destinationRoot:destinationRoot)
        rendered.append(pixels)
        try savePNG(pixels: pixels, width: canvas[0], height: canvas[1],
                    url: out.appendingPathComponent(String(format: "master/frame_%03d.png", index)))
        var footMin = frame.width, footMax = -1
        for y in 815..<min(860,frame.height) {
            for x in 0..<frame.width where frame.pixels[(y*frame.width+x)*4+3] > 84 {
                footMin = min(footMin,x); footMax = max(footMax,x)
            }
        }
        let outputBounds = alphaBounds(pixels: pixels, width: canvas[0], height: canvas[1])
        let clipped = originalBounds.minX < 3 || originalBounds.maxX > Double(frame.width - 3)
        rows.append(["frame":index,"time":time,"source_root_x":center,"rod_cut_x":cutX,
                     "source_bounds":[originalBounds.minX,originalBounds.minY,originalBounds.maxX,originalBounds.maxY],
                     "foot_span":[footMin,footMax],"source_touches_border":clipped,
                     "cleaned_source_bounds":[frame.bounds.minX,frame.bounds.minY,frame.bounds.maxX,frame.bounds.maxY],
                     "output_bounds":[outputBounds.minX,outputBounds.minY,outputBounds.maxX,outputBounds.maxY]])
        if index % 4 == 0 { print("frame \(index) bounds \(originalBounds) feet \(footMin)...\(footMax) rodCut \(cutX)") }
    }
    for clip in clips {
        let name = clip["name"] as! String
        let start = clip["start"] as! Int
        let end = clip["end"] as! Int
        let dir = out.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for index in start...end {
            try savePNG(pixels: rendered[index], width: canvas[0], height: canvas[1],
                        url: dir.appendingPathComponent(String(format:"frame_%03d.png",index-start)))
        }
    }
    var candidates: [(Int,Int,Double)] = []
    for a in 74...88 {
        for b in (a+14)...min(a+29,108) {
            var error = 0.0, union = 0.0
            for y in 235..<286 {
                for x in 130..<265 {
                    let offset = (y*canvas[0]+x)*4+3
                    let p = Double(rendered[a][offset])/255.0, q = Double(rendered[b][offset])/255.0
                    error += abs(p-q); union += max(p,q)
                }
            }
            candidates.append((a,b,error/max(1,union)))
        }
    }
    for c in candidates.sorted(by:{$0.2<$1.2}).prefix(10) { print("Pull seam candidate \(c.0)...\(c.1) error \(c.2)") }
    let report: [String: Any] = ["source":config["source"] ?? inputPath,"fps":fps,"scale":scale,"floor":floor,
        "canvas":canvas,"root":root,"clips":clips,"frames":rows,"root_keys":rootKeys,
        "status":"review_only_not_integrated"]
    let data = try JSONSerialization.data(withJSONObject:report, options:[.prettyPrinted,.sortedKeys])
    try data.write(to:out.appendingPathComponent("manifest.json"))
    let js = "window.MOTION_STUDY = " + String(data:data,encoding:.utf8)! + ";\n"
    try js.write(to:out.appendingPathComponent("manifest.js"),atomically:true,encoding:.utf8)
    print("Exported \(count) consecutive frames at 24fps; \(clips.count) continuous clips.")
}

guard CommandLine.arguments.count >= 2 else {
    usage()
}

do {
    switch CommandLine.arguments[1] {
    case "study":
        guard CommandLine.arguments.count == 5 else { usage() }
        try extractStudy(inputPath: CommandLine.arguments[2], outputDirectory: CommandLine.arguments[3], configPath: CommandLine.arguments[4])
    case "video":
        guard (
            CommandLine.arguments.count == 7
            || CommandLine.arguments.count == 10
            || CommandLine.arguments.count == 11
            || CommandLine.arguments.count == 12
        ) else {
            usage()
        }
        try extractVideo(
            inputPath: CommandLine.arguments[2],
            outputDirectory: CommandLine.arguments[3],
            startSeconds: Double(CommandLine.arguments[4])!,
            frameCount: Int(CommandLine.arguments[5])!,
            sourceFPS: Double(CommandLine.arguments[6])!,
            fixedScale: CommandLine.arguments.count >= 10 ? Double(CommandLine.arguments[7]) : nil,
            fixedCenterX: CommandLine.arguments.count >= 10 ? Double(CommandLine.arguments[8]) : nil,
            fixedSourceFloor: CommandLine.arguments.count >= 10 ? Double(CommandLine.arguments[9]) : nil,
            preserveSecondary: CommandLine.arguments.count >= 11 &&
                CommandLine.arguments[10] == "keepSecondary",
            anchor: CommandLine.arguments.count == 12
                ? VerticalAnchor(rawValue: CommandLine.arguments[11])!
                : .sourceFloor
        )
    case "still":
        guard CommandLine.arguments.count == 4 else {
            usage()
        }
        try extractStill(inputPath: CommandLine.arguments[2], outputPath: CommandLine.arguments[3])
    case "samples":
        guard
            CommandLine.arguments.count == 7 || CommandLine.arguments.count == 8,
            let anchor = VerticalAnchor(rawValue: CommandLine.arguments[4]),
            let scale = Double(CommandLine.arguments[5])
        else {
            usage()
        }
        let times = CommandLine.arguments[6].split(separator: ",").compactMap {
            Double($0)
        }
        guard !times.isEmpty else {
            usage()
        }
        try extractSamples(
            inputPath: CommandLine.arguments[2],
            outputDirectory: CommandLine.arguments[3],
            anchor: anchor,
            scale: scale,
            times: times,
            preserveSecondary: CommandLine.arguments.count == 8 &&
                CommandLine.arguments[7] == "keepSecondary"
        )
    default:
        usage()
    }
} catch {
    fputs("Seedance extraction failed: \(error)\n", stderr)
    exit(1)
}
