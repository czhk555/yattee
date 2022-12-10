import Defaults
import Siesta
import SwiftUI

struct TrendingView: View {
    @StateObject private var store = Store<[Video]>()
    private var videos = [Video]()

    @Default(.trendingCategory) private var category
    @Default(.trendingCountry) private var country

    @State private var presentingCountrySelection = false

    @State private var favoriteItem: FavoriteItem?

    @ObservedObject private var accounts = AccountsModel.shared

    var trending: [ContentItem] {
        ContentItem.array(of: store.collection)
    }

    init(_ videos: [Video] = [Video]()) {
        self.videos = videos
    }

    var resource: Resource {
        let newResource: Resource

        newResource = accounts.api.trending(country: country, category: category)
        newResource.addObserver(store)

        return newResource
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                #if os(tvOS)
                    toolbar
                    HorizontalCells(items: trending)
                        .padding(.top, 40)

                    Spacer()
                #else
                    VerticalCells(items: trending)
                        .environment(\.scrollViewBottomPadding, 70)
                #endif
            }
        }

        .toolbar {
            #if os(macOS)
                ToolbarItemGroup {
                    if let favoriteItem {
                        FavoriteButton(item: favoriteItem)
                            .id(favoriteItem.id)
                    }

                    if accounts.app.supportsTrendingCategories {
                        categoryButton
                    }
                    countryButton
                }
            #endif
        }
        .onChange(of: resource) { _ in
            resource.load()
            updateFavoriteItem()
        }
        .onAppear {
            if videos.isEmpty {
                resource.addObserver(store)
                resource.loadIfNeeded()
            } else {
                store.replace(videos)
            }

            updateFavoriteItem()
        }

        #if os(tvOS)
        .fullScreenCover(isPresented: $presentingCountrySelection) {
            TrendingCountry(selectedCountry: $country)
        }
        #else
                .sheet(isPresented: $presentingCountrySelection) {
                    TrendingCountry(selectedCountry: $country)
                    #if os(macOS)
                        .frame(minWidth: 400, minHeight: 400)
                    #endif
                }
                .background(
                    Button("Refresh") {
                        resource.load()
                    }
                    .keyboardShortcut("r")
                    .opacity(0)
                )
                .navigationTitle("Trending")
        #endif
        #if os(iOS)
        .refreshControl { refreshControl in
            resource.load().onCompletion { _ in
                refreshControl.endRefreshing()
            }
        }
        .backport
        .refreshable {
            DispatchQueue.main.async {
                resource.load().onFailure { error in
                    NavigationModel.shared.presentAlert(title: "Could not refresh Trending", message: error.userMessage)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                trendingMenu
            }
        }
        #endif
        #if !os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            resource.loadIfNeeded()
        }
        #endif
    }

    #if os(tvOS)
        private var toolbar: some View {
            HStack {
                if accounts.app.supportsTrendingCategories {
                    HStack {
                        Text("Category")
                            .foregroundColor(.secondary)

                        categoryButton
                    }
                }

                HStack {
                    Text("Country")
                        .foregroundColor(.secondary)

                    countryButton
                }

                if let favoriteItem {
                    FavoriteButton(item: favoriteItem)
                        .id(favoriteItem.id)
                        .labelStyle(.iconOnly)
                }
            }
        }
    #endif

    #if os(iOS)
        var trendingMenu: some View {
            Menu {
                countryButton
                if accounts.app.supportsTrendingCategories {
                    categoryButton
                }
                FavoriteButton(item: favoriteItem)
            } label: {
                HStack(spacing: 12) {
                    Text("\(country.flag) \(country.name)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                }
                .frame(maxWidth: 320)
            }
        }
    #endif

    private var categoryButton: some View {
        #if os(tvOS)
            Button(category.name) {
                self.category = category.next()
            }
            .contextMenu {
                ForEach(TrendingCategory.allCases) { category in
                    Button(category.controlLabel) { self.category = category }
                }

                Button("Cancel", role: .cancel) {}
            }

        #else
            Picker(category.controlLabel, selection: $category) {
                ForEach(TrendingCategory.allCases) { category in
                    Label(category.controlLabel, systemImage: category.systemImage).tag(category)
                }
            }
        #endif
    }

    private var countryButton: some View {
        Button(action: {
            presentingCountrySelection.toggle()
            resource.removeObservers(ownedBy: store)
        }) {
            #if os(iOS)
                Label("Switch country...", systemImage: "flag")
            #else
                Text("\(country.flag) \(country.id)")

            #endif
        }
    }

    private func updateFavoriteItem() {
        favoriteItem = FavoriteItem(section: .trending(country.rawValue, category.rawValue))
    }
}

struct TrendingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrendingView(Video.allFixtures)
        }
    }
}
