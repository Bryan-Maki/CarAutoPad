import UIKit

public final class DpiPreviewView: UIView {
    public var dpi: Int = 160 {
        didSet {
            if oldValue != dpi {
                setNeedsDisplay()
            }
        }
    }

    public var panelWidthPx: Int = 1920 {
        didSet {
            if oldValue != panelWidthPx {
                setNeedsDisplay()
            }
        }
    }

    public var panelHeightPx: Int = 1080 {
        didSet {
            if oldValue != panelHeightPx {
                setNeedsDisplay()
            }
        }
    }

    public var codecWidthPx: Int = 0 {
        didSet {
            if oldValue != codecWidthPx {
                setNeedsDisplay()
            }
        }
    }

    public var codecHeightPx: Int = 0 {
        didSet {
            if oldValue != codecHeightPx {
                setNeedsDisplay()
            }
        }
    }

    public var activeWidthPx: Int = 0 {
        didSet {
            if oldValue != activeWidthPx {
                setNeedsDisplay()
            }
        }
    }

    public var activeHeightPx: Int = 0 {
        didSet {
            if oldValue != activeHeightPx {
                setNeedsDisplay()
            }
        }
    }

    public var marginWidthPx: Int = 0 {
        didSet {
            if oldValue != marginWidthPx {
                setNeedsDisplay()
            }
        }
    }

    public var marginHeightPx: Int = 0 {
        didSet {
            if oldValue != marginHeightPx {
                setNeedsDisplay()
            }
        }
    }

    public var isRightHandDrive: Bool = false {
        didSet {
            if oldValue != isRightHandDrive {
                setNeedsDisplay()
            }
        }
    }

    public var fitMode: VideoFitMode = .fillMargin {
        didSet {
            if oldValue != fitMode {
                setNeedsDisplay()
            }
        }
    }

    private var effectivePanelWidthPx: Int {
        return activeWidthPx > 0 ? activeWidthPx : max(1, panelWidthPx)
    }

    private var effectivePanelHeightPx: Int {
        return activeHeightPx > 0 ? activeHeightPx : max(1, panelHeightPx)
    }

    private var isPortraitLayout: Bool {
        return effectivePanelHeightPx > effectivePanelWidthPx
    }

    public var virtualWidthDp: Int {
        guard dpi > 0 else { return 0 }
        let w = activeWidthPx > 0 ? activeWidthPx : panelWidthPx
        return (w * 160) / dpi
    }

    public var virtualHeightDp: Int {
        guard dpi > 0 else { return 0 }
        let h = activeHeightPx > 0 ? activeHeightPx : panelHeightPx
        return (h * 160) / dpi
    }

    public var isCoolwalkSplitScreen: Bool {
        if isPortraitLayout {
            return virtualWidthDp >= 480 && virtualHeightDp >= 700
        }
        return virtualWidthDp >= 800
    }

    public var densityScale: CGFloat {
        guard dpi > 0 else { return 1.0 }
        return CGFloat(dpi) / 160.0
    }

    public private(set) var lastCalculatedRailWidth: CGFloat = 0
    public private(set) var lastCalculatedSecondaryCardWidth: CGFloat = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        layer.masksToBounds = true
        layer.cornerRadius = 14
    }

    @discardableResult
    public func calculateLayoutMetrics(in rect: CGRect) -> (railWidth: CGFloat, secondaryCardWidth: CGFloat, isSplit: Bool) {
        let padX: CGFloat = 10.0
        let headerH: CGFloat = 22.0
        let bottomPad: CGFloat = 8.0
        let availW = rect.width - padX * 2
        let availH = rect.height - headerH - bottomPad
        guard availW > 40 && availH > 40 else {
            lastCalculatedRailWidth = 0
            lastCalculatedSecondaryCardWidth = 0
            return (0, 0, false)
        }

        let effW = CGFloat(effectivePanelWidthPx)
        let effH = CGFloat(effectivePanelHeightPx)
        let panelAspect: CGFloat = (effW > 0 && effH > 0) ? (effW / effH) : (16.0 / 9.0)

        var screenW = availW
        var screenH = screenW / panelAspect
        if screenH > availH {
            screenH = availH
            screenW = screenH * panelAspect
        }

        let innerPadding: CGFloat = max(4.0, min(screenW, screenH) * 0.025)
        let contentWidth = max(10.0, screenW - innerPadding * 2)
        let contentHeight = max(10.0, screenH - innerPadding * 2)

        let dpToCanvasW = screenW / CGFloat(max(1, virtualWidthDp))
        let dpToCanvasH = screenH / CGFloat(max(1, virtualHeightDp))
        let isSplit = isCoolwalkSplitScreen

        if isPortraitLayout {
            let bottomBarHeight = min(contentHeight * 0.16, max(16.0, 56.0 * dpToCanvasH))
            let gap = max(3.0, min(contentWidth, contentHeight) * 0.018)
            let secondaryRowWidth = isSplit ? max(16.0, (contentWidth - gap) * 0.5) : 0
            lastCalculatedRailWidth = bottomBarHeight
            lastCalculatedSecondaryCardWidth = secondaryRowWidth
            return (bottomBarHeight, secondaryRowWidth, isSplit)
        } else {
            let railWidth: CGFloat = isSplit ? min(contentWidth * 0.15, max(14.0, 60.0 * dpToCanvasW)) : 0
            let bottomBarHeight: CGFloat = isSplit ? 0 : min(contentHeight * 0.22, max(14.0, 52.0 * dpToCanvasH))

            let gap = max(3.5, min(contentWidth, contentHeight) * 0.02)
            let cardsW = contentWidth - (isSplit ? (railWidth + gap) : 0)
            let targetSecondaryW = 340.0 * dpToCanvasW
            let maxSecondaryW = (cardsW - gap) * 0.44
            let minSecondaryW = (cardsW - gap) * 0.28
            let secondaryCardWidth = isSplit ? min(maxSecondaryW, max(minSecondaryW, targetSecondaryW)) : 0

            lastCalculatedRailWidth = isSplit ? railWidth : bottomBarHeight
            lastCalculatedSecondaryCardWidth = secondaryCardWidth
            return (lastCalculatedRailWidth, lastCalculatedSecondaryCardWidth, isSplit)
        }
    }

    public override func draw(_ rect: CGRect) {
        _ = calculateLayoutMetrics(in: rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()

        let padX: CGFloat = 10.0
        let headerH: CGFloat = 22.0
        let bottomPad: CGFloat = 8.0
        let availW = rect.width - padX * 2
        let availH = rect.height - headerH - bottomPad
        guard availW > 40 && availH > 40 else {
            ctx.restoreGState()
            return
        }

        let outerBezel = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        ctx.setFillColor(UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 0.98).cgColor)
        outerBezel.fill()
        ctx.setStrokeColor(UIColor(white: 0.24, alpha: 0.7).cgColor)
        ctx.setLineWidth(1.0)
        outerBezel.stroke()

        drawStatusHeader(in: CGRect(x: padX, y: 4, width: availW, height: headerH - 4))

        let effW = CGFloat(effectivePanelWidthPx)
        let effH = CGFloat(effectivePanelHeightPx)
        let panelAspect: CGFloat = (effW > 0 && effH > 0) ? (effW / effH) : (16.0 / 9.0)

        var screenW = availW
        var screenH = screenW / panelAspect
        if screenH > availH {
            screenH = availH
            screenW = screenH * panelAspect
        }

        let screenLeft = padX + (availW - screenW) / 2.0
        let screenTop = headerH + (availH - screenH) / 2.0
        let screenRect = CGRect(x: screenLeft, y: screenTop, width: screenW, height: screenH)

        ctx.saveGState()
        let bezelRadius = max(8.0, min(screenW, screenH) * 0.045)
        let screenBezel = UIBezierPath(roundedRect: screenRect, cornerRadius: bezelRadius)
        ctx.setFillColor(UIColor(red: 0.03, green: 0.035, blue: 0.045, alpha: 1.0).cgColor)
        screenBezel.fill()
        ctx.setStrokeColor(UIColor(white: 0.32, alpha: 0.85).cgColor)
        ctx.setLineWidth(1.5)
        screenBezel.stroke()

        let innerInset = max(4.0, min(screenW, screenH) * 0.025)
        let contentRect = screenRect.insetBy(dx: innerInset, dy: innerInset)
        UIBezierPath(roundedRect: contentRect, cornerRadius: max(4.0, bezelRadius - innerInset)).addClip()

        if isPortraitLayout {
            drawPortraitCoolwalkLayout(ctx: ctx, contentRect: contentRect)
        } else {
            drawLandscapeCoolwalkLayout(ctx: ctx, contentRect: contentRect)
        }

        ctx.restoreGState()
        ctx.restoreGState()
    }

    private func drawStatusHeader(in headerRect: CGRect) {
        let isSplit = isCoolwalkSplitScreen
        let layoutModeText: String
        if isPortraitLayout {
            layoutModeText = isSplit ? "Portrait Coolwalk (Top Map + Lower Cards)" : "Portrait Single Card"
        } else {
            layoutModeText = isSplit ? "Coolwalk Split Screen" : "Single Card Compact"
        }

        let statusText: String
        if marginWidthPx > 0 || marginHeightPx > 0 {
            statusText = String(
                format: "Active: %d×%d (%d×%d crop) • %d DPI (%d×%d dp) • %@",
                effectivePanelWidthPx, effectivePanelHeightPx,
                codecWidthPx, codecHeightPx,
                dpi, virtualWidthDp, virtualHeightDp, layoutModeText
            )
        } else {
            statusText = String(
                format: "Active: %d×%d • %d DPI (%d×%d dp) • %@",
                effectivePanelWidthPx, effectivePanelHeightPx,
                dpi, virtualWidthDp, virtualHeightDp, layoutModeText
            )
        }

        let font = UIFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let textColor = isSplit
            ? UIColor(red: 0.25, green: 0.88, blue: 0.55, alpha: 0.96)
            : UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 0.96)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let textSize = (statusText as NSString).size(withAttributes: attrs)
        let drawY = headerRect.minY + max(0, (headerRect.height - textSize.height) / 2.0)
        let drawRect = CGRect(x: headerRect.minX, y: drawY, width: headerRect.width, height: textSize.height + 2)
        (statusText as NSString).draw(in: drawRect, withAttributes: attrs)
    }

    private func drawPortraitCoolwalkLayout(ctx: CGContext, contentRect: CGRect) {
        let gap = max(3.5, min(contentRect.width, contentRect.height) * 0.018)
        let dockHeight = min(contentRect.height * 0.14, max(18.0, lastCalculatedRailWidth))
        let dockRect = CGRect(
            x: contentRect.minX,
            y: contentRect.maxY - dockHeight,
            width: contentRect.width,
            height: dockHeight
        )

        let cardsAreaHeight = max(10.0, contentRect.height - dockHeight - gap)
        let cardsAreaRect = CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width,
            height: cardsAreaHeight
        )

        if isCoolwalkSplitScreen {
            let dpRatio = min(max(CGFloat(dpi - 100) / 220.0, 0.0), 1.0)
            let secondaryRowFraction: CGFloat = 0.34 + 0.07 * dpRatio
            let secondaryRowH = max(28.0, (cardsAreaRect.height - gap) * secondaryRowFraction)
            let mapH = max(36.0, cardsAreaRect.height - gap - secondaryRowH)

            let mapRect = CGRect(
                x: cardsAreaRect.minX,
                y: cardsAreaRect.minY,
                width: cardsAreaRect.width,
                height: mapH
            )

            let lowerRowY = mapRect.maxY + gap
            let halfW = max(16.0, (cardsAreaRect.width - gap) / 2.0)

            let leftCardRect = CGRect(
                x: cardsAreaRect.minX,
                y: lowerRowY,
                width: halfW,
                height: secondaryRowH
            )
            let rightCardRect = CGRect(
                x: leftCardRect.maxX + gap,
                y: lowerRowY,
                width: cardsAreaRect.width - halfW - gap,
                height: secondaryRowH
            )

            drawMapCard(ctx: ctx, rect: mapRect, showEtaOverlay: true)
            if isRightHandDrive {
                drawMediaCard(ctx: ctx, rect: leftCardRect)
                drawCommunicationCard(ctx: ctx, rect: rightCardRect)
            } else {
                drawCommunicationCard(ctx: ctx, rect: leftCardRect)
                drawMediaCard(ctx: ctx, rect: rightCardRect)
            }
        } else {
            drawMapCard(ctx: ctx, rect: cardsAreaRect, showEtaOverlay: true)
        }

        drawHorizontalBottomDock(ctx: ctx, rect: dockRect)
    }

    private func drawLandscapeCoolwalkLayout(ctx: CGContext, contentRect: CGRect) {
        let gap = max(3.5, min(contentRect.width, contentRect.height) * 0.02)
        let isSplit = isCoolwalkSplitScreen

        if isSplit {
            let railWidth = min(contentRect.width * 0.14, max(16.0, lastCalculatedRailWidth))
            let railRect: CGRect
            let cardsContainerRect: CGRect

            if isRightHandDrive {
                railRect = CGRect(
                    x: contentRect.maxX - railWidth,
                    y: contentRect.minY,
                    width: railWidth,
                    height: contentRect.height
                )
                cardsContainerRect = CGRect(
                    x: contentRect.minX,
                    y: contentRect.minY,
                    width: max(20.0, contentRect.width - railWidth - gap),
                    height: contentRect.height
                )
            } else {
                railRect = CGRect(
                    x: contentRect.minX,
                    y: contentRect.minY,
                    width: railWidth,
                    height: contentRect.height
                )
                cardsContainerRect = CGRect(
                    x: contentRect.minX + railWidth + gap,
                    y: contentRect.minY,
                    width: max(20.0, contentRect.width - railWidth - gap),
                    height: contentRect.height
                )
            }

            drawVerticalNavigationRail(ctx: ctx, rect: railRect)

            let secondaryW = min(cardsContainerRect.width * 0.44, max(cardsContainerRect.width * 0.28, lastCalculatedSecondaryCardWidth))
            let primaryW = max(24.0, cardsContainerRect.width - gap - secondaryW)

            let mapRect: CGRect
            let secondaryColumnRect: CGRect

            if isRightHandDrive {
                secondaryColumnRect = CGRect(
                    x: cardsContainerRect.minX,
                    y: cardsContainerRect.minY,
                    width: secondaryW,
                    height: cardsContainerRect.height
                )
                mapRect = CGRect(
                    x: secondaryColumnRect.maxX + gap,
                    y: cardsContainerRect.minY,
                    width: primaryW,
                    height: cardsContainerRect.height
                )
            } else {
                mapRect = CGRect(
                    x: cardsContainerRect.minX,
                    y: cardsContainerRect.minY,
                    width: primaryW,
                    height: cardsContainerRect.height
                )
                secondaryColumnRect = CGRect(
                    x: mapRect.maxX + gap,
                    y: cardsContainerRect.minY,
                    width: secondaryW,
                    height: cardsContainerRect.height
                )
            }

            drawMapCard(ctx: ctx, rect: mapRect, showEtaOverlay: true)

            let topCardH = max(18.0, (secondaryColumnRect.height - gap) * 0.54)
            let bottomCardH = max(16.0, secondaryColumnRect.height - gap - topCardH)

            let mediaRect = CGRect(
                x: secondaryColumnRect.minX,
                y: secondaryColumnRect.minY,
                width: secondaryColumnRect.width,
                height: topCardH
            )
            let commRect = CGRect(
                x: secondaryColumnRect.minX,
                y: mediaRect.maxY + gap,
                width: secondaryColumnRect.width,
                height: bottomCardH
            )

            drawMediaCard(ctx: ctx, rect: mediaRect)
            drawCommunicationCard(ctx: ctx, rect: commRect)
        } else {
            let bottomBarH = min(contentRect.height * 0.18, max(16.0, lastCalculatedRailWidth))
            let dockRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - bottomBarH,
                width: contentRect.width,
                height: bottomBarH
            )
            let mapRect = CGRect(
                x: contentRect.minX,
                y: contentRect.minY,
                width: contentRect.width,
                height: max(20.0, contentRect.height - bottomBarH - gap)
            )
            drawMapCard(ctx: ctx, rect: mapRect, showEtaOverlay: true)
            drawHorizontalBottomDock(ctx: ctx, rect: dockRect)
        }
    }

    private func drawVerticalNavigationRail(ctx: CGContext, rect: CGRect) {
        guard rect.width > 8 && rect.height > 20 else { return }
        ctx.saveGState()
        let corner = min(rect.width * 0.35, 10.0)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        ctx.setFillColor(UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 0.98).cgColor)
        path.fill()
        path.addClip()

        let w = rect.width
        let cx = rect.midX

        let gridCenterY = rect.minY + w * 0.55
        drawLauncherGrid(ctx: ctx, center: CGPoint(x: cx, y: gridCenterY), span: w * 0.42)

        let iconColors: [UIColor] = [
            UIColor(red: 0.18, green: 0.65, blue: 0.40, alpha: 1.0),
            UIColor(red: 0.92, green: 0.22, blue: 0.26, alpha: 1.0),
            UIColor(red: 0.22, green: 0.52, blue: 0.96, alpha: 1.0),
            UIColor(red: 0.28, green: 0.46, blue: 0.78, alpha: 1.0)
        ]
        let iconDiam = min(w * 0.58, max(8.0, (rect.height * 0.46) / 4.8))
        let iconSpacing = iconDiam * 0.28
        let totalIconsH = CGFloat(iconColors.count) * iconDiam + CGFloat(iconColors.count - 1) * iconSpacing
        var iconY = max(gridCenterY + w * 0.45, rect.midY - totalIconsH / 2.0)

        for (idx, color) in iconColors.enumerated() {
            if iconY + iconDiam < rect.maxY - w * 0.85 {
                let iconRect = CGRect(x: cx - iconDiam / 2.0, y: iconY, width: iconDiam, height: iconDiam)
                drawAppCircleIcon(ctx: ctx, rect: iconRect, baseColor: color, kind: idx)
                iconY += iconDiam + iconSpacing
            }
        }

        let fontSize = max(5.5, min(w * 0.34, 9.0))
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.88)
        ]
        let timeStr = "12:45"
        let timeSize = (timeStr as NSString).size(withAttributes: timeAttrs)
        let timeY = rect.maxY - timeSize.height - max(4.0, w * 0.2)
        if timeY > gridCenterY + w * 0.5 {
            (timeStr as NSString).draw(
                at: CGPoint(x: cx - timeSize.width / 2.0, y: timeY),
                withAttributes: timeAttrs
            )

            let pillW = min(w * 0.72, max(12.0, fontSize * 1.9))
            let pillH = max(7.0, fontSize * 1.15)
            let pillY = timeY - pillH - 3.0
            if pillY > iconY {
                let pillRect = CGRect(x: cx - pillW / 2.0, y: pillY, width: pillW, height: pillH)
                ctx.setFillColor(UIColor(red: 0.42, green: 0.84, blue: 0.45, alpha: 1.0).cgColor)
                UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2.0).fill()
            }
        }

        ctx.restoreGState()
    }

    private func drawHorizontalBottomDock(ctx: CGContext, rect: CGRect) {
        guard rect.width > 30 && rect.height > 10 else { return }
        ctx.saveGState()
        let corner = min(rect.height * 0.38, 10.0)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        ctx.setFillColor(UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 0.98).cgColor)
        path.fill()
        path.addClip()

        let h = rect.height
        let cy = rect.midY

        let leftPad = max(8.0, h * 0.45)
        let gridCenter = CGPoint(x: rect.minX + leftPad, y: cy)
        drawLauncherGrid(ctx: ctx, center: gridCenter, span: h * 0.44)

        let micCenter = CGPoint(x: gridCenter.x + h * 0.75, y: cy)
        drawAssistantMicIcon(ctx: ctx, center: micCenter, height: h * 0.46)

        let iconColors: [UIColor] = [
            UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0),
            UIColor(red: 0.92, green: 0.18, blue: 0.22, alpha: 1.0),
            UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0),
            UIColor(red: 0.16, green: 0.48, blue: 0.92, alpha: 1.0)
        ]
        let iconDiam = min(h * 0.68, max(10.0, rect.width * 0.075))
        let iconGap = max(4.0, iconDiam * 0.28)
        let totalW = CGFloat(iconColors.count) * iconDiam + CGFloat(iconColors.count - 1) * iconGap
        var startX = rect.midX - totalW / 2.0

        for (idx, color) in iconColors.enumerated() {
            let iconRect = CGRect(x: startX, y: cy - iconDiam / 2.0, width: iconDiam, height: iconDiam)
            drawAppCircleIcon(ctx: ctx, rect: iconRect, baseColor: color, kind: idx)
            startX += iconDiam + iconGap
        }

        let fontSize = max(6.5, min(h * 0.38, 10.5))
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.92)
        ]
        let timeStr = "12:45"
        let timeSize = (timeStr as NSString).size(withAttributes: timeAttrs)
        let rightPad = max(6.0, h * 0.32)
        let timeX = rect.maxX - timeSize.width - rightPad

        if timeX > startX + 4 {
            (timeStr as NSString).draw(
                at: CGPoint(x: timeX, y: cy - timeSize.height / 2.0),
                withAttributes: timeAttrs
            )

            let pillH = max(8.0, min(h * 0.50, fontSize * 1.35))
            let pillW = pillH * 1.45
            let pillX = timeX - pillW - max(4.0, h * 0.22)
            if pillX > startX + 2 {
                let pillRect = CGRect(x: pillX, y: cy - pillH / 2.0, width: pillW, height: pillH)
                ctx.setFillColor(UIColor(red: 0.44, green: 0.86, blue: 0.46, alpha: 1.0).cgColor)
                UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2.0).fill()

                let badgeFont = UIFont.systemFont(ofSize: max(5.0, pillH * 0.58), weight: .bold)
                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: badgeFont,
                    .foregroundColor: UIColor(white: 0.08, alpha: 1.0)
                ]
                let badgeStr = "9+"
                let badgeSize = (badgeStr as NSString).size(withAttributes: badgeAttrs)
                (badgeStr as NSString).draw(
                    at: CGPoint(x: pillRect.midX - badgeSize.width / 2.0, y: pillRect.midY - badgeSize.height / 2.0),
                    withAttributes: badgeAttrs
                )
            }
        }

        ctx.restoreGState()
    }

    private func drawMapCard(ctx: CGContext, rect: CGRect, showEtaOverlay: Bool) {
        guard rect.width > 20 && rect.height > 20 else { return }
        ctx.saveGState()

        let minDim = min(rect.width, rect.height)
        let cardRadius = max(5.0, min(minDim * 0.055, 12.0))
        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: cardRadius)
        ctx.setFillColor(UIColor(red: 0.09, green: 0.12, blue: 0.17, alpha: 1.0).cgColor)
        cardPath.fill()
        cardPath.addClip()

        ctx.setFillColor(UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 0.85).cgColor)
        ctx.fill(CGRect(x: rect.minX + rect.width * 0.68, y: rect.minY, width: rect.width * 0.32, height: rect.height))

        ctx.setStrokeColor(UIColor(red: 0.18, green: 0.23, blue: 0.30, alpha: 0.9).cgColor)
        ctx.setLineWidth(max(1.2, minDim * 0.018))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.32))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22))
        ctx.move(to: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.maxY * 0.55))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.82))
        ctx.move(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.maxY))
        ctx.strokePath()

        let routeX = rect.minX + rect.width * 0.65
        let puckY = rect.minY + rect.height * 0.76

        ctx.setStrokeColor(UIColor(white: 0.42, alpha: 0.8).cgColor)
        ctx.setLineWidth(max(2.5, minDim * 0.032))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: routeX + 1.5, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: routeX, y: puckY))
        ctx.strokePath()

        ctx.setStrokeColor(UIColor(red: 0.08, green: 0.64, blue: 1.0, alpha: 0.98).cgColor)
        ctx.setLineWidth(max(3.0, minDim * 0.038))
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: routeX, y: puckY))
        ctx.addLine(to: CGPoint(x: routeX - rect.width * 0.015, y: rect.minY))
        ctx.strokePath()

        let puckW = max(14.0, minDim * 0.14)
        let puckH = puckW * 0.68
        let puckRect = CGRect(x: routeX - puckW / 2.0, y: puckY - puckH / 2.0, width: puckW, height: puckH)
        ctx.setFillColor(UIColor(red: 0.08, green: 0.52, blue: 0.98, alpha: 1.0).cgColor)
        UIBezierPath(ovalIn: puckRect).fill()

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.beginPath()
        let arrowH = puckH * 0.48
        let arrowW = puckW * 0.36
        ctx.move(to: CGPoint(x: puckRect.midX, y: puckRect.midY - arrowH * 0.55))
        ctx.addLine(to: CGPoint(x: puckRect.midX + arrowW / 2.0, y: puckRect.midY + arrowH * 0.45))
        ctx.addLine(to: CGPoint(x: puckRect.midX, y: puckRect.midY + arrowH * 0.20))
        ctx.addLine(to: CGPoint(x: puckRect.midX - arrowW / 2.0, y: puckRect.midY + arrowH * 0.45))
        ctx.closePath()
        ctx.fillPath()

        let inset = max(5.0, minDim * 0.04)
        let bannerW = min(rect.width * 0.46, max(54.0, minDim * 0.52))
        let bannerH = min(rect.height * 0.28, max(16.0, minDim * 0.22))
        let bannerRect = CGRect(x: rect.minX + inset, y: rect.minY + inset, width: bannerW, height: bannerH)

        ctx.saveGState()
        let bannerPath = UIBezierPath(roundedRect: bannerRect, cornerRadius: max(3.5, bannerH * 0.18))
        ctx.setFillColor(UIColor(red: 0.02, green: 0.40, blue: 0.20, alpha: 0.96).cgColor)
        bannerPath.fill()
        bannerPath.addClip()

        let turnIconSize = min(bannerH * 0.48, bannerW * 0.22)
        let turnIconX = bannerRect.minX + max(4.0, bannerH * 0.20)
        let turnIconY = bannerRect.midY
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(max(1.3, turnIconSize * 0.18))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: turnIconX + turnIconSize * 0.75, y: turnIconY + turnIconSize * 0.45))
        ctx.addLine(to: CGPoint(x: turnIconX + turnIconSize * 0.75, y: turnIconY - turnIconSize * 0.1))
        ctx.addLine(to: CGPoint(x: turnIconX + turnIconSize * 0.15, y: turnIconY - turnIconSize * 0.1))
        ctx.strokePath()

        let textLeft = turnIconX + turnIconSize + max(3.0, bannerH * 0.14)
        let availTextW = max(0.0, bannerRect.maxX - textLeft - 5.0)
        if availTextW > 12 {
            let line1H = max(2.5, bannerH * 0.18)
            let line2H = max(2.0, bannerH * 0.14)
            let line1Rect = CGRect(x: textLeft, y: bannerRect.midY - line1H - 1.5, width: min(availTextW * 0.65, 42.0), height: line1H)
            let line2Rect = CGRect(x: textLeft, y: bannerRect.midY + 1.5, width: availTextW * 0.88, height: line2H)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            UIBezierPath(roundedRect: line1Rect, cornerRadius: line1H / 2.0).fill()
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.75).cgColor)
            UIBezierPath(roundedRect: line2Rect, cornerRadius: line2H / 2.0).fill()
        }
        ctx.restoreGState()

        if showEtaOverlay && rect.height > 54 {
            let etaW = min(rect.width * 0.44, max(50.0, bannerW * 0.94))
            let etaH = min(rect.height * 0.32, max(16.0, bannerH * 1.12))
            let etaY = rect.maxY - inset - etaH
            if etaY > bannerRect.maxY + 4 {
                let etaRect = CGRect(x: rect.minX + inset, y: etaY, width: etaW, height: etaH)
                ctx.saveGState()
                let etaPath = UIBezierPath(roundedRect: etaRect, cornerRadius: max(3.5, etaH * 0.18))
                ctx.setFillColor(UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 0.94).cgColor)
                etaPath.fill()
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
                ctx.setLineWidth(0.8)
                etaPath.stroke()
                etaPath.addClip()

                let closeDiam = min(etaH * 0.44, etaW * 0.22)
                let closeRect = CGRect(x: etaRect.minX + 5, y: etaRect.minY + (etaH - closeDiam) * 0.35, width: closeDiam, height: closeDiam)
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
                ctx.setLineWidth(1.0)
                UIBezierPath(ovalIn: closeRect).stroke()

                let etaTextX = closeRect.maxX + 5
                let etaAvailW = max(0.0, etaRect.maxX - etaTextX - 5)
                if etaAvailW > 10 {
                    let bar1H = max(2.5, etaH * 0.15)
                    let bar2H = max(2.0, etaH * 0.12)
                    let bar1 = CGRect(x: etaTextX, y: closeRect.minY + 1, width: etaAvailW * 0.78, height: bar1H)
                    let bar2 = CGRect(x: etaTextX, y: bar1.maxY + 2.5, width: etaAvailW * 0.52, height: bar2H)
                    ctx.setFillColor(UIColor(red: 0.96, green: 0.74, blue: 0.22, alpha: 0.95).cgColor)
                    UIBezierPath(roundedRect: bar1, cornerRadius: bar1H / 2.0).fill()
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
                    UIBezierPath(roundedRect: bar2, cornerRadius: bar2H / 2.0).fill()
                }
                ctx.restoreGState()
            }
        }

        let zoomW = max(8.0, minDim * 0.085)
        let zoomH = min(rect.height * 0.32, zoomW * 2.1)
        let zoomRect = CGRect(x: rect.maxX - inset - zoomW, y: rect.maxY - inset - zoomH, width: zoomW, height: zoomH)
        if zoomRect.minX > routeX + puckW * 0.6 {
            ctx.setFillColor(UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 0.92).cgColor)
            UIBezierPath(roundedRect: zoomRect, cornerRadius: zoomW / 2.0).fill()
        }

        ctx.restoreGState()
    }

    private func drawCommunicationCard(ctx: CGContext, rect: CGRect) {
        guard rect.width > 16 && rect.height > 16 else { return }
        ctx.saveGState()

        let minDim = min(rect.width, rect.height)
        let cardRadius = max(4.5, min(minDim * 0.12, 11.0))
        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: cardRadius)
        ctx.setFillColor(UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 0.98).cgColor)
        cardPath.fill()
        cardPath.addClip()

        let pad = max(5.0, minDim * 0.10)
        let availW = max(0.0, rect.width - pad * 2)
        let availH = max(0.0, rect.height - pad * 2)
        guard availW > 8 && availH > 8 else {
            ctx.restoreGState()
            return
        }

        let avatarDiam = min(availH * 0.42, availW * 0.26)
        let avatarRect = CGRect(x: rect.minX + pad, y: rect.minY + pad, width: avatarDiam, height: avatarDiam)
        ctx.setFillColor(UIColor(red: 0.88, green: 0.68, blue: 0.52, alpha: 0.95).cgColor)
        UIBezierPath(ovalIn: avatarRect).fill()

        let badgeDiam = max(3.5, avatarDiam * 0.36)
        let badgeRect = CGRect(x: avatarRect.maxX - badgeDiam * 0.85, y: avatarRect.maxY - badgeDiam * 0.85, width: badgeDiam, height: badgeDiam)
        ctx.setFillColor(UIColor(red: 0.22, green: 0.56, blue: 0.98, alpha: 1.0).cgColor)
        UIBezierPath(ovalIn: badgeRect).fill()

        let textX = avatarRect.maxX + max(4.0, pad * 0.7)
        let maxTextW = max(0.0, rect.maxX - pad - textX)
        if maxTextW > 6 {
            let line1H = max(2.2, min(4.5, avatarDiam * 0.26))
            let line2H = max(1.8, min(3.5, avatarDiam * 0.20))
            let line1W = max(line1H, maxTextW * 0.78)
            let line2W = max(line2H, maxTextW * 0.52)

            let line1 = CGRect(x: textX, y: avatarRect.midY - line1H - 1.5, width: line1W, height: line1H)
            let line2 = CGRect(x: textX, y: avatarRect.midY + 1.5, width: line2W, height: line2H)

            ctx.setFillColor(UIColor.white.withAlphaComponent(0.90).cgColor)
            UIBezierPath(roundedRect: line1, cornerRadius: line1H / 2.0).fill()
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.50).cgColor)
            UIBezierPath(roundedRect: line2, cornerRadius: line2H / 2.0).fill()
        }

        let btnH = min(availH * 0.34, max(7.0, minDim * 0.26))
        let btnY = rect.maxY - pad - btnH
        if btnY > avatarRect.maxY + 2 && availW > 16 {
            let btnGap = max(3.0, availW * 0.05)
            let btnW = max(6.0, (availW - btnGap) / 2.0)
            let leftBtn = CGRect(x: rect.minX + pad, y: btnY, width: btnW, height: btnH)
            let rightBtn = CGRect(x: leftBtn.maxX + btnGap, y: btnY, width: btnW, height: btnH)

            ctx.setFillColor(UIColor(red: 0.78, green: 0.84, blue: 0.98, alpha: 0.96).cgColor)
            UIBezierPath(roundedRect: leftBtn, cornerRadius: btnH / 2.0).fill()

            ctx.setFillColor(UIColor(white: 0.26, alpha: 0.95).cgColor)
            UIBezierPath(roundedRect: rightBtn, cornerRadius: btnH / 2.0).fill()

            let triSize = min(btnH * 0.42, 6.0)
            ctx.setFillColor(UIColor(red: 0.12, green: 0.22, blue: 0.52, alpha: 1.0).cgColor)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: leftBtn.midX - triSize * 0.4, y: leftBtn.midY - triSize * 0.5))
            ctx.addLine(to: CGPoint(x: leftBtn.midX + triSize * 0.6, y: leftBtn.midY))
            ctx.addLine(to: CGPoint(x: leftBtn.midX - triSize * 0.4, y: leftBtn.midY + triSize * 0.5))
            ctx.closePath()
            ctx.fillPath()
        }

        ctx.restoreGState()
    }

    private func drawMediaCard(ctx: CGContext, rect: CGRect) {
        guard rect.width > 16 && rect.height > 16 else { return }
        ctx.saveGState()

        let minDim = min(rect.width, rect.height)
        let cardRadius = max(4.5, min(minDim * 0.12, 11.0))
        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: cardRadius)
        cardPath.addClip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: 0.16, green: 0.46, blue: 0.54, alpha: 0.98).cgColor,
            UIColor(red: 0.08, green: 0.32, blue: 0.40, alpha: 0.98).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        } else {
            ctx.setFillColor(UIColor(red: 0.12, green: 0.38, blue: 0.46, alpha: 0.98).cgColor)
            ctx.fill(rect)
        }

        let pad = max(5.0, minDim * 0.10)
        let availW = max(0.0, rect.width - pad * 2)
        let availH = max(0.0, rect.height - pad * 2)
        guard availW > 8 && availH > 8 else {
            ctx.restoreGState()
            return
        }

        let badgeDiam = max(4.5, min(availH * 0.18, 9.0))
        let badgeRect = CGRect(x: rect.maxX - pad - badgeDiam, y: rect.minY + pad, width: badgeDiam, height: badgeDiam)
        ctx.setFillColor(UIColor(red: 0.72, green: 0.92, blue: 0.98, alpha: 0.92).cgColor)
        UIBezierPath(ovalIn: badgeRect).fill()

        let maxTitleW = max(0.0, badgeRect.minX - (rect.minX + pad) - 4.0)
        let line1H = max(2.2, min(4.5, availH * 0.11))
        let line2H = max(1.8, min(3.5, availH * 0.085))
        if maxTitleW > 8 {
            let line1W = max(line1H, maxTitleW * 0.82)
            let line2W = max(line2H, maxTitleW * 0.56)
            let line1 = CGRect(x: rect.minX + pad, y: rect.minY + pad + 1, width: line1W, height: line1H)
            let line2 = CGRect(x: rect.minX + pad, y: line1.maxY + max(2.0, availH * 0.05), width: line2W, height: line2H)

            ctx.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            UIBezierPath(roundedRect: line1, cornerRadius: line1H / 2.0).fill()
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.68).cgColor)
            UIBezierPath(roundedRect: line2, cornerRadius: line2H / 2.0).fill()
        }

        let progY = rect.minY + rect.height * 0.50
        let progH = max(1.2, min(2.2, availH * 0.04))
        let progFull = CGRect(x: rect.minX + pad, y: progY, width: availW, height: progH)
        let progActive = CGRect(x: rect.minX + pad, y: progY, width: availW * 0.42, height: progH)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.24).cgColor)
        UIBezierPath(roundedRect: progFull, cornerRadius: progH / 2.0).fill()
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        UIBezierPath(roundedRect: progActive, cornerRadius: progH / 2.0).fill()

        let playDiam = min(availH * 0.34, min(availW * 0.24, 18.0))
        let playCenterY = rect.maxY - pad - playDiam / 2.0
        if playCenterY - playDiam / 2.0 > progY + 2 {
            let playRect = CGRect(
                x: rect.midX - playDiam / 2.0,
                y: playCenterY - playDiam / 2.0,
                width: playDiam,
                height: playDiam
            )
            ctx.setFillColor(UIColor(red: 0.76, green: 0.93, blue: 0.99, alpha: 0.98).cgColor)
            UIBezierPath(ovalIn: playRect).fill()

            let tri = playDiam * 0.36
            ctx.setFillColor(UIColor(red: 0.05, green: 0.18, blue: 0.24, alpha: 1.0).cgColor)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: playRect.midX - tri * 0.35, y: playRect.midY - tri * 0.5))
            ctx.addLine(to: CGPoint(x: playRect.midX + tri * 0.65, y: playRect.midY))
            ctx.addLine(to: CGPoint(x: playRect.midX - tri * 0.35, y: playRect.midY + tri * 0.5))
            ctx.closePath()
            ctx.fillPath()

            let skipOffset = min(availW * 0.28, playDiam * 1.45)
            let skipSize = max(3.0, playDiam * 0.36)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.88).cgColor)

            let prevX = rect.midX - skipOffset
            ctx.fill(CGRect(x: prevX - skipSize * 0.5, y: playCenterY - skipSize * 0.45, width: max(1.0, skipSize * 0.22), height: skipSize * 0.9))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: prevX + skipSize * 0.45, y: playCenterY - skipSize * 0.45))
            ctx.addLine(to: CGPoint(x: prevX - skipSize * 0.2, y: playCenterY))
            ctx.addLine(to: CGPoint(x: prevX + skipSize * 0.45, y: playCenterY + skipSize * 0.45))
            ctx.closePath()
            ctx.fillPath()

            let nextX = rect.midX + skipOffset
            ctx.fill(CGRect(x: nextX + skipSize * 0.28, y: playCenterY - skipSize * 0.45, width: max(1.0, skipSize * 0.22), height: skipSize * 0.9))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: nextX - skipSize * 0.45, y: playCenterY - skipSize * 0.45))
            ctx.addLine(to: CGPoint(x: nextX + skipSize * 0.2, y: playCenterY))
            ctx.addLine(to: CGPoint(x: nextX - skipSize * 0.45, y: playCenterY + skipSize * 0.45))
            ctx.closePath()
            ctx.fillPath()
        }

        ctx.restoreGState()
    }

    private func drawLauncherGrid(ctx: CGContext, center: CGPoint, span: CGFloat) {
        let dotRadius = max(1.0, span * 0.13)
        let step = span * 0.38
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
        for r in -1...1 {
            for c in -1...1 {
                let cx = center.x + CGFloat(c) * step
                let cy = center.y + CGFloat(r) * step
                ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: cy - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
        }
    }

    private func drawAssistantMicIcon(ctx: CGContext, center: CGPoint, height: CGFloat) {
        let capsuleW = max(2.2, height * 0.34)
        let capsuleH = max(4.0, height * 0.62)
        let capsuleRect = CGRect(x: center.x - capsuleW / 2.0, y: center.y - height * 0.42, width: capsuleW, height: capsuleH)
        ctx.setFillColor(UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0).cgColor)
        UIBezierPath(roundedRect: capsuleRect, cornerRadius: capsuleW / 2.0).fill()

        ctx.setStrokeColor(UIColor(red: 0.92, green: 0.26, blue: 0.21, alpha: 1.0).cgColor)
        ctx.setLineWidth(max(1.0, height * 0.12))
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: center.x, y: center.y - height * 0.05), radius: capsuleW * 0.85, startAngle: 0, endAngle: .pi, clockwise: false)
        ctx.strokePath()
    }

    private func drawAppCircleIcon(ctx: CGContext, rect: CGRect, baseColor: UIColor, kind: Int) {
        ctx.saveGState()
        ctx.setFillColor(baseColor.cgColor)
        UIBezierPath(ovalIn: rect).fill()

        let innerR = rect.width * 0.24
        switch kind {
        case 0:
            ctx.setFillColor(UIColor(red: 0.16, green: 0.66, blue: 0.36, alpha: 1.0).cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.midX - innerR, y: rect.midY - innerR, width: innerR * 2, height: innerR * 2))
        case 1:
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(max(0.8, rect.width * 0.08))
            ctx.strokeEllipse(in: rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.24))
        case 2:
            ctx.setFillColor(UIColor(red: 0.14, green: 0.48, blue: 0.90, alpha: 1.0).cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.midX - innerR, y: rect.midY - innerR, width: innerR * 2, height: innerR * 2))
        default:
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.midX - innerR * 0.85, y: rect.midY - innerR * 0.85, width: innerR * 1.7, height: innerR * 1.7))
        }
        ctx.restoreGState()
    }
}
