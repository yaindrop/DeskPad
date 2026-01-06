import SwiftUI
import Combine
import Cocoa

class ScreenViewModel: ObservableObject {
    @Published var isWindowHighlighted = false
    @Published var resolution: CGSize = .zero
    @Published var scaleFactor: CGFloat = 1.0
    
    private var display: CGVirtualDisplay!
    private var stream: CGDisplayStream?
    weak var layer: CALayer? {
        didSet {
            // If layer is set after stream is ready, or if layer changes
            if stream != nil {
                // Stream handler captures [weak self] so it should pick up the new layer?
                // No, the handler is defined at creation.
                // But the handler accesses `self?.layer?.contents`.
                // So updating `self.layer` is sufficient.
            }
        }
    }
    
    private var previousResolution: CGSize?
    private var previousScaleFactor: CGFloat?
    private var mouseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDisplay()
        startMouseMonitoring()
        startScreenMonitoring()
    }
    
    deinit {
        mouseTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupDisplay() {
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "DeskPad Display"
        descriptor.maxPixelsWide = 3840
        descriptor.maxPixelsHigh = 2400
        descriptor.sizeInMillimeters = CGSize(width: 1600, height: 1000)
        descriptor.productID = 0x1234
        descriptor.vendorID = 0x3456
        descriptor.serialNum = 0x0001

        let display = CGVirtualDisplay(descriptor: descriptor)
        self.display = display

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = [
            // 16:9
            CGVirtualDisplayMode(width: 3840, height: 2160, refreshRate: 60),
            CGVirtualDisplayMode(width: 2560, height: 1440, refreshRate: 60),
            CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60),
            CGVirtualDisplayMode(width: 1600, height: 900, refreshRate: 60),
            CGVirtualDisplayMode(width: 1366, height: 768, refreshRate: 60),
            CGVirtualDisplayMode(width: 1280, height: 720, refreshRate: 60),
            // 16:10
            CGVirtualDisplayMode(width: 2560, height: 1600, refreshRate: 60),
            CGVirtualDisplayMode(width: 1920, height: 1200, refreshRate: 60),
            CGVirtualDisplayMode(width: 1680, height: 1050, refreshRate: 60),
            CGVirtualDisplayMode(width: 1440, height: 900, refreshRate: 60),
            CGVirtualDisplayMode(width: 1280, height: 800, refreshRate: 60),
            // Custom
            CGVirtualDisplayMode(width: 3392, height: 2400, refreshRate: 60),
            CGVirtualDisplayMode(width: 2544, height: 1800, refreshRate: 60),
            CGVirtualDisplayMode(width: 1696, height: 1200, refreshRate: 60),
            CGVirtualDisplayMode(width: 848, height: 600, refreshRate: 60),
        ]
        display.apply(settings)
    }
    
    private func startMouseMonitoring() {
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            let screens = NSScreen.screens
            let screenContainingMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
            let isWithinScreen = screenContainingMouse?.displayID == self.display.displayID
            
            if self.isWindowHighlighted != isWithinScreen {
                self.isWindowHighlighted = isWithinScreen
            }
        }
    }
    
    private func startScreenMonitoring() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard let screen = NSScreen.screens.first(where: {
                    $0.displayID == self.display.displayID
                }) else {
                    return
                }
                
                let newResolution = screen.frame.size
                let newScaleFactor = screen.backingScaleFactor
                
                if newResolution != self.resolution || newScaleFactor != self.scaleFactor {
                    self.resolution = newResolution
                    self.scaleFactor = newScaleFactor
                    self.updateStream(resolution: newResolution, scaleFactor: newScaleFactor)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStream(resolution: CGSize, scaleFactor: CGFloat) {
        if resolution != .zero,
           (resolution != previousResolution || scaleFactor != previousScaleFactor) {
            
            previousResolution = resolution
            previousScaleFactor = scaleFactor
            
            setupStream()
        }
    }
    
    private func setupStream() {
        stream = nil
        guard let resolution = previousResolution, let scaleFactor = previousScaleFactor else { return }
        
        let stream = CGDisplayStream(
            dispatchQueueDisplay: display.displayID,
            outputWidth: Int(resolution.width * scaleFactor),
            outputHeight: Int(resolution.height * scaleFactor),
            pixelFormat: 1_111_970_369,
            properties: [
                CGDisplayStream.showCursor: true,
            ] as CFDictionary,
            queue: .main,
            handler: { [weak self] _, _, frameSurface, _ in
                if let surface = frameSurface {
                    self?.layer?.contents = surface
                }
            }
        )
        self.stream = stream
        stream?.start()
    }
    
    func handleClick(at location: CGPoint, in viewSize: CGSize) {
        guard let screenResolution = previousResolution else { return }
        
        let onScreenPoint = NSPoint(
            x: location.x / viewSize.width * screenResolution.width,
            y: location.y / viewSize.height * screenResolution.height
        )
        
        CGDisplayMoveCursorToPoint(display.displayID, onScreenPoint)
    }
}

struct ScreenView: View {
    @ObservedObject var viewModel: ScreenViewModel
    
    var body: some View {
        GeometryReader { geometry in
            DisplaySurfaceView(viewModel: viewModel)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            viewModel.handleClick(at: value.location, in: geometry.size)
                        }
                )
        }
    }
}

struct DisplaySurfaceView: NSViewRepresentable {
    @ObservedObject var viewModel: ScreenViewModel
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        // Pass the layer to the view model
        DispatchQueue.main.async {
            viewModel.layer = view.layer
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if viewModel.layer !== nsView.layer {
             viewModel.layer = nsView.layer
        }
    }
}

class ScreenHostingController: NSHostingController<ScreenView>, NSWindowDelegate {
    let viewModel = ScreenViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    @objc required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        super.init(rootView: ScreenView(viewModel: viewModel))
        // Set a default size to prevent the window from being too small initially
        self.preferredContentSize = CGSize(width: 1280, height: 720)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    private func setupBindings() {
        viewModel.$isWindowHighlighted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHighlighted in
                self?.view.window?.backgroundColor = isHighlighted
                    ? NSColor(named: "TitleBarActive")
                    : NSColor(named: "TitleBarInactive")
                if isHighlighted {
                    self?.view.window?.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)
            
        viewModel.$resolution
            .combineLatest(viewModel.$scaleFactor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] resolution, scaleFactor in
                guard resolution != .zero else { return }
                self?.updateWindowSize(resolution: resolution, scaleFactor: scaleFactor)
            }
            .store(in: &cancellables)
    }
    
    private func updateWindowSize(resolution: CGSize, scaleFactor: CGFloat) {
        guard let window = view.window else { return }
        window.setContentSize(resolution)
        window.contentAspectRatio = resolution
        window.center()
    }

    // MARK: - NSWindowDelegate
    
    func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        let snappingOffset: CGFloat = 30
        let contentSize = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
        
        // Access resolution from viewModel
        let screenResolution = viewModel.resolution
        guard screenResolution != .zero else { return frameSize }
        
        guard abs(contentSize.width - screenResolution.width) < snappingOffset else {
            return frameSize
        }
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: screenResolution)).size
    }
}
