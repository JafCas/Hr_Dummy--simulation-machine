import LocationSimCore
import SwiftUI

struct SearchPanel: View {
    @Bindable var viewModel: SimulatorViewModel
    @FocusState private var focused: Bool

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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            Button {
                                focused = false
                                Task { await viewModel.select(suggestion) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title).font(.body).foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("searchResult_\(index)")
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 4, y: 2)
    }
}
