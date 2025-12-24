//
//  ContentView.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.94, green: 0.92, blue: 0.84),
                    Color(red: 0.90, green: 0.94, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.96, green: 0.86, blue: 0.72, opacity: 0.35),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: -240, y: -260)
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Camcorder Importer")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                        .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.12))
                    Text(viewModel.statusTitle)
                        .font(.custom("Avenir Next", size: 18))
                        .foregroundStyle(Color(red: 0.36, green: 0.32, blue: 0.25))
                }

                dropZone

                VStack(spacing: 12) {
                    Text(viewModel.statusDetail)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(Color(red: 0.38, green: 0.34, blue: 0.28))
                        .multilineTextAlignment(.center)

                    if viewModel.state == .scanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if viewModel.state == .converting {
                        ProgressView(value: viewModel.overallProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(maxWidth: 420)
                        Text(viewModel.progressDetail)
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color(red: 0.46, green: 0.42, blue: 0.36))
                    }

                    if let errorSummary = viewModel.errorSummary {
                        Text(errorSummary)
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(Color(red: 0.70, green: 0.18, blue: 0.12))
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 12) {
                    if let outputFolderURL = viewModel.outputFolderURL {
                        Button("Open Output Folder") {
                            viewModel.openOutputFolder(outputFolderURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.30, green: 0.54, blue: 0.34))
                    }

                    if viewModel.canReset {
                        Button("Import Another") {
                            viewModel.reset()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 680, minHeight: 520)
    }

    private var dropZone: some View {
        let isEnabled = !viewModel.isBusy
        let isTargeted = viewModel.isDropTargeted && isEnabled

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.8 : 0.4))
                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color(red: 0.90, green: 0.52, blue: 0.22) : Color(red: 0.70, green: 0.66, blue: 0.58),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [10, 6])
                )
                .animation(.easeInOut(duration: 0.18), value: isTargeted)

            VStack(spacing: 12) {
                Image(systemName: "memorycard")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.40, green: 0.36, blue: 0.28))
                Text(isEnabled ? "Drop SD Card or Folder" : "Processing...")
                    .font(.custom("Avenir Next Medium", size: 18))
                    .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.20))
                Text("Finds AVCHD .MTS clips and converts to MP4")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color(red: 0.52, green: 0.48, blue: 0.40))
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: 520, minHeight: 220)
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isTargeted)
        .onDrop(of: [UTType.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .opacity(isEnabled ? 1.0 : 0.8)
    }
}

#Preview {
    ContentView()
}
