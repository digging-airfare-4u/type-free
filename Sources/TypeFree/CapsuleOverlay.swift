import Cocoa
import QuartzCore

/// Elegant floating capsule overlay shown at bottom-center during recording.
final class CapsuleOverlay {

    private var panel: NSPanel?
    private var contentView: CapsuleContentView?
    private var dismissTimer: Timer?

    private let capsuleHeight: CGFloat = 56
    private let capsuleWidth: CGFloat = 440
    private let refiningCapsuleWidth: CGFloat = 260
    private let cornerRadius: CGFloat = 28
    /// Extra space around the capsule inside the panel so NSShadow can render without clipping.
    private let shadowPad: CGFloat = 22

    func show() {
        // Immediately kill any existing panel — no animation — so there is never
        // more than one capsule on screen at the same time.
        dismissTimer?.invalidate()
        dismissTimer = nil
        if let old = panel {
            old.orderOut(nil)
            contentView?.waveformView.stopAnimating()
        }
        panel = nil
        contentView = nil

        let panelW = capsuleWidth + shadowPad * 2
        let panelH = capsuleHeight + shadowPad * 2
        let frame = centeredFrame(width: panelW, height: panelH)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // hasShadow=false: the system shadow adds a 1px white rim-light that cannot be
        // removed any other way. We draw our own shadow in CapsuleContentView.draw().
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        let content = CapsuleContentView(
            frame: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            cornerRadius: cornerRadius,
            shadowPad: shadowPad
        )
        panel.contentView = content

        self.panel = panel
        self.contentView = content

        // Entrance animation: spring from below
        let finalFrame = panel.frame
        var startFrame = finalFrame
        startFrame.origin.y -= 30
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func updateText(_ text: String, animated: Bool = true) {
        contentView?.scrollToLatest(text, animated: animated)
    }

    func updateRMS(_ rms: Float) {
        contentView?.waveformView.updateRMS(rms)
    }

    func showRefining() {
        contentView?.showRefining()
        animatePanelWidth(to: refiningCapsuleWidth, duration: 0.22)
    }

    func hideRefining(completion: (() -> Void)? = nil) {
        contentView?.hideRefining()
        animatePanelWidth(to: capsuleWidth, duration: 0.24, completion: completion)
    }

    func dismiss(afterDelay delay: TimeInterval = 0) {
        dismissTimer?.invalidate()
        if delay > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.performDismiss()
            }
        } else {
            performDismiss()
        }
    }

    private func performDismiss() {
        guard let panel = panel else { return }

        // Capture old panel/contentView locally and nil self's refs immediately.
        // If show() is called right after dismiss(), it will assign a new panel before
        // this animation's completion handler fires — without this, the completion handler
        // would overwrite self.panel/contentView with nil, orphaning the new capsule on screen.
        let panelToClose = panel
        let contentToStop = contentView
        self.panel = nil
        self.contentView = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            panelToClose.animator().alphaValue = 0
            let f = panelToClose.frame
            panelToClose.animator().setFrame(
                NSRect(x: f.midX - f.width * 0.45, y: f.origin.y - 8,
                       width: f.width * 0.9, height: f.height * 0.9),
                display: true
            )
        }, completionHandler: {
            panelToClose.orderOut(nil)
            contentToStop?.waveformView.stopAnimating()
        })
    }

    private func animatePanelWidth(
        to visibleWidth: CGFloat,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard let panel = panel else {
            completion?()
            return
        }

        let targetWidth = visibleWidth + shadowPad * 2
        guard abs(panel.frame.width - targetWidth) > 0.5 else {
            completion?()
            return
        }

        var frame = panel.frame
        let centerX = frame.midX
        frame.size.width = targetWidth
        frame.origin.x = centerX - targetWidth / 2

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: {
            completion?()
        })
    }

    private func centeredFrame(width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 60, width: width, height: height)
        }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        // Keep the visible capsule at ~60pt above the Dock
        let y = screenFrame.minY + 60 - shadowPad
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Capsule Content View

/// The panel's contentView. Draws the rounded-rect capsule (+ shadow) via draw(),
/// so no system white border artifact can appear. Subviews are offset by shadowPad.
final class CapsuleContentView: NSView {

    let waveformView = WaveformView()
    private let textClipView = NSView()      // clips the scrolling label
    private let textLabel = NSTextField(labelWithString: "")
    private let refiningLabel = NSTextField(labelWithString: "Refining...")

    private let cornerRadius: CGFloat
    private let shadowPad: CGFloat

    private let textFont = NSFont.systemFont(ofSize: 15, weight: .medium)

    override var isOpaque: Bool { false }

    init(frame: NSRect, cornerRadius: CGFloat, shadowPad: CGFloat) {
        self.cornerRadius = cornerRadius
        self.shadowPad = shadowPad
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func setup() {
        let sp = shadowPad

        // Waveform
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(waveformView)

        // Clip container for the scrolling text label
        textClipView.wantsLayer = true
        textClipView.layer?.masksToBounds = true
        textClipView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textClipView)

        // Text label inside clip view — layer-backed + frame-based for CASpringAnimation
        textLabel.font = textFont
        textLabel.textColor = .white
        textLabel.lineBreakMode = .byClipping
        textLabel.maximumNumberOfLines = 1
        textLabel.autoresizingMask = []
        textLabel.wantsLayer = true  // GPU-backed, required for CASpringAnimation
        textClipView.addSubview(textLabel)

        // Refining label
        refiningLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        refiningLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        refiningLabel.translatesAutoresizingMaskIntoConstraints = false
        refiningLabel.isHidden = true
        addSubview(refiningLabel)

        NSLayoutConstraint.activate([
            // Waveform: shadowPad + 16pt from left edge of panel
            waveformView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sp + 16),
            waveformView.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),

            // Clip view fills the text area within the capsule
            textClipView.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 12),
            textClipView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(sp + 16)),
            textClipView.topAnchor.constraint(equalTo: topAnchor, constant: sp),
            textClipView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -sp),

            refiningLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 12),
            refiningLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        waveformView.startAnimating()
    }

    /// Update text and spring-animate so the LATEST content is always visible.
    func scrollToLatest(_ text: String, animated: Bool = true) {
        let clipW = textClipView.bounds.width
        let clipH = textClipView.bounds.height
        guard clipW > 0 && clipH > 0 else { return }

        let attrs: [NSAttributedString.Key: Any] = [.font: textFont]

        // Find the longest SUFFIX of `text` that fits within clipW.
        // textLabel is always clipW wide — no oversized backing layer, no black frame.
        var tail = text
        while !tail.isEmpty {
            if (tail as NSString).size(withAttributes: attrs).width <= clipW { break }
            tail = String(tail[tail.index(after: tail.startIndex)...])
        }

        let textH = ceil((tail as NSString).size(withAttributes: attrs).height)
        let centerY = (clipH - textH) / 2

        // Only animate when the visible tail actually changes
        guard tail != textLabel.stringValue else { return }

        let isScrolling = tail.count < text.count  // tail was trimmed → content shifted right→left

        // Update label content and frame atomically
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLabel.stringValue = tail
        textLabel.frame = NSRect(x: 0, y: centerY, width: clipW, height: textH)
        textLabel.layer?.transform = CATransform3DIdentity
        CATransaction.commit()

        // Only slide-in when actually scrolling (text overflows).
        // When text is short, skip animation — no jitter at the start.
        guard animated && isScrolling else { return }

        let spring = CASpringAnimation(keyPath: "transform.translation.x")
        spring.fromValue  = 6
        spring.toValue    = 0
        spring.damping    = 28
        spring.stiffness  = 300
        spring.mass       = 1.0
        spring.initialVelocity = 0
        spring.duration   = spring.settlingDuration
        textLabel.layer?.add(spring, forKey: "slideIn")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()

        // Draw the capsule with shadow — all within draw() so no system rim-light can interfere
        let capsuleRect = bounds.insetBy(dx: shadowPad, dy: shadowPad)
        let path = NSBezierPath(roundedRect: capsuleRect, xRadius: cornerRadius, yRadius: cornerRadius)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.55)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()

        NSColor(white: 0.1, alpha: 0.9).setFill()
        path.fill()

        ctx.restoreGraphicsState()
    }

    func showRefining() {
        waveformView.isRefining = true
        refiningLabel.isHidden = false
        textClipView.isHidden = true
        textLabel.layer?.removeAnimation(forKey: "slideIn")
    }

    func hideRefining() {
        waveformView.isRefining = false
        refiningLabel.isHidden = true
        textClipView.isHidden = false
    }
}

// MARK: - Waveform View (5-bar, RMS-driven)

final class WaveformView: NSView {

    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let barCount = 5
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4

    private var barLayers: [CALayer] = []
    private var displayLink: CVDisplayLink?
    private var smoothedRMS: Float = 0
    private var targetRMS: Float = 0

    var isRefining = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        guard let parentLayer = layer else { return }
        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = barWidth / 2
            parentLayer.addSublayer(bar)
            barLayers.append(bar)
            _ = i
        }
    }

    func startAnimating() {
        guard displayLink == nil else { return }

        func displayLinkCallback(
            _ displayLink: CVDisplayLink,
            _ inNow: UnsafePointer<CVTimeStamp>,
            _ inOutputTime: UnsafePointer<CVTimeStamp>,
            _ flagsIn: CVOptionFlags,
            _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
            _ context: UnsafeMutableRawPointer?
        ) -> CVReturn {
            guard let context = context else { return kCVReturnError }
            let view = Unmanaged<WaveformView>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { view.tick() }
            return kCVReturnSuccess
        }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        if let link = link {
            CVDisplayLinkSetOutputCallback(link, displayLinkCallback,
                                           Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(link)
            self.displayLink = link
        }
    }

    func stopAnimating() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    func updateRMS(_ rms: Float) {
        targetRMS = rms
    }

    private func tick() {
        let alpha: Float = targetRMS > smoothedRMS ? 0.4 : 0.15
        smoothedRMS += alpha * (targetRMS - smoothedRMS)

        let maxBarHeight = bounds.height
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let time = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for i in 0..<barCount {
            let weight = weights[i]
            let barHeight: CGFloat

            if isRefining {
                let travel = fmod(time * 4.2, Double(barCount) + 1.8) - 0.4
                let distance = abs(Double(i) - travel)
                let focus = max(0, 1 - distance / 1.15)
                let sweep = focus * focus * (3 - 2 * focus)
                let base = 0.18 + 0.04 * sin(time * 2.4 + Double(i) * 0.35)
                let amplitude = base + 0.52 * sweep
                barHeight = max(minBarHeight, maxBarHeight * CGFloat(amplitude) * weight)
            } else if smoothedRMS < 0.025 {
                // Idle: smooth breathing wave
                let phase = time * 2.0 + Double(i) * 0.5
                let breath = CGFloat(0.35 + 0.2 * sin(phase))
                barHeight = max(8, maxBarHeight * breath * weight)
            } else {
                let jitter = CGFloat.random(in: 0.96...1.04)
                barHeight = max(minBarHeight, maxBarHeight * CGFloat(smoothedRMS) * weight * jitter)
            }

            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = (bounds.height - barHeight) / 2
            barLayers[i].frame = CGRect(x: x, y: y, width: barWidth, height: barHeight)
        }

        CATransaction.commit()
    }
}
