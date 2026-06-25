//
//  ContentView.swift
//  fingerdection
//
//  Created by honman luk on 4/4/2025.
//

import SwiftUI
import AVFoundation
import Vision
import ImageIO

// MARK: - Merged from FingerDetectionViewModel.swift
enum SwipeDirection {
    case up
    case down
    case none
}

class FingerDetectionViewModel: NSObject, ObservableObject {
    @Published var detectionMessage: String = "No movement detected"
    @Published var swipeDirection: SwipeDirection = .none
    @Published var swipeAmplitude: CGFloat = 0
    @Published var isDetectionEnabled: Bool = true
    @Published var permissionGranted: Bool = false
    
    // Add properties to track the last successful swipe direction and dynamic thresholds
    @Published var lastSuccessfulDirection: SwipeDirection = .none
    @Published var upSwipeThreshold: CGFloat = 0.1
    @Published var downSwipeThreshold: CGFloat = 0.1
    
    // Properties for arrow highlight state
    @Published var isUpArrowHighlighted: Bool = false
    @Published var isDownArrowHighlighted: Bool = false
    
    // Add properties for continuous input
    @Published var isContinuousSwipeActive: Bool = false
    private var continuousSwipeTimer: Timer?
    @Published var continuousSwipeDirection: SwipeDirection = .none
    private var continuousSwipeCount: Int = 0
    private let maxContinuousSwipeCount: Int = 10 // Safety limit
    private let continuousSwipeInterval: TimeInterval = 1.5 // 增加到1.5秒，控制連續輸入間隔
    
    @Published private(set) var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue = DispatchQueue(label: "VideoDataOutputQueue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var lastProcessingTime: Date = Date()
    private var processingTimeInterval: TimeInterval = 1.0
    
    private var isCurrentlyInSwipe: Bool = false
    private var swipeResetTimer: Timer?
    
    private var lastIndexTipPosition: CGPoint?
    private var onUpSwipe: (() -> Void)?
    private var onDownSwipe: (() -> Void)?
    
    private var swipeStartPosition: CGPoint?
    private var lastStablePosition: CGPoint? // Added to track position for continuous swipes
    
    // Base threshold values
    private let baseThreshold: CGFloat = 0.1
    private let oppositeDirectionThreshold: CGFloat = 0.4
    
    func setup(onUpSwipe: @escaping () -> Void, onDownSwipe: @escaping () -> Void) {
        self.onUpSwipe = onUpSwipe
        self.onDownSwipe = onDownSwipe
        
        // Check camera permission first
        checkPermission()
    }
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Permission already granted
            permissionGranted = true
            setupCaptureSession()
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.detectionMessage = "Camera access denied"
                    }
                }
            }
        case .denied, .restricted:
            // Permission denied
            permissionGranted = false
            detectionMessage = "Camera access denied"
        @unknown default:
            break
        }
    }
    
    func startDetection() {
        // 只有在權限已授權且尚未運行時才啟動
        guard permissionGranted, captureSession != nil, !(captureSession?.isRunning ?? false) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopDetection() {
        // 只有在正在運行時才停止
        guard captureSession?.isRunning ?? false else {
            return
        }
        
        captureSession?.stopRunning()
    }
    
    private func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            DispatchQueue.main.async { [weak self] in
                self?.detectionMessage = "Failed to access camera"
            }
            return
        }
        
        captureSession.addInput(input)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        // Configure video orientation
        if let connection = videoDataOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        
        self.captureSession = captureSession
        self.videoDataOutput = videoDataOutput
        
        startDetection()
    }
    
    private func processHandPoseObservation(_ observation: VNHumanHandPoseObservation) {
        // 檢查是否處於全局冷卻期，如果是，則不處理手勢
        guard isDetectionEnabled,
              observation.confidence > 0.5,
              !ContentView.isGlobalCoolingDown else { // 使用全局靜態變量來跟踪冷卻狀態
            return
        }
        
        // Get index finger tip position
        guard let indexTip = try? observation.recognizedPoints(.indexFinger)[.indexTip],
              indexTip.confidence > 0.5 else {
            // If finger disappears, stop continuous swipe
            stopContinuousSwipe()
            return
        }
        
        let normalizedPoint = CGPoint(x: indexTip.location.x, y: 1 - indexTip.location.y)
        
        // Store initial position if this is the first frame
        if swipeStartPosition == nil {
            swipeStartPosition = normalizedPoint
            lastIndexTipPosition = normalizedPoint
            lastStablePosition = normalizedPoint  // 也設置為穩定參考點
            return
        }
        
        // Make sure we don't process too frequently for initial swipe
        guard !isCurrentlyInSwipe,
              Date().timeIntervalSince(lastProcessingTime) >= processingTimeInterval,
              let lastPosition = lastIndexTipPosition,
              let startPosition = swipeStartPosition else {
            // Just update last position and return
            lastIndexTipPosition = normalizedPoint
            return
        }
        
        // Calculate vertical movement (y-axis) from start position to current
        let verticalDifference = normalizedPoint.y - startPosition.y
        
        // Determine current direction (even if not enough for a swipe)
        let currentDirection: SwipeDirection = verticalDifference < 0 ? SwipeDirection.up : SwipeDirection.down
        let amplitude = abs(verticalDifference)
        
        // Determine which threshold to use based on direction and last successful direction
        let currentThreshold = currentDirection == .up ? upSwipeThreshold : downSwipeThreshold
        
        // Check if the swipe meets the threshold
        if amplitude > currentThreshold {
            // Prevent further swipe detection temporarily
            isCurrentlyInSwipe = true
            lastProcessingTime = Date()
            
            // Update the last successful direction
            lastSuccessfulDirection = currentDirection
            
            // Update thresholds for next swipes
            updateThresholdsAfterSwipe(direction: currentDirection)
            
            // Store this position for continuous swipe tracking
            lastStablePosition = normalizedPoint
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.swipeDirection = currentDirection
                self.swipeAmplitude = amplitude
                
                // Update the message to include the current threshold
                let thresholdString = String(format: "%.1f", currentThreshold)
                
                switch currentDirection {
                case .up:
                    self.detectionMessage = "Up swipe detected! Amplitude: \(String(format: "%.2f", amplitude))/\(thresholdString)"
                    self.onUpSwipe?()
                    // Highlight up arrow
                    self.isUpArrowHighlighted = true
                    self.isDownArrowHighlighted = false
                    // Start continuous swipe mode with current finger position
                    self.startContinuousSwipe(direction: .up, position: normalizedPoint)
                case .down:
                    self.detectionMessage = "Down swipe detected! Amplitude: \(String(format: "%.2f", amplitude))/\(thresholdString)"
                    self.onDownSwipe?()
                    // Highlight down arrow
                    self.isDownArrowHighlighted = true
                    self.isUpArrowHighlighted = false
                    // Start continuous swipe mode with current finger position
                    self.startContinuousSwipe(direction: .down, position: normalizedPoint)
                case .none:
                    self.isUpArrowHighlighted = false
                    self.isDownArrowHighlighted = false
                    break
                }
                
                // 觸發方向後，重置起始位置為當前位置
                self.swipeStartPosition = normalizedPoint
                
                // Reset swipe detection after delay but keep continuous mode
                self.resetSwipeAfterDelay(keepContinuous: true)
            }
        } else if isContinuousSwipeActive && lastStablePosition != nil {
            // Check if we're in continuous mode and should continue the swipe
            
            // Calculate from the last stable position instead of start position
            let continuousDifference = normalizedPoint.y - lastStablePosition!.y
            let continuousDirection: SwipeDirection = continuousDifference < 0 ? SwipeDirection.up : SwipeDirection.down
            let continuousAmplitude = abs(continuousDifference)
            
            // If the direction is the same as continuous mode and amplitude increased
            if continuousDirection == continuousSwipeDirection && continuousAmplitude > currentThreshold * 0.6 {
                // Update the stable position to the new one
                lastStablePosition = normalizedPoint
                
                // Continue the continuous swipe with the updated position
                updateContinuousSwipeStatus(newAmplitude: continuousAmplitude)
            }
            // If user moved in opposite direction, quickly detect as new direction
            else if continuousDirection != continuousSwipeDirection && continuousAmplitude > 0.08 {  // 降低閾值，更快檢測新方向
                // 檢測到相反方向移動，且移動幅度足夠大
                
                // 停止原來的連續模式
                stopContinuousSwipe()
                
                // 重置閾值，以便於切換方向
                updateThresholdsAfterSwipe(direction: .none)
                
                // 如果幅度已經達到檢測閾值，直接觸發新方向
                if continuousAmplitude > baseThreshold {
                    swipeStartPosition = lastStablePosition // 使用上次穩定位置作為起點
                    swipeDirection = continuousDirection
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // 觸發對應方向的動作
                        if continuousDirection == .up {
                            self.onUpSwipe?()
                            self.isUpArrowHighlighted = true
                            self.isDownArrowHighlighted = false
                            self.detectionMessage = "Quick direction change: Up"
                        } else {
                            self.onDownSwipe?()
                            self.isUpArrowHighlighted = false
                            self.isDownArrowHighlighted = true
                            self.detectionMessage = "Quick direction change: Down"
                        }
                        
                        // 使用新位置開始新的連續模式
                        self.startContinuousSwipe(direction: continuousDirection, position: normalizedPoint)
                    }
                }
            }
            // If user moved back significantly in same direction, also stop
            else if continuousDirection == continuousSwipeDirection && continuousAmplitude > 0.15 {  // 降低閾值，適應更靈敏的檢測
                stopContinuousSwipe()
                
                // 重置起始位置為當前位置，便於下一次檢測
                swipeStartPosition = normalizedPoint
            }
            
            // Update last position
            lastIndexTipPosition = normalizedPoint
        } else {
            // Show current swipe progress/amplitude in realtime
            if amplitude > 0.02 { // 降低檢測閾值，使更小的移動也能被檢測到
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.swipeAmplitude = amplitude
                    
                    // Update arrow highlights based on current direction
                    if !self.isContinuousSwipeActive {
                        if amplitude > currentThreshold * 0.3 {  // 更小的比例，適應更低的閾值
                            // Pre-highlight the arrow with lower threshold
                            self.isUpArrowHighlighted = (currentDirection == .up)
                            self.isDownArrowHighlighted = (currentDirection == .down)
                        } else {
                            // Reset highlights when amplitude is small
                            self.isUpArrowHighlighted = false
                            self.isDownArrowHighlighted = false
                        }
                    }
                    
                    // Show the appropriate threshold for the current direction
                    let directionThreshold = currentDirection == .up ? self.upSwipeThreshold : self.downSwipeThreshold
                    self.detectionMessage = "\(currentDirection == .up ? "Up" : "Down") progress: \(String(format: "%.2f", amplitude))/\(String(format: "%.1f", directionThreshold))"
                }
            }
            
            // If finger is still present but not in continuous mode and not enough for a swipe,
            // update positions
            lastIndexTipPosition = normalizedPoint
        }
    }
    
    // Start continuous swipe mode
    private func startContinuousSwipe(direction: SwipeDirection, position: CGPoint) {
        continuousSwipeDirection = direction
        isContinuousSwipeActive = true
        continuousSwipeCount = 1 // Count the first swipe
        
        // 使用當前手指位置作為新的穩定參考點
        lastStablePosition = position
        
        // Update arrow highlight state based on direction
        isUpArrowHighlighted = (direction == .up)
        isDownArrowHighlighted = (direction == .down)
        
        // Cancel existing timer if any
        continuousSwipeTimer?.invalidate()
        
        // Create a timer for continuous swipes
        continuousSwipeTimer = Timer.scheduledTimer(withTimeInterval: continuousSwipeInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.isContinuousSwipeActive,
                  self.continuousSwipeCount < self.maxContinuousSwipeCount else {
                self?.stopContinuousSwipe()
                return
            }
            
            DispatchQueue.main.async {
                // Trigger the appropriate action based on direction
                switch self.continuousSwipeDirection {
                case .up:
                    self.detectionMessage = "Continuous up swipe (\(self.continuousSwipeCount))"
                    self.onUpSwipe?()
                    // Ensure arrows are properly highlighted during continuous swipe
                    self.isUpArrowHighlighted = true
                    self.isDownArrowHighlighted = false
                case .down:
                    self.detectionMessage = "Continuous down swipe (\(self.continuousSwipeCount))"
                    self.onDownSwipe?()
                    // Ensure arrows are properly highlighted during continuous swipe
                    self.isDownArrowHighlighted = true
                    self.isUpArrowHighlighted = false
                case .none:
                    // Reset arrow highlight states
                    self.isUpArrowHighlighted = false
                    self.isDownArrowHighlighted = false
                    break
                }
                
                // Increment the count
                self.continuousSwipeCount += 1
            }
        }
    }
    
    // Update continuous swipe status
    private func updateContinuousSwipeStatus(newAmplitude: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.swipeAmplitude = newAmplitude
            self.detectionMessage = "Continuous \(self.continuousSwipeDirection == .up ? "up" : "down") active (\(self.continuousSwipeCount))"
        }
    }
    
    // Stop continuous swipe mode
    private func stopContinuousSwipe() {
        // Clean up timers and reset state
        continuousSwipeTimer?.invalidate()
        continuousSwipeTimer = nil
        isContinuousSwipeActive = false
        continuousSwipeDirection = .none
        continuousSwipeCount = 0
        lastStablePosition = nil
        
        // Reset arrow highlight states
        isUpArrowHighlighted = false
        isDownArrowHighlighted = false
        
        // 重置閾值，使各方向都為基本閾值
        // 這樣在連續模式結束後，各方向的檢測靈敏度相同
        upSwipeThreshold = baseThreshold
        downSwipeThreshold = baseThreshold
    }
    
    // New method to update thresholds after a successful swipe
    private func updateThresholdsAfterSwipe(direction: SwipeDirection) {
        switch direction {
        case .up:
            // Set up direction to base threshold
            upSwipeThreshold = baseThreshold
            // Set opposite direction to higher threshold
            downSwipeThreshold = oppositeDirectionThreshold
        case .down:
            // Set down direction to base threshold
            downSwipeThreshold = baseThreshold
            // Set opposite direction to higher threshold
            upSwipeThreshold = oppositeDirectionThreshold
        case .none:
            // Reset both to base threshold
            upSwipeThreshold = baseThreshold
            downSwipeThreshold = baseThreshold
        }
    }
    
    private func resetSwipeAfterDelay(keepContinuous: Bool = false) {
        // Cancel existing timer if any
        swipeResetTimer?.invalidate()
        
        // Create new timer
        swipeResetTimer = Timer.scheduledTimer(withTimeInterval: processingTimeInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isCurrentlyInSwipe = false
                
                // 始終保持最後已知的位置作為起始位置
                // 這樣可以更自然地檢測方向變化
                // self?.swipeStartPosition 保持為上一次設置的值
                
                // Only reset if we're not keeping continuous mode
                if !keepContinuous || self?.isContinuousSwipeActive == false {
                    // self?.swipeStartPosition = nil  // 不要重置起始位置，使用最後已知的位置
                    self?.swipeDirection = .none
                    
                    // Only reset arrow highlights if we're not in continuous mode
                    if self?.isContinuousSwipeActive == false {
                        self?.isUpArrowHighlighted = false
                        self?.isDownArrowHighlighted = false
                    }
                }
            }
        }
    }
    
    // Make sure to stop timers when the object is deallocated
    deinit {
        swipeResetTimer?.invalidate()
        continuousSwipeTimer?.invalidate()
    }
}

extension FingerDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process video frame
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handPoseRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            guard let self = self, error == nil else {
                return
            }
            
            guard let observations = request.results as? [VNHumanHandPoseObservation],
                  let observation = observations.first else {
                return
            }
            
            self.processHandPoseObservation(observation)
        }
        
        handPoseRequest.maximumHandCount = 1
        
        // Use an alternative constructor without orientation
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        // Perform the hand pose detection request
        do {
            try handler.perform([handPoseRequest])
        } catch {
            print("Error performing hand pose request: \(error)")
            // Log error for debugging purposes
        }
    }
}

// MARK: - Merged from CameraPreviewView.swift
struct CameraPreviewView: UIViewRepresentable {
    let captureSession: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// A separate view for the direction indicators
struct DirectionIndicatorsView: View {
    let viewModel: FingerDetectionViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            // Up direction indicator
            VStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .foregroundColor(
                        viewModel.isUpArrowHighlighted ? .green : .white.opacity(0.5)
                    )
                    .font(.largeTitle)
                
                Text("Need: \(String(format: "%.1f", viewModel.upSwipeThreshold))")
                    .font(.caption)
                    .foregroundColor(viewModel.lastSuccessfulDirection == .up ? .green : .white)
            }
            
            // Direction info
            VStack {
                Text("Last: \(directionText(viewModel.lastSuccessfulDirection))")
                    .font(.caption)
                    .foregroundColor(.white)
                
                // Show continuous mode status
                Text(viewModel.isContinuousSwipeActive ?
                     "CONTINUOUS: \(directionText(viewModel.continuousSwipeDirection))" :
                     "Current: \(String(format: "%.2f", viewModel.swipeAmplitude))")
                    .font(.caption)
                    .foregroundColor(viewModel.isContinuousSwipeActive ? .orange : .white)
            }
            
            // Down direction indicator
            VStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .foregroundColor(
                        viewModel.isDownArrowHighlighted ? .green : .white.opacity(0.5)
                    )
                    .font(.largeTitle)
                
                Text("Need: \(String(format: "%.1f", viewModel.downSwipeThreshold))")
                    .font(.caption)
                    .foregroundColor(viewModel.lastSuccessfulDirection == .down ? .green : .white)
            }
        }
    }
    
    // Helper function to convert SwipeDirection to text
    private func directionText(_ direction: SwipeDirection) -> String {
        switch direction {
        case .up:
            return "Up"
        case .down:
            return "Down"
        case .none:
            return "None"
        }
    }
}

// A separate view for continuous mode indicator
struct ContinuousModeIndicatorView: View {
    let viewModel: FingerDetectionViewModel
    
    var body: some View {
        if viewModel.isContinuousSwipeActive {
            HStack {
                Image(systemName: "repeat")
                    .foregroundColor(.orange)
                
                Text("持续\(viewModel.continuousSwipeDirection == .up ? "上" : "下")滑模式激活")
                    .foregroundColor(.orange)
                    .font(.callout)
                    .bold()
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .padding(.vertical, 4)
        }
    }
}

// A separate view for the swipe progress bars
struct SwipeProgressBarsView: View {
    let viewModel: FingerDetectionViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Up direction progress
            upProgressBar
            
            // Down direction progress
            downProgressBar
        }
        .padding(.vertical, 8)
    }
    
    private var upProgressBar: some View {
        VStack(spacing: 2) {
            Text("Up Progress")
                .foregroundColor(.white)
                .font(.caption)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 6)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(200 * (viewModel.swipeAmplitude / viewModel.upSwipeThreshold), 200), height: 6)
                    .opacity(viewModel.swipeDirection == .up ? 1.0 : 0.7)
                    .foregroundColor(progressColor(for: .up))
            }
            .frame(width: 200)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    private var downProgressBar: some View {
        VStack(spacing: 2) {
            Text("Down Progress")
                .foregroundColor(.white)
                .font(.caption)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 6)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(200 * (viewModel.swipeAmplitude / viewModel.downSwipeThreshold), 200), height: 6)
                    .opacity(viewModel.swipeDirection == .down ? 1.0 : 0.7)
                    .foregroundColor(progressColor(for: .down))
            }
            .frame(width: 200)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    // Helper function to determine progress color
    private func progressColor(for direction: SwipeDirection) -> Color {
        let thresholdValue = direction == .up ? viewModel.upSwipeThreshold : viewModel.downSwipeThreshold
        let progress = viewModel.swipeAmplitude / thresholdValue
        
        if viewModel.swipeDirection == direction {
            return .green
        } else if progress >= 1.0 {
            return .green
        } else if progress > 0.7 {
            return .yellow
        } else {
            return .blue
        }
    }
}

// A separate view for the cooldown indicator
struct CooldownIndicatorView: View {
    let isCoolingDown: Bool
    let coolingDownProgress: CGFloat
    
    var body: some View {
        Group {
            if isCoolingDown {
                VStack(spacing: 4) {
                    Text("Cooldown: Wait for next swipe")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    // Cooldown progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 4)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Rectangle()
                            .frame(width: 200 * coolingDownProgress, height: 4)
                            .foregroundColor(.yellow)
                    }
                    .frame(width: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// Main content view
struct ContentView: View {
    // 全局靜態變量，用於跟踪冷卻狀態
    static var isGlobalCoolingDown: Bool = false
    
    @StateObject private var viewModel = FingerDetectionViewModel()
    @State private var currentPage = 0
    @State private var totalPages = 5
    @State private var isCoolingDown = false
    @State private var coolingDownProgress: CGFloat = 0
    private let coolingDownDuration: TimeInterval = 1.5 // 增加到1.5秒，讓頁面跳轉有足夠冷卻時間
    
    var body: some View {
        ZStack {
            // Background content
            Color.black.edgesIgnoringSafeArea(.all)
            
            if viewModel.permissionGranted {
                permissionGrantedView
            } else {
                permissionDeniedView
            }
        }
        .onAppear {
            setupViewModel()
        }
    }
    
    // Permission granted content
    private var permissionGrantedView: some View {
        ZStack {
            // Camera preview
            if let captureSession = viewModel.captureSession {
                CameraPreviewView(captureSession: captureSession)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // UI Elements overlay
            VStack {
                // Page indicator
                Text("Page \(currentPage + 1) of \(totalPages)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.top, 40)
                
                Spacer()
                
                // Detection controls
                controlsContainer
            }
        }
    }
    
    // Controls container
    private var controlsContainer: some View {
        VStack(spacing: 10) {
            Text(viewModel.detectionMessage)
                .font(.headline)
                .foregroundColor(.white)
            
            // Add the continuous mode indicator
            ContinuousModeIndicatorView(viewModel: viewModel)
            
            DirectionIndicatorsView(viewModel: viewModel)
            
            SwipeProgressBarsView(viewModel: viewModel)
            
            CooldownIndicatorView(
                isCoolingDown: isCoolingDown,
                coolingDownProgress: coolingDownProgress
            )
            
            // Toggle for enabling/disabling detection
            Toggle("Enable Detection", isOn: $viewModel.isDetectionEnabled)
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
        .padding(.bottom, 40)
    }
    
    // Permission denied view
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 70))
                .foregroundColor(.white)
            
            Text("Camera Access Required")
                .font(.title)
                .foregroundColor(.white)
            
            Text(viewModel.detectionMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // Setup view model
    private func setupViewModel() {
        viewModel.setup(
            onUpSwipe: {
                // Handle up swipe - go to previous page
                withAnimation {
                    if currentPage > 0 {
                        currentPage -= 1
                    }
                }
                startCooldownTimer()
            },
            onDownSwipe: {
                // Handle down swipe - go to next page
                withAnimation {
                    if currentPage < totalPages - 1 {
                        currentPage += 1
                    }
                }
                startCooldownTimer()
            }
        )
    }
    
    // Start cooldown timer
    private func startCooldownTimer() {
        // 設置本地和全局冷卻狀態
        isCoolingDown = true
        ContentView.isGlobalCoolingDown = true
        coolingDownProgress = 0
        
        withAnimation(.linear(duration: coolingDownDuration)) {
            coolingDownProgress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + coolingDownDuration) {
            // 冷卻時間結束，重置狀態
            isCoolingDown = false
            ContentView.isGlobalCoolingDown = false
            coolingDownProgress = 0
        }
    }
}

// MARK: - Background Hand Gesture Detector
struct BackgroundHandGestureDetector: View {
    @StateObject private var viewModel = FingerDetectionViewModel()
    @State private var showPermissionAlert: Bool = false
    @Binding var isEnabled: Bool
    private var onUpSwipe: () -> Void
    private var onDownSwipe: () -> Void
    private let coolingDownDuration: TimeInterval = 1.5
    
    init(isEnabled: Binding<Bool> = .constant(true), onUpSwipe: @escaping () -> Void, onDownSwipe: @escaping () -> Void) {
        self._isEnabled = isEnabled
        self.onUpSwipe = onUpSwipe
        self.onDownSwipe = onDownSwipe
    }
    
    var body: some View {
        // Empty view that won't display anything on screen
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                setupViewModel()
            }
            .onChange(of: isEnabled) { oldValue, newValue in
                viewModel.isDetectionEnabled = newValue
                if newValue {
                    // 如果啟用，先確認權限並啟動相機
                    checkPermissionAndStartCamera()
                } else {
                    // 如果禁用，停止相機以節省資源
                    viewModel.stopDetection()
                }
            }
            .alert("Camera Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Flavour Gesture requires camera access to detect hand movements.")
            }
    }
    
    // Setup view model
    private func setupViewModel() {
        viewModel.isDetectionEnabled = isEnabled
        viewModel.setup(
            onUpSwipe: {
                if isEnabled {
                    self.onUpSwipe()
                    startCooldownTimer()
                }
            },
            onDownSwipe: {
                if isEnabled {
                    self.onDownSwipe()
                    startCooldownTimer()
                }
            }
        )
        
        // 確保初始狀態與 isEnabled 一致
        if isEnabled {
            checkPermissionAndStartCamera()
        } else {
            viewModel.stopDetection()
        }
    }
    
    // 檢查權限並啟動相機
    private func checkPermissionAndStartCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 權限已授予，啟動相機
            viewModel.startDetection()
        case .notDetermined:
            // 請求權限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        // 用戶同意授權，啟動相機
                        viewModel.startDetection()
                    } else {
                        // 用戶拒絕授權，顯示提示
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // 權限被拒絕，顯示提示
            showPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    // Start cooldown timer
    private func startCooldownTimer() {
        // Set global cooldown state
        ContentView.isGlobalCoolingDown = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + coolingDownDuration) {
            // Reset cooldown state after duration
            ContentView.isGlobalCoolingDown = false
        }
    }
}

#Preview {
    ContentView()
}
