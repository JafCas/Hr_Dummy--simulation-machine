import CoreLocation
import LocationSimCore
import MapKit
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: SimulatorViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCoordinateEntry = false
    @State private var showHistory = false
    @State private var showHowTo = false
    @State private var locationManager = CLLocationManager()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                overlays
            }
            .navigationTitle("Location Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showCoordinateEntry) {
                CoordinateEntrySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showHistory) {
                HistorySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showHowTo) {
                HowToApplySheet(coordinate: viewModel.selected?.coordinate)
            }
            .sheet(item: $viewModel.exportItem) { item in
                ActivityView(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            if !AppEnvironment.isUITesting { locationManager.requestWhenInUseAuthorization() }
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()
                if let selected = viewModel.selected {
                    Marker(selected.name, systemImage: "mappin", coordinate: selected.coordinate.clCoordinate)
                        .tint(.red)
                    if viewModel.effectiveAccuracyRadius > 0 {
                        MapCircle(center: selected.coordinate.clCoordinate, radius: viewModel.effectiveAccuracyRadius)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue, lineWidth: 1)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.visibleCenter = Coordinate(context.region.center)
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                Task { await viewModel.dropPin(at: Coordinate(coordinate)) }
            }
            .accessibilityIdentifier("map")
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var overlays: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .top) {
                VStack(spacing: 12) {
                    SearchPanel(viewModel: viewModel)
                    if viewModel.selected != nil { LocationPanel(viewModel: viewModel, showHowTo: $showHowTo) }
                    Spacer(minLength: 0)
                }
                .frame(width: 380)
                Spacer(minLength: 0)
            }
            .padding()
        } else {
            VStack(spacing: 12) {
                SearchPanel(viewModel: viewModel)
                Spacer(minLength: 0)
                if viewModel.selected != nil { LocationPanel(viewModel: viewModel, showHowTo: $showHowTo) }
            }
            .padding()
        }
        if let toast = viewModel.toastMessage {
            VStack {
                Spacer()
                Text(toast)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .accessibilityIdentifier("toast")
                    .padding(.bottom, 40)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showCoordinateEntry = true } label: {
                Label("Coordinates or link", systemImage: "link.badge.plus")
            }
            .accessibilityIdentifier("coordinateEntryButton")
            Button { showHistory = true } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("historyButton")
            Button { showHowTo = true } label: {
                Label("How to apply", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("howToButton")
        }
    }
}
