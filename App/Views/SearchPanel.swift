import LocationSimCore
import SwiftUI

struct SearchPanel: View {
    @Bindable var viewModel: SimulatorViewModel
    @FocusState private var focused: Bool
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search a place or address", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .accessibilityIdentifier("searchField")
                    .onChange(of: viewModel.query) { viewModel.queryChanged() }
                if viewModel.isSearching {
                    ProgressView()
                } else if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
                if viewModel.providers.count > 1 {
                    Menu {
                        Picker("Provider", selection: $viewModel.selectedProviderIndex) {
                            ForEach(viewModel.providers.indices, id: \.self) { index in
                                Text(viewModel.providers[index].providerName).tag(index)
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                    .accessibilityIdentifier("providerMenu")
                }
            }
            .padding(12)

            if let error = viewModel.searchError {
                Divider()
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .accessibilityIdentifier("searchError")
            }

            if !viewModel.suggestions.isEmpty {
                Divider()
                ScrollView {
                    suggestionList
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(listHeight, 280))
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 4, y: 2)
    }

    // Translucent styles (.secondary, Divider) are not drawn inside this ScrollView over the material background.
    private static let subtitleColor = Color(uiColor: .systemGray)
    private static let separatorColor = Color(uiColor: .opaqueSeparator)

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    focused = false
                    Task { await viewModel.select(suggestion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title).font(.body).foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle).font(.caption).foregroundStyle(Self.subtitleColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("searchResult_\(index)")
                Rectangle().fill(Self.separatorColor).frame(height: 0.5).padding(.leading, 12)
            }
        }
    }
}
