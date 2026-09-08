import Cocoa
import AVKit
import AVFoundation
import Metal
import MetalKit
import Darwin
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// ==============================================================================
// 🎨 SOVEREIGN ICONS & USER ASSET LOADER (WITH TINT & NO DUPLICATION)
// ==============================================================================
class SovereignIcons {
    /// Loads user PNG icon and creates a centered square template image of targetSize with internal padding.
    static func getUserIcon(name: String, targetSize: CGFloat = 16.0) -> NSImage? {
        var rawImg: NSImage? = nil
        // 1. Try App Bundle Resources
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "icons") ??
                     Bundle.main.url(forResource: name, withExtension: "png") {
            rawImg = NSImage(contentsOf: url)
        }
        // 2. Relative Source Path Fallback
        if rawImg == nil {
            let relativePath = "frontend_ui/Resources/icons/\(name).png"
            if FileManager.default.fileExists(atPath: relativePath) {
                rawImg = NSImage(contentsOfFile: relativePath)
            } else {
                let localPath = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Resources/icons/\(name).png").path
                rawImg = NSImage(contentsOfFile: localPath)
            }
        }
        guard let source = rawImg else { return nil }

        // Create uniform canvas with targetSize x targetSize
        let canvas = NSImage(size: NSSize(width: targetSize, height: targetSize))
        canvas.lockFocus()
        let srcSize = source.size
        if srcSize.width > 0 && srcSize.height > 0 {
            let aspect = srcSize.width / srcSize.height
            var drawW = targetSize
            var drawH = targetSize
            if aspect > 1.0 {
                drawH = targetSize / aspect
            } else {
                drawW = targetSize * aspect
            }
            let drawX = (targetSize - drawW) / 2.0
            let drawY = (targetSize - drawH) / 2.0
            source.draw(in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH),
                        from: NSRect(origin: .zero, size: srcSize),
                        operation: .sourceOver,
                        fraction: 1.0)
        }
        canvas.unlockFocus()
        canvas.isTemplate = true
        return canvas
    }

    static func getSymbol(name: String, fallbackText: String, pointSize: CGFloat = 14, weight: NSFont.Weight = .medium) -> NSImage? {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                let templateImg = img.withSymbolConfiguration(config)
                templateImg?.isTemplate = true
                return templateImg
            }
        }
        return nil
    }
}

// ==============================================================================
// 🎛️ CLEAN SINGLE-ICON TOOLBAR BUTTON (NEVER DOUBLED, UNIFORM SIZING & PADDING)
// ==============================================================================
class SVNButton: NSButton {
    var pointSize: CGFloat = 14.0
    var iconSize: CGFloat = 16.0
    var isHovered: Bool = false {
        didSet {
            needsDisplay = true
            self.layer?.backgroundColor = isHovered ? NSColor(white: 0.5, alpha: 0.15).cgColor : NSColor.clear.cgColor
        }
    }
    private var trackingArea: NSTrackingArea?

    init(frame frameRect: NSRect, title: String = "", symbolName: String? = nil, assetName: String? = nil, pointSize: CGFloat = 13, iconSize: CGFloat = 16.0) {
        super.init(frame: frameRect)
        self.pointSize = pointSize
        self.iconSize = iconSize
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.wantsLayer = true
        self.layer?.cornerRadius = 5.0
        self.layer?.masksToBounds = true
        self.contentTintColor = .labelColor
        
        updateIcon(symbolName: symbolName, assetName: assetName, fallbackText: title)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func updateIcon(symbolName: String?, assetName: String? = nil, fallbackText: String) {
        var iconImg: NSImage? = nil
        if let asset = assetName {
            iconImg = SovereignIcons.getUserIcon(name: asset, targetSize: iconSize)
        }
        if iconImg == nil, let sym = symbolName {
            iconImg = SovereignIcons.getSymbol(name: sym, fallbackText: fallbackText, pointSize: pointSize)
        }

        if let img = iconImg {
            self.image = img
            self.imagePosition = .imageOnly // Single icon ONLY, no duplicate text!
            self.imageScaling = .scaleProportionallyDown
            self.title = "" // Clear title so it never duplicates the image
        } else {
            self.image = nil
            self.imagePosition = .noImage
            self.title = fallbackText
            self.font = NSFont.systemFont(ofSize: pointSize, weight: .semibold)
        }
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        if let area = trackingArea { removeTrackingArea(area) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}

// ==============================================================================
// ⏱️ TIMELINE SCRUBBER (SLIDER WITH CIRCULAR DRAGGER THUMB)
// ==============================================================================
class SVNScrubberView: NSView {
    var progress: Double = 0.0 {
        didSet { needsDisplay = true }
    }
    var isHovered: Bool = false {
        didSet { needsDisplay = true }
    }
    var isDragging: Bool = false {
        didSet { needsDisplay = true }
    }
    
    var onScrubStart: (() -> Void)?
    var onScrubChanged: ((Double) -> Void)?
    var onScrubEnd: ((Double) -> Void)?
    
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func updateTrackingAreas() {
        if let area = trackingArea { removeTrackingArea(area) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        super.updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    override func mouseExited(with event: NSEvent) {
        if !isDragging { isHovered = false }
    }
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        isHovered = true
        onScrubStart?()
        updateProgress(with: event)
    }
    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            updateProgress(with: event)
        }
    }
    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            let pt = convert(event.locationInWindow, from: nil)
            isHovered = bounds.contains(pt)
            onScrubEnd?(progress)
        }
    }
    
    private func updateProgress(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let w = max(1.0, bounds.width - 12.0)
        let val = max(0.0, min(1.0, (pt.x - 6.0) / w))
        progress = val
        onScrubChanged?(progress)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let trackH: CGFloat = 4.0
        let trackY = (bounds.height - trackH) / 2.0
        let trackW = max(1.0, bounds.width - 12.0)
        let trackRect = NSRect(x: 6.0, y: trackY, width: trackW, height: trackH)
        
        // Background track (Separator color)
        let bgPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.0, yRadius: 2.0)
        NSColor.separatorColor.setFill()
        bgPath.fill()
        
        // Active played progress
        let playedW = max(0.0, trackW * CGFloat(progress))
        if playedW > 0 {
            let playedRect = NSRect(x: 6.0, y: trackY, width: playedW, height: trackH)
            let playedPath = NSBezierPath(roundedRect: playedRect, xRadius: 2.0, yRadius: 2.0)
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.9).setFill()
            playedPath.fill()
        }
        
        // Circular Thumb Knob
        let thumbSize: CGFloat = (isHovered || isDragging) ? 14.0 : 12.0
        let thumbX = 6.0 + (trackW * CGFloat(progress)) - (thumbSize / 2.0)
        let thumbY = (bounds.height - thumbSize) / 2.0
        let thumbRect = NSRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        
        let thumbPath = NSBezierPath(ovalIn: thumbRect)
        NSColor.white.setFill()
        thumbPath.fill()
        
        NSColor(white: 0.65, alpha: 1.0).setStroke()
        thumbPath.lineWidth = 1.0
        thumbPath.stroke()
    }
}

// ==============================================================================
// 🔊 HORIZONTAL VOLUME SLIDER
// ==============================================================================
class SVNVolumeSlider: NSView {
    var volume: Float = 1.0 {
        didSet { needsDisplay = true }
    }
    var onVolumeChanged: ((Float) -> Void)?
    var isDragging: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        updateVolume(with: event)
    }
    override func mouseDragged(with event: NSEvent) {
        if isDragging { updateVolume(with: event) }
    }
    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
    
    private func updateVolume(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let w = max(1.0, bounds.width - 10.0)
        let val = max(0.0, min(1.0, Float((pt.x - 5.0) / w)))
        volume = val
        onVolumeChanged?(volume)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let trackH: CGFloat = 3.5
        let trackY = (bounds.height - trackH) / 2.0
        let trackW = max(1.0, bounds.width - 10.0)
        let trackRect = NSRect(x: 5.0, y: trackY, width: trackW, height: trackH)
        
        // Background track
        let bgPath = NSBezierPath(roundedRect: trackRect, xRadius: 1.75, yRadius: 1.75)
        NSColor.separatorColor.setFill()
        bgPath.fill()
        
        // Active Volume
        let activeW = max(0.0, trackW * CGFloat(volume))
        if activeW > 0 {
            let activeRect = NSRect(x: 5.0, y: trackY, width: activeW, height: trackH)
            let activePath = NSBezierPath(roundedRect: activeRect, xRadius: 1.75, yRadius: 1.75)
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.9).setFill()
            activePath.fill()
        }
        
        // Knob
        let knobSize: CGFloat = 10.0
        let knobX = 5.0 + (trackW * CGFloat(volume)) - (knobSize / 2.0)
        let knobY = (bounds.height - knobSize) / 2.0
        let knobRect = NSRect(x: knobX, y: knobY, width: knobSize, height: knobSize)
        
        let knobPath = NSBezierPath(ovalIn: knobRect)
        NSColor.white.setFill()
        knobPath.fill()
        
        NSColor(white: 0.65, alpha: 1.0).setStroke()
        knobPath.lineWidth = 0.8
        knobPath.stroke()
    }
}

// ==============================================================================
// 🎛️ DOCKED BOTTOM TOOLBAR (NATIVE MACOS SYSTEM STYLING)
// ==============================================================================
class SVNDockedBarView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.material = .titlebar
        self.blendingMode = .withinWindow
        self.state = .active
        self.wantsLayer = true
        self.layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 1px top divider line
        let lineY = bounds.height - 1.0
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: lineY))
        line.line(to: NSPoint(x: bounds.width, y: lineY))
        line.lineWidth = 1.0
        line.stroke()
    }
}

// Drag & Drop and Double-Click Video Surface
class VideoPlayerWindowView: NSView {
    var onFileDropped: ((URL) -> Void)?
    var onSubtitleDropped: ((URL) -> Void)?
    var onMouseMove: (() -> Void)?
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    
    private var pendingClickWorkItem: DispatchWorkItem?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string])
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        for item in items {
            if let stringURL = item.string(forType: .fileURL), let url = URL(string: stringURL) {
                let ext = url.pathExtension.lowercased()
                if ["srt", "vtt", "sub", "sbv", "ass", "ssa"].contains(ext) {
                    onSubtitleDropped?(url)
                    return true
                }
                onFileDropped?(url)
                return true
            } else if let rawString = item.string(forType: .string), let url = URL(string: rawString), url.scheme != nil {
                let ext = url.pathExtension.lowercased()
                if ["srt", "vtt", "sub", "sbv", "ass", "ssa"].contains(ext) {
                    onSubtitleDropped?(url)
                    return true
                }
                onFileDropped?(url)
                return true
            }
        }
        return false
    }
    
    override func mouseMoved(with event: NSEvent) {
        onMouseMove?()
        super.mouseMoved(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            // Schedule single click (Play / Pause) after a tiny delay so double click can cancel it
            pendingClickWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onSingleClick?()
            }
            pendingClickWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: workItem)
        } else if event.clickCount >= 2 {
            // Cancel pending single click and perform double click (Fullscreen)
            pendingClickWorkItem?.cancel()
            pendingClickWorkItem = nil
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}

// ==============================================================================
// 📊 REAL-TIME HARDWARE TELEMETRY HUD OVERLAY
// ==============================================================================
class TelemetryHUDView: NSVisualEffectView {
    private let titleLabel = NSTextField()
    private let statsLabel = NSTextField()
    private let closeBtn = NSButton()
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.material = .hudWindow
        self.blendingMode = .withinWindow
        self.state = .active
        self.wantsLayer = true
        self.layer?.cornerRadius = 8.0
        self.layer?.masksToBounds = true
        self.layer?.borderWidth = 1.0
        self.layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor

        // Header Title
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.textColor = .systemGreen
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.stringValue = "⚡ HARDWARE TELEMETRY REPORT"
        titleLabel.frame = NSRect(x: 12, y: frameRect.height - 24, width: 230, height: 16)
        addSubview(titleLabel)

        // Close '✕' Button
        closeBtn.isBordered = false
        closeBtn.title = "✕"
        closeBtn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        closeBtn.contentTintColor = NSColor(white: 0.8, alpha: 0.8)
        closeBtn.frame = NSRect(x: frameRect.width - 24, y: frameRect.height - 24, width: 16, height: 16)
        closeBtn.target = self
        closeBtn.action = #selector(handleClose)
        addSubview(closeBtn)

        // Monospaced Stats Body
        statsLabel.isEditable = false
        statsLabel.isBordered = false
        statsLabel.drawsBackground = false
        statsLabel.textColor = .white
        statsLabel.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
        statsLabel.frame = NSRect(x: 12, y: 10, width: frameRect.width - 24, height: frameRect.height - 40)
        addSubview(statsLabel)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    @objc private func handleClose() {
        onClose?()
    }

    func updateTelemetry(fps: Double, cpuPercent: Double, ramMB: Double, droppedFrames: Int, resolution: String, codec: String, bufferDuration: Double) {
        let text = """
        • Frame Rate : \(String(format: "%.1f", fps)) FPS
        • CPU Overhead: \(String(format: "%.1f", cpuPercent))%
        • RAM Usage   : \(String(format: "%.1f", ramMB)) MB
        • Dropped     : \(droppedFrames) frames
        • Resolution  : \(resolution)
        • Video Codec : \(codec)
        • Forward Buff: \(String(format: "%.2f", bufferDuration))s
        """
        statsLabel.stringValue = text
    }
}

// ==============================================================================
// 💬 SUBTITLE DATA STRUCTURES & MULTI-FORMAT PARSER (SRT, VTT, SUB, ASS, SSA)
// ==============================================================================
struct SubtitleCue: Equatable {
    let startTime: Double // seconds
    let endTime: Double   // seconds
    let text: String
}

struct SubtitleTrack {
    let id: String
    let name: String
    let url: URL?
    let cues: [SubtitleCue]
}

class SVNSubtitleParser {
    static func parseTimestamp(_ str: String) -> Double? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        if parts.count == 3 {
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            return h * 3600.0 + m * 60.0 + s
        } else if parts.count == 2 {
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
            return m * 60.0 + s
        }
        return nil
    }

    static func cleanSubtitleText(_ text: String) -> String {
        var cleaned = text
        // Remove HTML/XML styling tags e.g. <i>, </b>, <font color="...">
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Remove ASS/SSA override blocks e.g. {\pos(100,200)}
        cleaned = cleaned.replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
        // Convert explicit newline tokens
        cleaned = cleaned.replacingOccurrences(of: "\\N", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: "\n")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseSRTOrVTT(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count == 2,
                   let start = parseTimestamp(parts[0]),
                   let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first ?? "") {
                    var textLines: [String] = []
                    i += 1
                    while i < lines.count {
                        let textLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if textLine.isEmpty { break }
                        if textLine.contains("-->") {
                            i -= 1 // backtrack to cue header
                            break
                        }
                        if let _ = Int(textLine), i + 1 < lines.count && lines[i + 1].contains("-->") {
                            break
                        }
                        textLines.append(textLine)
                        i += 1
                    }
                    let rawText = textLines.joined(separator: "\n")
                    let cleaned = cleanSubtitleText(rawText)
                    if !cleaned.isEmpty {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: cleaned))
                    }
                }
            }
            i += 1
        }
        return cues.sorted { $0.startTime < $1.startTime }
    }

    static func parseASS(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Dialogue:") {
                let payload = trimmed.dropFirst(9).trimmingCharacters(in: .whitespaces)
                let parts = payload.components(separatedBy: ",")
                if parts.count >= 10,
                   let start = parseTimestamp(parts[1]),
                   let end = parseTimestamp(parts[2]) {
                    let text = parts[9...].joined(separator: ",")
                    let cleaned = cleanSubtitleText(text)
                    if !cleaned.isEmpty {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: cleaned))
                    }
                }
            }
        }
        return cues.sorted { $0.startTime < $1.startTime }
    }

    static func load(from url: URL) -> [SubtitleCue] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let str = String(data: data, encoding: .utf8) ??
                  String(data: data, encoding: .isoLatin1) ??
                  String(data: data, encoding: .windowsCP1252) ?? ""
        guard !str.isEmpty else { return [] }
        let ext = url.pathExtension.lowercased()
        if ext == "ass" || ext == "ssa" {
            return parseASS(content: str)
        } else {
            return parseSRTOrVTT(content: str)
        }
    }
}

// ==============================================================================
// 📺 VLC-STYLE HIGH-CONTRAST SUBTITLE OVERLAY VIEW
// ==============================================================================
class SVNSubtitleOverlayView: NSView {
    private let label = NSTextField()
    private var currentText: String = ""
    var isFullScreen: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .center
        label.maximumNumberOfLines = 4
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        addSubview(label)
        self.isHidden = true
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    // Click-through: never block video play/pause or double-click gestures
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    func setSubtitle(_ text: String?) {
        let newText = text ?? ""
        if newText == currentText { return }
        currentText = newText
        
        if currentText.isEmpty {
            label.attributedStringValue = NSAttributedString(string: "")
            self.isHidden = true
            return
        }
        
        self.isHidden = false
        let fontSize: CGFloat = isFullScreen ? 26.0 : 20.0
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowOffset = NSSize(width: 0, height: -1.5)
        shadow.shadowBlurRadius = 3.0
        
        // VLC iconic styling: crisp pure white with black stroke and drop shadow
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -3.2, // Negative stroke width strokes AND fills!
            .paragraphStyle: style,
            .shadow: shadow
        ]
        
        label.attributedStringValue = NSAttributedString(string: currentText, attributes: attrs)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        label.frame = bounds
    }
}

// ==============================================================================
// 🚀 MASTER SOVEREIGN VIDEO PLAYER (SOVEREIGN PLAYER)
// ==============================================================================
class SovereignPlayerApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var containerView: VideoPlayerWindowView!
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var timeObserverToken: Any?
    
    // Docked Bottom Toolbar
    var bottomBar: SVNDockedBarView!
    
    // Control Suite (Play, Prev, Stop, Next, Scrubber, Time, Volume, EQ, Fullscreen)
    var playPauseBtn: SVNButton!
    var prevBtn: SVNButton!
    var stopBtn: SVNButton!
    var nextBtn: SVNButton!
    var scrubberView: SVNScrubberView!
    var timeLabel: NSTextField!
    var volumeBtn: SVNButton!
    var volumeSlider: SVNVolumeSlider!
    var eqBtn: SVNButton!
    var ccBtn: SVNButton!
    var fullscreenBtn: SVNButton!
    
    // Telemetry HUD State (Initially Hidden)
    var telemetryHUD: TelemetryHUDView?
    var isTelemetryVisible: Bool = false
    var telemetryTimer: Timer?
    
    // Playback State
    var isPlaying = false
    var isSeeking = false
    var isLiveStream = false
    var currentDuration: Double = 0.0
    var previousVolume: Float = 1.0
    var currentSourceURL: URL?
    var autoHideTimer: Timer?
    var trackingArea: NSTrackingArea?

    // Subtitle Subsystem State
    var subtitleOverlayView: SVNSubtitleOverlayView!
    var subtitleTracks: [SubtitleTrack] = []
    var activeSubtitleTrackIndex: Int = -1 // -1 means Disabled
    var subtitleDelay: Double = 0.0        // Seconds offset (+/- 50ms)
    var subtitleTrackSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Setup Main Window (Named "Sovereign Player")
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1280, height: 720)
        let winW: CGFloat = min(1080, screenSize.width * 0.80)
        let winH: CGFloat = min(640, screenSize.height * 0.75)
        let rect = NSRect(x: (screenSize.width - winW)/2, y: (screenSize.height - winH)/2, width: winW, height: winH)
        
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "Sovereign Player"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 540, height: 320)
        
        // 2. Container View (Video Surface)
        containerView = VideoPlayerWindowView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        containerView.onFileDropped = { [weak self] url in
            self?.loadMediaSource(url: url)
        }
        containerView.onSubtitleDropped = { [weak self] url in
            self?.loadSubtitleFile(url: url)
        }
        containerView.onMouseMove = { [weak self] in
            self?.showControls()
        }
        containerView.onSingleClick = { [weak self] in
            guard let self = self else { return }
            self.togglePlayPause()
            self.showControls()
        }
        containerView.onDoubleClick = { [weak self] in
            self?.toggleFullscreen()
        }
        window.contentView?.addSubview(containerView)
        
        // 2b. VLC-style Subtitle Overlay View
        subtitleOverlayView = SVNSubtitleOverlayView(frame: .zero)
        containerView.addSubview(subtitleOverlayView)
        
        window.acceptsMouseMovedEvents = true
        setupTrackingArea()

        // 3. Setup Docked Bottom Toolbar & Menus
        setupBottomBar()
        setupAppMainMenu()
        setupKeyboardShortcuts()
        
        // 4. In-App Update Checker
        AppUpdater.shared.checkForUpdates(window: self.window)

        // 5. Initial layout
        updateUILayout()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppUpdater.shared.checkForUpdates(window: window)
        
        // 5. Initial source
        let args = CommandLine.arguments
        if args.count > 1 {
            let pathOrUrl = args[1]
            if let url = URL(string: pathOrUrl), url.scheme != nil {
                loadMediaSource(url: url)
            } else {
                loadMediaSource(url: URL(fileURLWithPath: pathOrUrl))
            }
        } else {
            let defaultVideo = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/VID_20220320_143533.mp4")
            if FileManager.default.fileExists(atPath: defaultVideo.path) {
                loadMediaSource(url: defaultVideo)
            } else {
                promptOpenStreamURL()
            }
        }
    }
    
    func setupTrackingArea() {
        if let area = trackingArea { containerView.removeTrackingArea(area) }
        trackingArea = NSTrackingArea(rect: containerView.bounds,
                                      options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                      owner: containerView,
                                      userInfo: nil)
        containerView.addTrackingArea(trackingArea!)
    }

    // ==========================================================================
    // 🎛️ BUILD DOCKED BOTTOM TOOLBAR WITH USER'S CUSTOM ICONS
    // ==========================================================================
    func setupBottomBar() {
        let barH: CGFloat = 42.0
        bottomBar = SVNDockedBarView(frame: NSRect(x: 0, y: 0, width: containerView.bounds.width, height: barH))
        bottomBar.autoresizingMask = [.width, .maxYMargin]
        
        let btnY: CGFloat = 7.0
        let btnSize: CGFloat = 28.0
        
        // 1. Play / Pause Button (Loads icon_play.png / icon_pause.png)
        playPauseBtn = SVNButton(frame: NSRect(x: 10, y: btnY, width: btnSize, height: btnSize),
                                 title: "▶",
                                 symbolName: "play.fill",
                                 assetName: "icon_play",
                                 pointSize: 13,
                                 iconSize: 15.0)
        playPauseBtn.toolTip = "Play / Pause (Space)"
        playPauseBtn.target = self
        playPauseBtn.action = #selector(togglePlayPause)
        bottomBar.addSubview(playPauseBtn)
        
        // 2. Rewind / Step Back (Loads icon_backward.png - rotated 180 from forward)
        prevBtn = SVNButton(frame: NSRect(x: 42, y: btnY, width: btnSize, height: btnSize),
                            title: "◀◀",
                            symbolName: "backward.fill",
                            assetName: "icon_backward",
                            pointSize: 13,
                            iconSize: 15.0)
        prevBtn.toolTip = "Seek Backward 10s (←)"
        prevBtn.target = self
        prevBtn.action = #selector(rewind10)
        bottomBar.addSubview(prevBtn)
        
        // 3. Stop Button (⏹)
        stopBtn = SVNButton(frame: NSRect(x: 74, y: btnY, width: btnSize, height: btnSize),
                            title: "⏹",
                            symbolName: "stop.fill",
                            pointSize: 12,
                            iconSize: 13.0)
        stopBtn.toolTip = "Stop (S)"
        stopBtn.target = self
        stopBtn.action = #selector(stopPlayback)
        bottomBar.addSubview(stopBtn)
        
        // 4. Fast Forward / Step Next (Loads icon_forward.png)
        nextBtn = SVNButton(frame: NSRect(x: 106, y: btnY, width: btnSize, height: btnSize),
                            title: "▶▶",
                            symbolName: "forward.fill",
                            assetName: "icon_forward",
                            pointSize: 13,
                            iconSize: 15.0)
        nextBtn.toolTip = "Seek Forward 10s (→)"
        nextBtn.target = self
        nextBtn.action = #selector(forward10)
        bottomBar.addSubview(nextBtn)
        
        // 5. Timeline Scrubber
        scrubberView = SVNScrubberView(frame: NSRect(x: 142, y: btnY + 4.0, width: 300, height: 20))
        scrubberView.onScrubStart = { [weak self] in
            self?.isSeeking = true
        }
        scrubberView.onScrubChanged = { [weak self] progress in
            guard let self = self, self.currentDuration > 0, !self.isLiveStream else { return }
            let curSec = progress * self.currentDuration
            let curStr = self.formatTime(seconds: curSec)
            let durStr = self.formatTime(seconds: self.currentDuration)
            self.timeLabel.stringValue = "\(curStr) / \(durStr)"
            self.updateSubtitle(currentTime: curSec)
        }
        scrubberView.onScrubEnd = { [weak self] progress in
            guard let self = self, let player = self.player, self.currentDuration > 0, !self.isLiveStream else {
                self?.isSeeking = false
                return
            }
            let targetSec = progress * self.currentDuration
            let targetTime = CMTime(seconds: targetSec, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.isSeeking = false
                self?.updateSubtitle(currentTime: targetSec)
            }
        }
        bottomBar.addSubview(scrubberView)
        
        // 6. Time Display Label (00:00 / 00:00)
        timeLabel = NSTextField(frame: NSRect(x: 450, y: btnY + 5.0, width: 95, height: 18))
        timeLabel.isEditable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false
        timeLabel.alignment = .center
        timeLabel.textColor = .labelColor
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.stringValue = "00:00 / 00:00"
        bottomBar.addSubview(timeLabel)
        
        // 7. Volume Speaker Button
        volumeBtn = SVNButton(frame: NSRect(x: 550, y: btnY, width: btnSize, height: btnSize),
                              title: "🔊",
                              symbolName: "speaker.wave.3.fill",
                              pointSize: 13,
                              iconSize: 15.0)
        volumeBtn.toolTip = "Mute / Unmute (M)"
        volumeBtn.target = self
        volumeBtn.action = #selector(toggleMute)
        bottomBar.addSubview(volumeBtn)
        
        // 8. Horizontal Volume Slider
        volumeSlider = SVNVolumeSlider(frame: NSRect(x: 582, y: btnY + 5.0, width: 65, height: 18))
        volumeSlider.volume = 1.0
        volumeSlider.onVolumeChanged = { [weak self] newVol in
            guard let self = self, let player = self.player else { return }
            player.volume = newVol
            self.updateVolumeIcon(vol: newVol)
        }
        bottomBar.addSubview(volumeSlider)
        
        // 9. Equalizer / Effects (EQ) Button
        eqBtn = SVNButton(frame: NSRect(x: 652, y: btnY, width: btnSize, height: btnSize),
                          title: "EQ",
                          symbolName: "slider.horizontal.3",
                          pointSize: 13,
                          iconSize: 15.0)
        eqBtn.toolTip = "Audio & Video Effects / Speed"
        eqBtn.target = self
        eqBtn.action = #selector(showEffectsMenu)
        bottomBar.addSubview(eqBtn)
        
        // 9.5 Subtitles (CC) Button
        ccBtn = SVNButton(frame: NSRect(x: 684, y: btnY, width: btnSize, height: btnSize),
                          title: "CC",
                          symbolName: "captions.bubble",
                          pointSize: 12,
                          iconSize: 14.0)
        ccBtn.toolTip = "Toggle Subtitles (C)"
        ccBtn.target = self
        ccBtn.action = #selector(toggleSubtitles)
        bottomBar.addSubview(ccBtn)
        
        // 10. Fullscreen Button (Loads icon_fullscreen.png)
        fullscreenBtn = SVNButton(frame: NSRect(x: 684, y: btnY, width: btnSize, height: btnSize),
                                  title: "⤢",
                                  symbolName: "arrow.up.left.and.arrow.down.right",
                                  assetName: "icon_fullscreen",
                                  pointSize: 13,
                                  iconSize: 15.0)
        fullscreenBtn.toolTip = "Toggle Fullscreen (F)"
        fullscreenBtn.target = self
        fullscreenBtn.action = #selector(toggleFullscreen)
        bottomBar.addSubview(fullscreenBtn)
        
        containerView.addSubview(bottomBar)
    }

    // ==========================================================================
    // 📐 RESPONSIVE DOCKED TOOLBAR LAYOUT
    // ==========================================================================
    func updateUILayout() {
        guard containerView != nil, bottomBar != nil else { return }
        
        let winW = containerView.bounds.width
        let winH = containerView.bounds.height
        let isFull = window.styleMask.contains(.fullScreen)
        let barH: CGFloat = 42.0
        
        if isFull {
            let hudW = min(winW - 60.0, 900.0)
            bottomBar.frame = NSRect(x: (winW - hudW) / 2.0, y: 24.0, width: hudW, height: barH)
            bottomBar.layer?.cornerRadius = 10.0
            bottomBar.layer?.borderWidth = 1.0
            bottomBar.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        } else {
            bottomBar.frame = NSRect(x: 0, y: 0, width: winW, height: barH)
            bottomBar.layer?.cornerRadius = 0.0
            bottomBar.layer?.borderWidth = 0.0
        }
        
        let currentBarW = bottomBar.bounds.width
        let btnY: CGFloat = 7.0
        let btnSize: CGFloat = 28.0
        
        // Left Buttons: Play(28) + Prev(28) + Stop(28) + Next(28)
        playPauseBtn.frame = NSRect(x: 10, y: btnY, width: btnSize, height: btnSize)
        prevBtn.frame = NSRect(x: 42, y: btnY, width: btnSize, height: btnSize)
        stopBtn.frame = NSRect(x: 74, y: btnY, width: btnSize, height: btnSize)
        nextBtn.frame = NSRect(x: 106, y: btnY, width: btnSize, height: btnSize)
        
        // Right Controls: Fullscreen(28) + CC(28) + EQ(28) + VolSlider(65) + VolBtn(28) + Time(98)
        let rightMargin: CGFloat = 10.0
        fullscreenBtn.frame = NSRect(x: currentBarW - rightMargin - btnSize, y: btnY, width: btnSize, height: btnSize)
        ccBtn.frame = NSRect(x: currentBarW - rightMargin - btnSize - 30.0, y: btnY, width: btnSize, height: btnSize)
        eqBtn.frame = NSRect(x: currentBarW - rightMargin - btnSize - 62.0, y: btnY, width: btnSize, height: btnSize)
        volumeSlider.frame = NSRect(x: currentBarW - rightMargin - btnSize - 62.0 - 70.0, y: btnY + 5.0, width: 65.0, height: 18.0)
        volumeBtn.frame = NSRect(x: currentBarW - rightMargin - btnSize - 62.0 - 70.0 - btnSize - 4.0, y: btnY, width: btnSize, height: btnSize)
        timeLabel.frame = NSRect(x: currentBarW - rightMargin - btnSize - 62.0 - 70.0 - btnSize - 4.0 - 102.0, y: btnY + 5.0, width: 98.0, height: 18.0)
        
        // Scrubber fills middle area
        let scrubLeft: CGFloat = 142.0
        let scrubRight: CGFloat = currentBarW - rightMargin - btnSize - 62.0 - 70.0 - btnSize - 4.0 - 106.0
        let scrubW = max(60.0, scrubRight - scrubLeft)
        scrubberView.frame = NSRect(x: scrubLeft, y: btnY + 4.0, width: scrubW, height: 20.0)

        // Subtitle Overlay Positioning (VLC style, centered bottom above toolbar)
        if subtitleOverlayView != nil {
            subtitleOverlayView.isFullScreen = isFull
            let subH: CGFloat = isFull ? 120.0 : 85.0
            let subW: CGFloat = min(winW - 60.0, isFull ? 1100.0 : 860.0)
            let subY: CGFloat = isFull ? 76.0 : (barH + 8.0)
            subtitleOverlayView.frame = NSRect(x: (winW - subW) / 2.0, y: subY, width: subW, height: subH)
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isFull {
            playerLayer?.frame = containerView.bounds
        } else {
            playerLayer?.frame = NSRect(x: 0, y: barH, width: winW, height: winH - barH)
        }
        CATransaction.commit()
    }

    func windowDidResize(_ notification: Notification) {
        updateUILayout()
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        updateUILayout()
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        updateUILayout()
    }

    // ==========================================================================
    // 🎬 MEDIA PLAYBACK ENGINE
    // ==========================================================================
    func loadMediaSource(url: URL) {
        currentSourceURL = url
        let isRemote = url.scheme == "http" || url.scheme == "https" || url.scheme == "rtsp" || url.scheme == "srt"
        let isHLS = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains(".m3u8")
        isLiveStream = isRemote && isHLS
        
        let titleName = url.lastPathComponent
        window.title = "\(titleName) — Sovereign Player"
        
        playerLayer?.removeFromSuperlayer()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        var assetOptions: [String: Any] = [
            "AVURLAssetAllowsCellularAccessKey": true,
            "AVURLAssetPreferPreciseDurationAndTimingKey": true
        ]
        if isHLS {
            assetOptions["AVURLAssetOutOfBandMIMETypeKey"] = "application/x-mpegURL"
        }
        
        let asset = AVURLAsset(url: url, options: assetOptions)        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = NSRect(x: 0, y: 42.0, width: containerView.bounds.width, height: containerView.bounds.height - 42.0)
        containerView.layer?.insertSublayer(playerLayer!, at: 0)
        
        // Time Observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let durSec = self.player?.currentItem?.duration.seconds ?? 0.0
            
            if durSec.isInfinite || durSec.isNaN || self.isLiveStream {
                self.isLiveStream = true
                self.scrubberView.progress = 1.0
                self.timeLabel.stringValue = "🔴 Live"
            } else if durSec > 0 && !self.isSeeking {
                self.currentDuration = durSec
                self.scrubberView.progress = time.seconds / durSec
                let curStr = self.formatTime(seconds: time.seconds)
                let durStr = self.formatTime(seconds: durSec)
                self.timeLabel.stringValue = "\(curStr) / \(durStr)"
            }
            self.updateSubtitle(currentTime: time.seconds)
        }
        
        player?.play()
        isPlaying = true
        playPauseBtn.updateIcon(symbolName: "pause.fill", assetName: "icon_pause", fallbackText: "❚❚")
        updateUILayout()

        // Subtitle Reset & Auto-Discovery
        subtitleTracks.removeAll()
        activeSubtitleTrackIndex = -1
        subtitleDelay = 0.0
        subtitleOverlayView?.setSubtitle(nil)
        
        if url.isFileURL {
            let baseWithoutExt = url.deletingPathExtension()
            let siblingExtensions = ["srt", "vtt", "sub", "sbv", "ass", "ssa"]
            for ext in siblingExtensions {
                let subURL = baseWithoutExt.appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: subURL.path) {
                    loadSubtitleFile(url: subURL)
                    break
                }
            }
        }
        updateAppMainMenu()
    }

    func formatTime(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        let m = (total / 60) % 60
        let s = total % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    // ==========================================================================
    // 🎮 ACTION HANDLERS
    // ==========================================================================
    @objc func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            playPauseBtn.updateIcon(symbolName: "play.fill", assetName: "icon_play", fallbackText: "▶")
        } else {
            player.play()
            isPlaying = true
            playPauseBtn.updateIcon(symbolName: "pause.fill", assetName: "icon_pause", fallbackText: "❚❚")
        }
    }
    
    // Stop: pauses, resets timeline to 00:00, and updates scrubber
    @objc func stopPlayback() {
        guard let player = player else { return }
        player.pause()
        player.seek(to: CMTime.zero, toleranceBefore: .zero, toleranceAfter: .zero)
        isPlaying = false
        scrubberView.progress = 0.0
        let durStr = formatTime(seconds: currentDuration)
        timeLabel.stringValue = "00:00 / \(durStr)"
        playPauseBtn.updateIcon(symbolName: "play.fill", assetName: "icon_play", fallbackText: "▶")
        subtitleOverlayView?.setSubtitle(nil)
        showControls(keepVisible: true)
    }
    
    @objc func rewind10() {
        seekOffset(seconds: -10.0)
    }
    
    @objc func forward10() {
        seekOffset(seconds: 10.0)
    }
    
    func seekOffset(seconds: Double) {
        guard let player = player, currentDuration > 0, !isLiveStream else { return }
        let cur = player.currentTime().seconds
        let target = max(0, min(currentDuration, cur + seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.updateSubtitle(currentTime: target)
        }
    }

    func updateVolumeIcon(vol: Float) {
        if vol == 0 {
            volumeBtn.updateIcon(symbolName: "speaker.slash.fill", fallbackText: "🔇")
        } else if vol < 0.5 {
            volumeBtn.updateIcon(symbolName: "speaker.wave.1.fill", fallbackText: "🔉")
        } else {
            volumeBtn.updateIcon(symbolName: "speaker.wave.3.fill", fallbackText: "🔊")
        }
    }
    
    @objc func toggleMute() {
        guard let player = player else { return }
        if player.volume > 0 {
            previousVolume = player.volume
            player.volume = 0
            volumeSlider.volume = 0
            updateVolumeIcon(vol: 0)
        } else {
            let restored = (previousVolume > 0) ? previousVolume : 1.0
            player.volume = restored
            volumeSlider.volume = restored
            updateVolumeIcon(vol: restored)
        }
    }
    
    func adjustVolume(delta: Float) {
        guard let player = player else { return }
        let newVol = max(0.0, min(1.0, player.volume + delta))
        player.volume = newVol
        volumeSlider.volume = newVol
        updateVolumeIcon(vol: newVol)
    }
    
    @objc func toggleFullscreen() {
        window.toggleFullScreen(nil)
    }

    @objc func toggleSubtitles() {
        guard let item = player?.currentItem else { return }
        if #available(macOS 12.0, *) {
            Task {
                do {
                    if let group = try await item.asset.loadMediaSelectionGroup(for: .legible) {
                        await MainActor.run {
                            if item.currentMediaSelection.selectedMediaOption(in: group) != nil {
                                item.select(nil, in: group)
                            } else {
                                let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: .current)
                                if let first = options.first ?? group.options.first {
                                    item.select(first, in: group)
                                }
                            }
                        }
                    }
                } catch {
                    print("Could not load subtitle tracks: \(error)")
                }
            }
        } else {
            if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                if item.currentMediaSelection.selectedMediaOption(in: group) != nil {
                    item.select(nil, in: group)
                } else {
                    let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: .current)
                    if let first = options.first ?? group.options.first {
                        item.select(first, in: group)
                    }
                }
            }
        }
    }

    @objc func showEffectsMenu() {
        let menu = NSMenu(title: "Effects & Speed")
        
        let speedHeader = NSMenuItem(title: "Playback Speed", action: nil, keyEquivalent: "")
        speedHeader.isEnabled = false
        menu.addItem(speedHeader)
        
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let curRate = player?.rate ?? 1.0
        for spd in speeds {
            let isCurrent = (abs(curRate - spd) < 0.05)
            let checkmark = isCurrent ? "✓ " : "    "
            let item = NSMenuItem(title: "\(checkmark)\(spd)x", action: #selector(handleSpeedSelect(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = spd
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        let openFileItem = NSMenuItem(title: "Open File... (⌘O)", action: #selector(promptOpenFile), keyEquivalent: "")
        openFileItem.target = self
        menu.addItem(openFileItem)
        
        let openStreamItem = NSMenuItem(title: "Open Network Stream... (⌘U)", action: #selector(promptOpenStreamURL), keyEquivalent: "")
        openStreamItem.target = self
        menu.addItem(openStreamItem)
        
        menu.addItem(NSMenuItem.separator())
        let addSubItem = NSMenuItem(title: "Add Subtitle File... (⌘S)", action: #selector(promptAddSubtitleFile), keyEquivalent: "")
        addSubItem.target = self
        menu.addItem(addSubItem)
        
        let subTrackItem = NSMenuItem(title: "Subtitles Track", action: nil, keyEquivalent: "")
        let trackMenu = NSMenu(title: "Subtitles Track")
        let disableItem = NSMenuItem(title: (activeSubtitleTrackIndex == -1 ? "✓ " : "    ") + "Disable", action: #selector(handleSubtitleTrackSelect(_:)), keyEquivalent: "")
        disableItem.tag = -1
        disableItem.target = self
        trackMenu.addItem(disableItem)
        
        if subtitleTracks.isEmpty {
            let emptyItem = NSMenuItem(title: "    (No Subtitles Loaded)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            trackMenu.addItem(emptyItem)
        } else {
            for (idx, track) in subtitleTracks.enumerated() {
                let isCurrent = (activeSubtitleTrackIndex == idx)
                let prefix = isCurrent ? "✓ " : "    "
                let item = NSMenuItem(title: "\(prefix)Track \(idx + 1) - \(track.name)", action: #selector(handleSubtitleTrackSelect(_:)), keyEquivalent: "")
                item.tag = idx
                item.target = self
                trackMenu.addItem(item)
            }
        }
        subTrackItem.submenu = trackMenu
        menu.addItem(subTrackItem)

        menu.addItem(NSMenuItem.separator())
        let telemetryTitle = isTelemetryVisible ? "✓ Hide Telemetry Report (T)" : "   Show Telemetry Report (T)"
        let telemetryItem = NSMenuItem(title: telemetryTitle, action: #selector(toggleTelemetry), keyEquivalent: "")
        telemetryItem.target = self
        menu.addItem(telemetryItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: eqBtn.bounds.height + 4), in: eqBtn)
    }
    
    @objc private func handleSpeedSelect(_ sender: NSMenuItem) {
        if let spd = sender.representedObject as? Float {
            player?.rate = isPlaying ? spd : 0.0
        }
    }

    @objc func promptOpenStreamURL() {
        let alert = NSAlert()
        alert.messageText = "Open Network Stream"
        alert.informativeText = "Enter network stream URL (HLS / m3u8 / RTSP / HTTP):"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 440, height: 26))
        inputTextField.placeholderString = "https://example.com/stream.m3u8"
        inputTextField.stringValue = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        alert.accessoryView = inputTextField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let entered = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: entered), url.scheme != nil {
                loadMediaSource(url: url)
            }
        }
    }

    @objc func promptOpenFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.movie, .video, .audio, .mpeg4Movie, .quickTimeMovie]
        } else {
            panel.allowedFileTypes = ["mp4", "mov", "mkv", "hevc", "avi", "webm", "m4v", "m3u8", "m3u"]
        }
        panel.prompt = "Open"
        panel.title = "Open Media"
        
        if panel.runModal() == .OK, let url = panel.url {
            loadMediaSource(url: url)
        }
    }

    // ==========================================================================
    // 💬 SUBTITLE MANAGEMENT & ROUTING
    // ==========================================================================
    func updateSubtitle(currentTime: Double) {
        guard activeSubtitleTrackIndex >= 0 && activeSubtitleTrackIndex < subtitleTracks.count else {
            subtitleOverlayView?.setSubtitle(nil)
            return
        }
        let track = subtitleTracks[activeSubtitleTrackIndex]
        let adjustedTime = currentTime - subtitleDelay
        
        if let cue = track.cues.first(where: { adjustedTime >= $0.startTime && adjustedTime <= $0.endTime }) {
            subtitleOverlayView?.setSubtitle(cue.text)
        } else {
            subtitleOverlayView?.setSubtitle(nil)
        }
    }

    func loadSubtitleFile(url: URL) {
        let cues = SVNSubtitleParser.load(from: url)
        guard !cues.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Subtitle File Invalid or Empty"
            alert.informativeText = "No valid subtitle cues found in:\n\(url.lastPathComponent)\n\nPlease ensure the file contains valid timestamps."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let trackName = url.deletingPathExtension().lastPathComponent
        let track = SubtitleTrack(id: UUID().uuidString, name: trackName, url: url, cues: cues)
        subtitleTracks.append(track)
        activeSubtitleTrackIndex = subtitleTracks.count - 1
        
        if let player = player {
            updateSubtitle(currentTime: player.currentTime().seconds)
        }
        updateAppMainMenu()
    }

    @objc func promptAddSubtitleFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load Subtitle"
        panel.title = "Add Subtitle File"
        
        let subtitleExtensions = ["srt", "vtt", "sub", "sbv", "ass", "ssa"]
        #if canImport(UniformTypeIdentifiers)
        if #available(macOS 12.0, *) {
            var types: [UTType] = []
            for ext in subtitleExtensions {
                if let ut = UTType(filenameExtension: ext) {
                    types.append(ut)
                }
            }
            if !types.isEmpty {
                panel.allowedContentTypes = types
            } else {
                panel.allowedFileTypes = subtitleExtensions
            }
        } else {
            panel.allowedFileTypes = subtitleExtensions
        }
        #else
        panel.allowedFileTypes = subtitleExtensions
        #endif
        panel.allowsOtherFileTypes = false
        
        if panel.runModal() == .OK, let url = panel.url {
            loadSubtitleFile(url: url)
        }
    }

    @objc func handleSubtitleTrackSelect(_ sender: NSMenuItem) {
        activeSubtitleTrackIndex = sender.tag
        if let player = player {
            updateSubtitle(currentTime: player.currentTime().seconds)
        }
        updateAppMainMenu()
    }

    func adjustSubtitleDelay(delta: Double) {
        subtitleDelay += delta
        if let player = player {
            updateSubtitle(currentTime: player.currentTime().seconds)
        }
    }

    @objc func subtitleDelayUp() {
        adjustSubtitleDelay(delta: 0.05) // +50ms
    }

    @objc func subtitleDelayDown() {
        adjustSubtitleDelay(delta: -0.05) // -50ms
    }

    @objc func resetSubtitleDelay() {
        subtitleDelay = 0.0
        if let player = player {
            updateSubtitle(currentTime: player.currentTime().seconds)
        }
    }

    // Top macOS Menu Bar Integration (VLC parity)
    func setupAppMainMenu() {
        let mainMenu = NSMenu()
        
        // 1. Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Sovereign Player", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Sovereign Player", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Sovereign Player", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open File...", action: #selector(promptOpenFile), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Open Network Stream...", action: #selector(promptOpenStreamURL), keyEquivalent: "u")
        fileMenu.addItem(NSMenuItem.separator())
        let addSubFileItem = NSMenuItem(title: "Add Subtitle File...", action: #selector(promptAddSubtitleFile), keyEquivalent: "s")
        fileMenu.addItem(addSubFileItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // 3. Playback Menu
        let playbackMenuItem = NSMenuItem()
        let playbackMenu = NSMenu(title: "Playback")
        playbackMenu.addItem(withTitle: "Play / Pause", action: #selector(togglePlayPause), keyEquivalent: " ")
        playbackMenu.addItem(withTitle: "Stop", action: #selector(stopPlayback), keyEquivalent: "")
        playbackMenu.addItem(withTitle: "Rewind 10 Seconds", action: #selector(rewind10), keyEquivalent: "")
        playbackMenu.addItem(withTitle: "Forward 10 Seconds", action: #selector(forward10), keyEquivalent: "")
        playbackMenu.addItem(NSMenuItem.separator())
        playbackMenu.addItem(withTitle: "Toggle Fullscreen", action: #selector(toggleFullscreen), keyEquivalent: "f")
        playbackMenu.addItem(withTitle: "Mute", action: #selector(toggleMute), keyEquivalent: "m")
        playbackMenuItem.submenu = playbackMenu
        mainMenu.addItem(playbackMenuItem)
        
        // 4. Subtitle Menu
        let subMenuItem = NSMenuItem()
        let subMenu = NSMenu(title: "Subtitle")
        
        let subAdd = NSMenuItem(title: "Add Subtitle File...", action: #selector(promptAddSubtitleFile), keyEquivalent: "")
        subMenu.addItem(subAdd)
        subMenu.addItem(NSMenuItem.separator())
        
        let trackContainer = NSMenuItem(title: "Subtitles Track", action: nil, keyEquivalent: "")
        let trackMenu = NSMenu(title: "Subtitles Track")
        self.subtitleTrackSubmenu = trackMenu
        trackContainer.submenu = trackMenu
        subMenu.addItem(trackContainer)
        
        subMenu.addItem(NSMenuItem.separator())
        let delayUpItem = NSMenuItem(title: "Subtitle Delay +50 ms", action: #selector(subtitleDelayUp), keyEquivalent: "h")
        let delayDownItem = NSMenuItem(title: "Subtitle Delay -50 ms", action: #selector(subtitleDelayDown), keyEquivalent: "g")
        let delayResetItem = NSMenuItem(title: "Reset Subtitle Delay", action: #selector(resetSubtitleDelay), keyEquivalent: "")
        subMenu.addItem(delayUpItem)
        subMenu.addItem(delayDownItem)
        subMenu.addItem(delayResetItem)
        
        subMenuItem.submenu = subMenu
        mainMenu.addItem(subMenuItem)
        
        // 5. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Telemetry Report", action: #selector(toggleTelemetry), keyEquivalent: "t")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        NSApp.mainMenu = mainMenu
        updateAppMainMenu()
    }

    func updateAppMainMenu() {
        guard let trackMenu = subtitleTrackSubmenu else { return }
        trackMenu.removeAllItems()
        
        let disableItem = NSMenuItem(title: (activeSubtitleTrackIndex == -1 ? "✓ " : "    ") + "Disable", action: #selector(handleSubtitleTrackSelect(_:)), keyEquivalent: "")
        disableItem.tag = -1
        disableItem.target = self
        trackMenu.addItem(disableItem)
        
        if subtitleTracks.isEmpty {
            let emptyItem = NSMenuItem(title: "    (No Subtitles Loaded)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            trackMenu.addItem(emptyItem)
        } else {
            for (idx, track) in subtitleTracks.enumerated() {
                let isCurrent = (activeSubtitleTrackIndex == idx)
                let prefix = isCurrent ? "✓ " : "    "
                let item = NSMenuItem(title: "\(prefix)Track \(idx + 1) - \(track.name)", action: #selector(handleSubtitleTrackSelect(_:)), keyEquivalent: "")
                item.tag = idx
                item.target = self
                trackMenu.addItem(item)
            }
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Sovereign Player"
        alert.informativeText = "High-Performance Sovereign Media Player\nVersion 2.2.0 (Open-Core)\nUniversal Metal & AVFoundation Architecture\nEquipped with Subtitle Engine (SRT, VTT, SUB, ASS, SSA)"
        alert.alertStyle = .informational
        alert.runModal()
    }

    // ==========================================================================
    // 📊 HARDWARE TELEMETRY HUD CONTROLLER (SHOW / HIDE ON DEMAND)
    // ==========================================================================
    @objc func toggleTelemetry() {
        if isTelemetryVisible {
            hideTelemetryHUD()
        } else {
            showTelemetryHUD()
        }
    }

    func showTelemetryHUD() {
        isTelemetryVisible = true
        if telemetryHUD == nil {
            let hudW: CGFloat = 260.0
            let hudH: CGFloat = 165.0
            let hudX = containerView.bounds.width - hudW - 16.0
            let hudY = containerView.bounds.height - hudH - 16.0
            let hud = TelemetryHUDView(frame: NSRect(x: hudX, y: hudY, width: hudW, height: hudH))
            hud.autoresizingMask = [.minXMargin, .minYMargin]
            hud.onClose = { [weak self] in
                self?.hideTelemetryHUD()
            }
            containerView.addSubview(hud)
            telemetryHUD = hud
        }

        telemetryHUD?.isHidden = false
        telemetryHUD?.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            telemetryHUD?.animator().alphaValue = 1.0
        }

        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshTelemetryData()
        }
        refreshTelemetryData()
    }

    func hideTelemetryHUD() {
        isTelemetryVisible = false
        telemetryTimer?.invalidate()
        telemetryTimer = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            telemetryHUD?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            self?.telemetryHUD?.isHidden = true
        }
    }

    private func refreshTelemetryData() {
        guard isTelemetryVisible, let hud = telemetryHUD else { return }

        // 1. Memory Usage (Resident set size via mach task_info)
        var ramMB: Double = 32.5
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            ramMB = Double(taskInfo.resident_size) / (1024.0 * 1024.0)
        }

        // 2. CPU Usage (CPU load via thread info)
        var cpuPercent: Double = 0.8
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        if task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS, let threads = threadList {
            var totCpu: Double = 0.0
            for i in 0..<Int(threadCount) {
                var thInfo = thread_basic_info()
                var thInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let thKerr = withUnsafeMutablePointer(to: &thInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(thInfoCount)) {
                        thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &thInfoCount)
                    }
                }
                if thKerr == KERN_SUCCESS && (thInfo.flags & TH_FLAGS_IDLE) == 0 {
                    totCpu += Double(thInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.size)))
            if totCpu > 0 { cpuPercent = totCpu }
        }

        // 3. AVPlayer Item Stats (Resolution, FPS, Codec, Forward Buffer)
        var fps: Double = isPlaying ? 60.0 : 0.0
        var resolution = "1920 × 1080"
        var codec = "H.264 / AAC"
        var forwardBuffer: Double = 0.0
        var dropped: Int = 0

        if let item = player?.currentItem {
            if let track = item.tracks.first(where: { $0.assetTrack?.mediaType == .video })?.assetTrack {
                let sz = track.naturalSize
                if sz.width > 0 && sz.height > 0 {
                    resolution = "\(Int(sz.width)) × \(Int(sz.height))"
                }
                let nominalRate = Double(track.nominalFrameRate)
                if nominalRate > 0 && isPlaying {
                    fps = nominalRate
                }
                for desc in track.formatDescriptions {
                    let mediaSubtype = CMFormatDescriptionGetMediaSubType(desc as! CMFormatDescription)
                    let fourCC = String(format: "%c%c%c%c",
                                        (mediaSubtype >> 24) & 0xff,
                                        (mediaSubtype >> 16) & 0xff,
                                        (mediaSubtype >> 8) & 0xff,
                                        mediaSubtype & 0xff).trimmingCharacters(in: .whitespaces)
                    if !fourCC.isEmpty {
                        codec = fourCC.uppercased()
                    }
                }
            }

            if let accessLog = item.accessLog()?.events.last {
                dropped = accessLog.numberOfDroppedVideoFrames
                if accessLog.indicatedBitrate > 0 {
                    let mbps = accessLog.indicatedBitrate / 1_000_000.0
                    codec += " (\(String(format: "%.1f", mbps)) Mbps)"
                }
            }

            if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
                forwardBuffer = timeRange.duration.seconds
            }
        }

        hud.updateTelemetry(fps: fps,
                            cpuPercent: cpuPercent,
                            ramMB: ramMB,
                            droppedFrames: dropped,
                            resolution: resolution,
                            codec: codec,
                            bufferDuration: forwardBuffer)
    }

    // Auto-Hide Controls only during Full Screen playback
    func showControls(keepVisible: Bool = false) {
        guard window.styleMask.contains(.fullScreen) else {
            bottomBar.alphaValue = 1.0
            NSCursor.unhide()
            return
        }
        
        NSCursor.unhide()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            bottomBar.animator().alphaValue = 1.0
        }
        
        autoHideTimer?.invalidate()
        if !keepVisible && isPlaying {
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                guard let self = self, self.isPlaying, self.window.styleMask.contains(.fullScreen) else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.35
                    self.bottomBar.animator().alphaValue = 0.0
                } completionHandler: {
                    if self.isPlaying && self.window.styleMask.contains(.fullScreen) {
                        NSCursor.setHiddenUntilMouseMoves(true)
                    }
                }
            }
        }
    }

    // Standard Keyboard Shortcuts
    func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            switch event.keyCode {
            case 49: // Spacebar -> Play / Pause
                self.togglePlayPause()
                return nil
            case 1: // 'S' -> Stop, or Cmd+S -> Add Subtitle File
                if event.modifierFlags.contains(.command) {
                    self.promptAddSubtitleFile()
                } else {
                    self.stopPlayback()
                }
                return nil
            case 4: // 'H' -> Subtitle Delay +50ms
                self.subtitleDelayUp()
                return nil
            case 5: // 'G' -> Subtitle Delay -50ms
                self.subtitleDelayDown()
                return nil
            case 123: // Left Arrow -> Seek -10s (or -60s with Option)
                let delta = event.modifierFlags.contains(.option) ? -60.0 : -10.0
                self.seekOffset(seconds: delta)
                return nil
            case 124: // Right Arrow -> Seek +10s (or +60s with Option)
                let delta = event.modifierFlags.contains(.option) ? 60.0 : 10.0
                self.seekOffset(seconds: delta)
                return nil
            case 126: // Up Arrow -> Volume +5%
                self.adjustVolume(delta: 0.05)
                return nil
            case 125: // Down Arrow -> Volume -5%
                self.adjustVolume(delta: -0.05)
                return nil
            case 3: // 'F' -> Fullscreen
                self.toggleFullscreen()
                return nil
            case 46: // 'M' -> Mute
                self.toggleMute()
                return nil
            case 8: // 'C' -> Toggle Subtitles
                self.toggleSubtitles()
                return nil
            case 14: // 'E' -> Step one frame
                self.seekOffset(seconds: 1.0 / 30.0)
                return nil
            case 32: // 'U' with Cmd -> Open Stream URL
                if event.modifierFlags.contains(.command) {
                    self.promptOpenStreamURL()
                    return nil
                }
            case 17: // 'T' -> Toggle Telemetry HUD
                self.toggleTelemetry()
                return nil
            case 31: // 'O' with Cmd -> Open File
                if event.modifierFlags.contains(.command) {
                    self.promptOpenFile()
                    return nil
                }
            default:
                break
            }
            return event
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return true
    }
}

// ==============================================================================
// 🏁 RUNTIME ENTRY POINT
// ==============================================================================
let app = NSApplication.shared
let delegate = SovereignPlayerApp()
app.delegate = delegate
app.run()

// ==============================================================================
// 🔄 AUTOMATIC IN-APP UPDATE CHECKER (GITHUB RELEASES API)
// ==============================================================================
class AppUpdater {
    static let shared = AppUpdater()
    let currentVersion = "v2.2.0"
    let repoURL = "https://api.github.com/repos/TheSPST/sovereign-media-player/releases/latest"

    func checkForUpdates(window: NSWindow?) {
        guard let url = URL(string: repoURL) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let latestVersion = json["tag_name"] as? String,
                   let htmlUrl = json["html_url"] as? String {
                    
                    if latestVersion != self.currentVersion {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Update Available"
                            alert.informativeText = "A new version of Sovereign Media Player (\(latestVersion)) is available. You are currently running \(self.currentVersion)."
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "Download Update")
                            alert.addButton(withTitle: "Later")
                            
                            if let win = window {
                                alert.beginSheetModal(for: win) { response in
                                    if response == .alertFirstButtonReturn, let updateURL = URL(string: htmlUrl) {
                                        NSWorkspace.shared.open(updateURL)
                                    }
                                }
                            } else {
                                if alert.runModal() == .alertFirstButtonReturn, let updateURL = URL(string: htmlUrl) {
                                    NSWorkspace.shared.open(updateURL)
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Failed to parse GitHub releases JSON")
            }
        }
        task.resume()
    }
}
