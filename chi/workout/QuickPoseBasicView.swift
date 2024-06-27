//
//  QuickPoseBasicView.swift
//  FitCount
//
//  Created by QuickPose.ai on 22.05.2023.
//

import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI
import AVFoundation
import SwiftData

struct SessionData: Equatable {
    let count: Int
    let seconds: Int
}

enum ViewState: Equatable {
    case startVolume
    case instructions
    case introBoundingBox
    case boundingBox(enterTime: Date)
    case introExercise(Exercise)
    case exercise(SessionData, enterTime: Date)
    case results(SessionData)
    
    var speechPrompt: String? {
        switch self {
        case .introBoundingBox:
            return "Stand so that your whole body is inside the bounding box"
        case .introExercise(let exercise):
            return "Now let's start the \(exercise.name) exercise"
        default:
            return nil
        }
    }
}


//01HZJAKE5YFK9YQPFPKWTJ5VMK

struct QuickPoseBasicView: View {
    private var quickPose = QuickPose(sdkKey: "01HZJAKE5YFK9YQPFPKWTJ5VMK") // register for your free key at https://dev.quickpose.ai
    
    @EnvironmentObject var sessionConfig: SessionConfig
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var overlayImage: UIImage?
    @State private var feedbackText: String? = nil
    
    @State var lastUpdateTime: Date = Date.distantPast
    @Environment(\.modelContext) private var modelContext
    // 1000 ms
    private var minIntervalMs: TimeInterval = 1000

    
    @State private var actualCount = 0
    @State private var counter = QuickPoseThresholdCounter()
    @State private var state: ViewState = .introBoundingBox
    
    @State private var resultPercent = 0.0
    @State private var boundingBoxVisibility = 1.0
    @State private var countScale = 1.0
    @State private var boundingBoxMaskWidth = 0.0
    
    static let synthesizer = AVSpeechSynthesizer()
    
    func canMoveFromBoundingBox(landmarks: QuickPose.Landmarks) -> Bool {
        let xsInBox = landmarks.allLandmarksForBody().allSatisfy { 0.5 - (0.8/2) < $0.x && $0.x < 0.5 + (0.8/2) }
        let ysInBox = landmarks.allLandmarksForBody().allSatisfy { 0.5 - (0.9/2) < $0.y && $0.y < 0.5 + (0.9/2) }
        
        return xsInBox && ysInBox
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack(alignment: .top) {
                    QuickPoseCameraView(useFrontCamera: true, delegate: quickPose)
                    QuickPoseOverlayView(overlayImage: $overlayImage)
                }
                .frame(width: geometry.safeAreaInsets.leading + geometry.size.width + geometry.safeAreaInsets.trailing)
                .edgesIgnoringSafeArea(.all)
                .overlay() {
                    switch state {
                    case .introBoundingBox:
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.red, lineWidth: 5)
                        }
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.9)
                        .padding(.horizontal, (geometry.size.width * 1 - 0.8)/2)
                        
                    case .boundingBox:
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.green, lineWidth: 5)
                            
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.green.opacity(0.5))
                                .mask(alignment: .leading) {
                                    Rectangle()
                                        .frame(width: geometry.size.width * 0.9 * boundingBoxMaskWidth)
                                }
                        }
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.9)
                        .padding(.horizontal, (geometry.size.width * 1 - 0.8)/2)
                        
                        
                    case .results(let results):
                        WorkoutResultsView(sessionData: results)
                            .environmentObject(sessionConfig)

                    default:
                        EmptyView()
                    }
                }
                
                .overlay(alignment: .topTrailing) {
                    Button(action: {
                        if let goals = try? modelContext.fetch(FetchDescriptor<Goal>()) {
                            for goal in goals {
                                let prev = goal.getLocalUserValue()
                                _ = goal.updateData(val: prev + Double(counter.state.count), date: Date.now)
                                Task {
                                    do {
                                        try await CloudManager.saveToCloud(goal:goal)
                                    } catch (let error) {
                                        print("failed to save to cloud \(error)")
                                    }
                                }
                            }
                        }
                        quickPose.stop()
                        dismiss()
                        /*
                        if case .results = state {
                            dismiss()
                        
                        } else {
                            state = .results(SessionData(count: counter.state.count, seconds: 0))
                            quickPose.stop()
                        }
                         */
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color("AccentColor"))
                    }
                    .padding()
                }
                
                .overlay(alignment: .bottom) {
                    if case .exercise(let results, let enterTime) = state {
                        VStack {
                            Text(String(results.count) + (sessionConfig.useReps ? " \\ " + String(sessionConfig.nReps) : "") + " reps")
                                .font(.system(size: 30, weight: .semibold))
                                .padding(16)
                                .scaleEffect(countScale)
                            
                            Text("Count: \(actualCount) Percent: \(Int(resultPercent*100))")
                                .font(.system(size: 30, weight: .semibold))
                            /*
                             Text(String(format: "%.0f",-enterTime.timeIntervalSinceNow) + (!sessionConfig.useReps ? " \\ " + String(sessionConfig.nSeconds + sessionConfig.nMinutes * 60) : "") + " sec")
                             .font(.system(size: 30, weight: .semibold))
                             .padding(16)
                             */
                            ProgressBar(progress: resultPercent, include_text: false)
                                .frame(height: 15)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Color.accentColor)
                        .background(Color.beige)
                    }
                }
                .overlay(alignment: .center) {
                    if case .exercise = state {
                        if let feedbackText = feedbackText {
                            Text(feedbackText)
                                .font(.system(size: 26, weight: .semibold)).foregroundColor(.white)
                                .padding(16)
                        }
                    }
                }
                
                .onChange(of: state) {
                    if case .results(let result) = state {
                        let sessionDataDump = SessionDataModel(exercise: sessionConfig.exercise.name, count: result.count, seconds: result.seconds, date: Date())
                        appendToJson(sessionData: sessionDataDump)
                    }
                    
                    quickPose.update(features: sessionConfig.exercise.features)
                }
                .onAppear() {
                    UIApplication.shared.isIdleTimerDisabled = true
                    DispatchQueue.main.asyncAfter(deadline: .now()+1.0){
                        quickPose.start(features: sessionConfig.exercise.features, onFrame: { status, image, features, feedback, landmarks in
                            overlayImage = image
                            if case .success = status {
                                
                                switch state {
                                case .introBoundingBox:
                                    
                                    if let landmarks = landmarks, canMoveFromBoundingBox(landmarks: landmarks) {
                                        state = .boundingBox(enterTime: Date())
                                        boundingBoxMaskWidth = 0
                                    }
                                case .boundingBox(let enterDate):
                                    if let landmarks = landmarks, canMoveFromBoundingBox(landmarks: landmarks) {
                                        let timeSinceInsideBBox = -enterDate.timeIntervalSinceNow
                                        boundingBoxMaskWidth = timeSinceInsideBBox / 2
                                        if timeSinceInsideBBox > 2 {
                                            state = .introExercise(sessionConfig.exercise)
                                        }
                                    } else {
                                        state = .introBoundingBox
                                    }
                                case .introExercise(_):
                                    DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                                        state = .exercise(SessionData(count: 0, seconds: 0), enterTime: Date())
                                    }
                                case .exercise(_, let enterDate):
                                    let secondsElapsed = Int(-enterDate.timeIntervalSinceNow)
                                    
                                    if let feedback = feedback[sessionConfig.exercise.features.first!] {
                                        feedbackText = feedback.displayString
                                    } else {
                                        feedbackText = nil
                                        
                                        if case .fitness = sessionConfig.exercise.features.first, let result = features[sessionConfig.exercise.features.first!] {
                                            resultPercent = result.value
                                            _ = counter.count(result.value) { newState in
                                                switch (newState) {
                                                case .poseComplete(let num):
                                                    let currentTime = Date()
                                                    let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime) * 1000 // convert to milliseconds
                                                    if timeSinceLastUpdate >= minIntervalMs {
                                                        actualCount += 1
                                                        lastUpdateTime = currentTime
                                                    } else {
                                                        print("Update rejected: Too soon since last update")
                                                    }
                                                default:
                                                    break;
                                                }
                                                if !newState.isEntered {
                                                    Text2Speech(text: "\(counter.state.count)").say()
                                                    DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                                                        withAnimation(.easeInOut(duration: 0.1)) {
                                                            countScale = 2.0
                                                        }
                                                        DispatchQueue.main.asyncAfter(deadline: .now()+0.4) {
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                countScale = 1.0
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    let newResults = SessionData(count: counter.state.count, seconds: secondsElapsed)
                                    state = .exercise(newResults, enterTime: enterDate) // refresh view for every updated second
                                    /*
                                    var hasFinished = false
                                    if sessionConfig.useReps {
                                        hasFinished = counter.state.count >= sessionConfig.nReps
                                    } else {
                                        hasFinished = secondsElapsed >= sessionConfig.nSeconds + sessionConfig.nMinutes * 60
                                    }
                                    
                                    if hasFinished {
                                        state = .results(newResults)
                                    }
                                     */
                                default:
                                    break
                                }
                            } else if state != .startVolume && state != .instructions{
                                state = .introBoundingBox
                            }
                        })
                    }
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

