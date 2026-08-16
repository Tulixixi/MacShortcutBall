import Cocoa

// ============================================================
//  快捷键悬浮球 · Mac Shortcut Ball
//  一个可拖拽、可隐藏的桌面悬浮球，点击即可搜索 Mac 快捷键
// ============================================================

// MARK: - 数据模型

struct ShortcutItem: Decodable {
    let id: String
    let name: String
    let keys: String        // 符号显示，如 ⌘C
    let plain: String       // 文字显示，如 Command + C
    let category: String
    let desc: String
    let keywords: [String]

    func searchableText() -> String {
        ([name, keys, plain, category, desc] + keywords).joined(separator: " ").lowercased()
    }
}

// MARK: - 数据加载

enum ShortcutStore {

    /// 内置兜底数据（用于找不到 shortcuts.json 时保证可用）
    static let builtinJSON = """
    [
      { "id": "copy", "name": "复制", "keys": "⌘C", "plain": "Command + C", "category": "通用", "desc": "复制所选内容", "keywords": ["复制", "copy"] },
      { "id": "paste", "name": "粘贴", "keys": "⌘V", "plain": "Command + V", "category": "通用", "desc": "粘贴剪贴板内容", "keywords": ["粘贴", "paste"] },
      { "id": "cut", "name": "剪切", "keys": "⌘X", "plain": "Command + X", "category": "通用", "desc": "剪切所选内容", "keywords": ["剪切", "cut"] },
      { "id": "screenshot_full", "name": "全屏截图", "keys": "⇧⌘3", "plain": "Shift + Command + 3", "category": "截屏", "desc": "截取整个屏幕", "keywords": ["截图", "截屏", "screenshot"] },
      { "id": "screenshot_area", "name": "区域截图", "keys": "⇧⌘4", "plain": "Shift + Command + 4", "category": "截屏", "desc": "框选区域截图", "keywords": ["截图", "截屏", "选区"] },
      { "id": "switch_app", "name": "切换应用", "keys": "⌘⇥", "plain": "Command + Tab", "category": "窗口与切换", "desc": "在应用间切换", "keywords": ["切换应用", "切换窗口"] },
      { "id": "force_quit", "name": "强制退出应用", "keys": "⌥⌘⎋", "plain": "Option + Command + Esc", "category": "窗口与切换", "desc": "强制退出无响应的应用", "keywords": ["强制退出", "任务管理器"] },
      { "id": "spotlight", "name": "聚焦搜索 Spotlight", "keys": "⌘␣", "plain": "Command + 空格", "category": "系统", "desc": "全局搜索", "keywords": ["搜索", "spotlight"] },
      { "id": "lock_screen", "name": "锁定屏幕", "keys": "⌃⌘Q", "plain": "Control + Command + Q", "category": "系统", "desc": "立即锁定屏幕", "keywords": ["锁屏", "锁定"] },
      { "id": "switch_ime", "name": "切换输入法", "keys": "⌃␣", "plain": "Control + 空格", "category": "系统", "desc": "切换输入法", "keywords": ["输入法"] }
    ]
    """

    static func userConfigURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MacShortcutBall", isDirectory: true)
        return dir.appendingPathComponent("shortcuts.json")
    }

    /// 依次尝试：用户自定义 → 应用资源 → 可执行文件同目录 → 内置
    static func load() -> [ShortcutItem] {
        if let list = parse(contentsOf: userConfigURL()) { return list }
        if let r = Bundle.main.resourceURL?.appendingPathComponent("shortcuts.json"),
           let list = parse(contentsOf: r) { return list }
        if let e = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("shortcuts.json"),
           let list = parse(contentsOf: e) { return list }
        if let list = parse(Data(builtinJSON.utf8)) { return list }
        return []
    }

    private static func parse(contentsOf url: URL) -> [ShortcutItem]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    private static func parse(_ data: Data) -> [ShortcutItem]? {
        try? JSONDecoder().decode([ShortcutItem].self, from: data)
    }

    /// 若无自定义文件，导出完整快捷键库作为模板供用户编辑
    static func exportDefaultIfMissing() {
        let fileURL = userConfigURL()
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // 优先以完整资源库作为模板
        if let r = Bundle.main.resourceURL?.appendingPathComponent("shortcuts.json"),
           let data = try? Data(contentsOf: r) {
            try? data.write(to: fileURL)
        } else if let e = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("shortcuts.json"),
                  let data = try? Data(contentsOf: e) {
            try? data.write(to: fileURL)
        } else {
            try? builtinJSON.data(using: .utf8)?.write(to: fileURL)
        }
    }
}

// MARK: - 品牌信息（在这里留下你的标志 / 署名）

enum Branding {
    /// 作者署名（改这里即可全应用生效，如「张小明」「@your_name」）
    static let author = "你的名字"
    /// GitHub 仓库地址（创建仓库后替换成你的地址）
    static let githubURL = "https://github.com/你的用户名/MacShortcutBall"
    /// 应用显示名
    static let appDisplayName = "快捷键悬浮球"

    /// 应用品牌图标（来自 AppIcon.icns，找不到时回退到系统图标）
    static func appIcon() -> NSImage? {
        if let img = NSImage(named: NSImage.Name("AppIcon")) { return img }
        return NSImage(systemSymbolName: "magnifyingglass.circle.fill",
                       accessibilityDescription: appDisplayName)
    }
}

// MARK: - 可输入的无边框面板

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - 悬浮球视图

final class BallView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    private var dragStart = NSPoint.zero
    private var windowStart = NSPoint.zero
    private var didDrag = false
    private var trackingArea: NSTrackingArea?
    private var isHover = false

    // 从应用资源加载设计稿提供的悬浮球图片
    private lazy var ballImage: NSImage? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("float.png") else { return nil }
        if let img = NSImage(contentsOf: url) { return img }
        // 开发时回退：可执行文件同目录
        let devURL = URL(fileURLWithPath: Bundle.main.executableURL?.deletingLastPathComponent().path ?? "")
            .appendingPathComponent("float.png")
        return NSImage(contentsOf: devURL)
    }()

    override var acceptsFirstResponder: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds,
                                      options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                                      owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private func setHover(_ h: Bool) {
        guard isHover != h else { return }
        isHover = h
        // 保持原状态：不放大、不变阴影，避免动画卡顿
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        windowStart = window?.frame.origin ?? .zero
        didDrag = false
        // 记录按下时间，用于区分短点击和拖动/长压
        mouseDownTime = Date()
    }

    private var mouseDownTime = Date()

    override func mouseDragged(with event: NSEvent) {
        guard let w = window else { return }
        let p = event.locationInWindow
        let dx = p.x - dragStart.x
        let dy = p.y - dragStart.y
        var origin = NSPoint(x: windowStart.x + dx, y: windowStart.y + dy)
        if let screen = w.screen {
            let vf = screen.visibleFrame
            let f = w.frame
            origin.x = min(max(origin.x, vf.minX), vf.maxX - f.width)
            origin.y = min(max(origin.y, vf.minY), vf.maxY - f.height)
        }
        // 拖动时禁用 layer 隐式动画、减少立即 display，避免残影
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        w.setFrame(NSRect(origin: origin, size: w.frame.size), display: false)
        CATransaction.commit()
        w.displayIfNeeded()
        didDrag = true
    }

    override func mouseUp(with event: NSEvent) {
        // 只有短按且未拖动时才触发点击，避免拖动结束误触
        if !didDrag && Date().timeIntervalSince(mouseDownTime) < 0.25 {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 4, dy: 4)
        ballImage?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}

// MARK: - 快捷键键帽（浅色极简：多个小圆角键帽右对齐）

final class KeysView: NSView {
    var parts: [String] = [] {
        didSet { needsDisplay = true }
    }
    override var isFlipped: Bool { true }
    private let font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
    private let inkDark = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)

    func desiredWidth() -> CGFloat {
        guard !parts.isEmpty else { return 0 }
        let w = parts.reduce(CGFloat(0)) { $0 + capWidth(for: $1) }
        return w + CGFloat((parts.count - 1)) * 3
    }

    private func capWidth(for p: String) -> CGFloat {
        NSAttributedString(string: p, attributes: [.font: font]).size().width + 14
    }

    override func draw(_ dirtyRect: NSRect) {
        var x: CGFloat = 0
        for p in parts {
            let w = capWidth(for: p)
            let r = NSRect(x: x, y: 1, width: w, height: bounds.height - 2)
            let path = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
            NSColor.black.withAlphaComponent(0.05).setFill()
            path.fill()
            NSColor.black.withAlphaComponent(0.08).setStroke()
            path.lineWidth = 1
            path.stroke()
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attr = NSAttributedString(string: p, attributes: [
                .font: font, .foregroundColor: inkDark, .paragraphStyle: para
            ])
            attr.draw(in: NSRect(x: r.minX, y: r.minY + 2, width: r.width, height: r.height - 3))
            x += w + 3
        }
    }
}

// MARK: - 搜索结果单元格

final class ShortcutCell: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let keysView = KeysView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for l in [nameLabel, detailLabel] {
            l.translatesAutoresizingMaskIntoConstraints = false
            l.lineBreakMode = .byTruncatingTail
            l.isSelectable = false
            addSubview(l)
        }
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .labelColor.withAlphaComponent(0.82)
        addSubview(keysView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let W = bounds.width
        // 键帽右对齐，右缘距列右边界 12pt（与滚动条安全距离）
        let keysW = keysView.desiredWidth()
        let keysX = W - keysW - 12
        keysView.frame = NSRect(x: keysX, y: (bounds.height - 22) / 2, width: keysW, height: 22)
        let textW = keysX - 12 - 6
        // 大标题（名称）在上，副标题（分类/描述）在下
        nameLabel.frame = NSRect(x: 12, y: 22, width: textW, height: 17)
        detailLabel.frame = NSRect(x: 12, y: 7, width: textW, height: 13)
    }

    func configure(with item: ShortcutItem, tokens: [String]) {
        nameLabel.attributedStringValue = Self.attributed(item.name, tokens: tokens,
                                                           font: nameLabel.font ?? .systemFont(ofSize: 13), color: .labelColor)
        let detail = item.desc.isEmpty ? item.category : "\(item.category) · \(item.desc)"
        detailLabel.attributedStringValue = Self.attributed(detail, tokens: tokens,
                                                            font: detailLabel.font ?? .systemFont(ofSize: 11),
                                                            color: .labelColor.withAlphaComponent(0.82))
        keysView.parts = item.keys.split(separator: " ").map(String.init)
        // 鼠标悬停时显示完整标题、描述和快捷键
        toolTip = "\(item.name)\n\(detail)\n\(item.plain)"
    }

    private static func attributed(_ s: String, tokens: [String],
                                   font: NSFont, color: NSColor) -> NSAttributedString {
        let ms = NSMutableAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
        let lower = s.lowercased()
        for t in tokens where !t.isEmpty {
            var range = lower.startIndex..<lower.endIndex
            while let r = lower.range(of: t, options: .caseInsensitive, range: range) {
                let ns = NSRange(r, in: s)
                ms.addAttributes([
                    .foregroundColor: NSColor.systemOrange,
                    .font: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                ], range: ns)
                range = r.upperBound..<lower.endIndex
            }
        }
        return ms
    }
}

// MARK: - 搜索面板

final class SearchPanel: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    static let shared = SearchPanel()

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let hintLabel = NSTextField(labelWithString: "输入关键词搜索，如：复制 / 截屏 / 切换应用")
    private let emptyLabel = NSTextField(labelWithString: "没有找到匹配的快捷键")
    private let onlineSearchButton = NSButton()
    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 400
    private var currentQuery: String = ""

    private var items: [ShortcutItem] = []
    private var filtered: [ShortcutItem] = []
    private var toastTimer: Timer?
    private var globalMonitor: Any?

    private init() {
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered,
                             defer: false)
        super.init(window: panel)
        configurePanel(panel)
        setupUI(panel)
        items = ShortcutStore.load()
        filtered = items
        tableView.reloadData()
        registerGlobalMonitors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configurePanel(_ panel: NSPanel) {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
    }

    private func setupUI(_ panel: NSPanel) {
        // 外层容器承载阴影（内层毛玻璃会裁剪，不能直接挂阴影）
        let container = NSView(frame: panel.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.35
        container.layer?.shadowRadius = 20
        container.layer?.shadowOffset = CGSize(width: 0, height: 4)
        panel.contentView = container

        let effect = NSVisualEffectView(frame: container.bounds)
        // .hudWindow 在较新系统上太透，改用 .popover 并叠加一层背景色提高可读性
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effect)

        // 加一层半透明底色，让文字在任何壁纸下都清晰
        let dimming = NSView(frame: container.bounds)
        dimming.wantsLayer = true
        dimming.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor
        dimming.layer?.cornerRadius = 14
        dimming.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dimming, positioned: .below, relativeTo: effect)

        NSLayoutConstraint.activate([
            effect.topAnchor.constraint(equalTo: container.topAnchor),
            effect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effect.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            dimming.topAnchor.constraint(equalTo: container.topAnchor),
            dimming.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dimming.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dimming.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // 搜索框
        searchField.placeholderString = "搜索 Mac 快捷键，如：截屏、切换应用、强制退出…"
        searchField.font = .systemFont(ofSize: 13)
        searchField.delegate = self
        searchField.wantsLayer = true
        searchField.layer?.cornerRadius = 9
        searchField.translatesAutoresizingMaskIntoConstraints = false

        // 列表
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = panelWidth - 24
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 40
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClicked(_:))

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true

        // 提示标签
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        onlineSearchButton.title = "在线搜索 Mac 快捷键"
        onlineSearchButton.bezelStyle = .rounded
        onlineSearchButton.target = self
        onlineSearchButton.action = #selector(performOnlineSearch)
        onlineSearchButton.isHidden = true
        onlineSearchButton.translatesAutoresizingMaskIntoConstraints = false

        for v in [searchField, scrollView, hintLabel, emptyLabel, onlineSearchButton] {
            effect.addSubview(v)
        }

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -6),

            hintLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
            hintLabel.heightAnchor.constraint(equalToConstant: 16),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor, constant: -20),
            emptyLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),

            onlineSearchButton.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            onlineSearchButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 10)
        ])
    }

    // MARK: - 事件监听

    private func registerGlobalMonitors() {
        // 点击面板外任意处 → 关闭
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { SearchPanel.shared.closeIfClickedOutside() }
        }
        // Esc → 关闭
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                MainActor.assumeIsolated { SearchPanel.shared.closePanel() }
                return nil
            }
            if event.keyCode == 36 {
                MainActor.assumeIsolated { SearchPanel.shared.handleReturnKey() }
                return nil
            }
            return event
        }
    }

    @objc func closeIfClickedOutside() {
        guard let panel = window, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        if !panel.frame.contains(mouse) {
            closePanel()
        }
    }

    // MARK: - 显示 / 关闭

    func showPanel(near ballFrame: NSRect) {
        guard let panel = window else { return }
        var x = ballFrame.midX - panelWidth / 2
        var y = ballFrame.maxY + 12
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            x = min(max(x, vf.minX + 8), vf.maxX - panelWidth - 8)
            if y + panelHeight > vf.maxY { y = ballFrame.minY - panelHeight - 12 }
            y = max(y, vf.minY + 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)

        searchField.stringValue = ""
        updateFilter()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchField.window?.makeFirstResponder(searchField)
    }

    func closePanel() {
        window?.orderOut(nil)
        toastTimer?.invalidate()
        hintLabel.stringValue = "输入关键词搜索，如：复制 / 截屏 / 切换应用"
        hintLabel.textColor = .tertiaryLabelColor
    }

    // MARK: - 搜索过滤

    private func updateFilter() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        currentQuery = q
        if q.isEmpty {
            filtered = items
        } else {
            let tokens = q.lowercased().split(separator: " ").map(String.init)
            filtered = items.filter { item in
                let s = item.searchableText()
                return tokens.allSatisfy { s.contains($0) }
            }
        }
        tableView.reloadData()
        let noResults = filtered.isEmpty && !q.isEmpty
        emptyLabel.isHidden = !noResults
        onlineSearchButton.isHidden = !noResults
        scrollView.isHidden = noResults
    }

    func reload() {
        items = ShortcutStore.load()
        updateFilter()
    }

    // MARK: - 复制与提示

    @objc private func doubleClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0 && row < filtered.count else { return }
        let item = filtered[row]
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.plain, forType: .string)
        showToast("已复制：\(item.plain)")
    }

    private func showToast(_ text: String) {
        toastTimer?.invalidate()
        hintLabel.stringValue = text
        hintLabel.textColor = .systemGreen
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hintLabel.stringValue = "输入关键词搜索，如：复制 / 截屏 / 切换应用"
            self.hintLabel.textColor = .tertiaryLabelColor
        }
    }

    @objc private func handleReturnKey() {
        if !currentQuery.isEmpty && filtered.isEmpty {
            performOnlineSearch()
        }
    }

    @objc private func performOnlineSearch() {
        guard !currentQuery.isEmpty else { return }
        let encoded = currentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentQuery
        let urlString = "https://www.bing.com/search?q=Mac+\(encoded)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            closePanel()
        }
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filtered.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("ShortcutCell")
        var cell = tableView.makeView(withIdentifier: id, owner: nil) as? ShortcutCell
        if cell == nil {
            cell = ShortcutCell(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 48))
            cell!.identifier = id
        }
        let tokens = searchField.stringValue.trimmingCharacters(in: .whitespaces)
            .lowercased().split(separator: " ").map(String.init)
        cell!.configure(with: filtered[row], tokens: tokens)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            tableView.deselectRow(row)
        }
    }
}

// MARK: - 悬浮球窗口控制器

final class BallController: NSWindowController {

    private let ballView = BallView()
    private let savedKey = "MacShortcutBall.origin"

    init() {
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered,
                             defer: false)
        super.init(window: panel)

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

        ballView.wantsLayer = true
        ballView.layer?.cornerRadius = 40
        ballView.layer?.shadowColor = NSColor.black.cgColor
        ballView.layer?.shadowOpacity = 0.28
        ballView.layer?.shadowRadius = 6
        ballView.layer?.shadowOffset = CGSize(width: 0, height: 2)
        panel.contentView = ballView

        restorePosition(panel)
        ballView.onClick = { [weak self] in self?.toggleSearch() }
        ballView.onRightClick = { [weak self] event in self?.showBallMenu(event: event) }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ballMoved(_:)),
                                               name: NSWindow.didMoveNotification,
                                               object: panel)
    }

    @objc private func ballMoved(_ note: Notification) {
        guard let p = window?.frame.origin else { return }
        UserDefaults.standard.set(NSStringFromPoint(p), forKey: savedKey)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func restorePosition(_ panel: NSPanel) {
        if let s = UserDefaults.standard.string(forKey: savedKey) {
            let p = NSPointFromString(s)
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(p) }) {
                panel.setFrameOrigin(p)
                return
            }
        }
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: vf.maxX - 96, y: vf.midY - 40))
        }
    }

    // MARK: - 行为

    func showBall() {
        window?.orderFrontRegardless()
    }

    @objc func toggleBall() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showBall()
        }
    }

    @objc func hideBall() {
        window?.orderOut(nil)
    }

    @objc func toggleSearch() {
        let searchPanel = SearchPanel.shared
        if searchPanel.window?.isVisible == true {
            searchPanel.closePanel()
        } else if let f = window?.frame {
            searchPanel.showPanel(near: f)
        }
    }

    @objc func reloadShortcuts() {
        SearchPanel.shared.reload()
    }

    @objc func openShortcutFile() {
        ShortcutStore.exportDefaultIfMissing()
        NSWorkspace.shared.open(ShortcutStore.userConfigURL())
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: 开机自启

    private func runAppleScript(_ source: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", source]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    func isLoginItemEnabled() -> Bool {
        guard let output = runAppleScript("tell application \"System Events\" to name of every login item") else { return false }
        let appName = Bundle.main.bundleURL.lastPathComponent
        let names = output.components(separatedBy: CharacterSet(charactersIn: ",\n")).map { $0.trimmingCharacters(in: .whitespaces) }
        return names.contains(appName)
    }

    private func addLoginItem() -> Bool {
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"System Events\" to make login item at end with properties {path:\"\(path)\", hidden:false}"
        return runAppleScript(source) != nil
    }

    private func removeLoginItem() -> Bool {
        let appName = Bundle.main.bundleURL.lastPathComponent.replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"System Events\" to delete login item \"\(appName)\""
        return runAppleScript(source) != nil
    }

    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        let enabled = isLoginItemEnabled()
        let success = enabled ? removeLoginItem() : addLoginItem()
        if success {
            sender.state = enabled ? NSControl.StateValue.off : NSControl.StateValue.on
        } else {
            let alert = NSAlert()
            alert.messageText = "需要手动设置开机自启"
            alert.informativeText = "macOS 权限限制，自动设置未成功。请打开「系统设置 → 通用 → 登录项」，点击 + 号选择 MacShortcutBall.app。建议先将应用拖入「应用程序」文件夹。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.SystemPreferences-Settings.extension?LoginItems") {
                    NSWorkspace.shared.open(url)
                } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.users") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func showBallMenu(event: NSEvent) {
        let menu = NSMenu()
        // 品牌标题（不可点击，作为标志展示）
        let brand = NSMenuItem(title: "⚡ 快捷键悬浮球 · by \(Branding.author)", action: nil, keyEquivalent: "")
        brand.isEnabled = false
        menu.addItem(brand)
        menu.addItem(.separator())
        let entries: [(String, Selector)] = [
            ("🔍 搜索快捷键", #selector(toggleSearch)),
            ("🙈 隐藏悬浮球", #selector(hideBall)),
            ("🔄 重新加载快捷键库", #selector(reloadShortcuts)),
            ("✏️ 打开自定义快捷键文件", #selector(openShortcutFile))
        ]
        for (title, action) in entries {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let about = NSMenuItem(title: "ℹ️ 关于 · 项目主页", action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        about.target = appDelegate
        menu.addItem(about)
        menu.addItem(.separator())
        let loginItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLoginItemEnabled() ? NSControl.StateValue.on : NSControl.StateValue.off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "⏏️ 退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        guard let w = window else { return }
        let screenPoint = w.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let ball = BallController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ShortcutStore.exportDefaultIfMissing()
        ball.showBall()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            // 菜单栏图标使用设计稿的圆形悬浮球图片，避免方型图标在菜单栏中不明显
            if let icon = menuBarIcon() {
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "magnifyingglass.circle.fill",
                                       accessibilityDescription: Branding.appDisplayName)
            }
            button.toolTip = "\(Branding.appDisplayName) · by \(Branding.author)"
        }
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "显示 / 隐藏悬浮球", action: #selector(BallController.toggleBall), keyEquivalent: "")
        toggle.target = ball
        let reload = NSMenuItem(title: "重新加载快捷键库", action: #selector(BallController.reloadShortcuts), keyEquivalent: "")
        reload.target = ball
        let edit = NSMenuItem(title: "打开自定义快捷键文件", action: #selector(BallController.openShortcutFile), keyEquivalent: "")
        edit.target = ball
        let loginItem = NSMenuItem(title: "开机自动启动", action: #selector(BallController.toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = ball
        loginItem.state = ball.isLoginItemEnabled() ? NSControl.StateValue.on : NSControl.StateValue.off
        let about = NSMenuItem(title: "ℹ️ 关于 \(Branding.appDisplayName)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(toggle)
        menu.addItem(reload)
        menu.addItem(edit)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(about)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    private func menuBarIcon() -> NSImage? {
        let url = Bundle.main.resourceURL?.appendingPathComponent("float.png")
            ?? URL(fileURLWithPath: Bundle.main.executableURL?.deletingLastPathComponent().path ?? "")
                .appendingPathComponent("float.png")
        guard let img = NSImage(contentsOf: url) else { return nil }
        let scaled = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let sourceRect = CGRect(origin: .zero, size: img.size)
            img.draw(in: rect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
            return true
        }
        scaled.isTemplate = false
        return scaled
    }

    // MARK: - 关于窗口（品牌展示 + 项目主页）

    @objc func showAbout() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = Branding.appIcon()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        alert.messageText = "\(Branding.appDisplayName) \(version)"
        alert.informativeText = "一个原生 macOS 桌面悬浮球，点击即可搜索 Mac 快捷键。\n\nMade by \(Branding.author) 🚀\n项目主页：\(Branding.githubURL)"
        alert.addButton(withTitle: "打开 GitHub ⭐")
        alert.addButton(withTitle: "关闭")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: Branding.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 入口（Swift 单文件顶层代码模式，无需 @main）

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory) // 无 Dock 图标，纯菜单栏 + 悬浮球
app.run()
