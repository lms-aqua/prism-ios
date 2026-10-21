import SwiftUI
import AVKit

// The native client owns its own cookie session. Browser cookies are never embedded.
private struct PrismUser: Decodable { let id: Int; let name: String }
private struct AuthReply: Decodable { let user: PrismUser; let csrfToken: String? }
private struct MediaProgress: Decodable { let position: Double; let duration: Double? }
private struct EpisodeInfo: Decodable {
    let showTitle: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
}
private struct MediaTitle: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let year: Int?
    let overview: String?
    let posterUrl: String?
    let backdropUrl: String?
    let duration: Double?
    let kind: String?
    let episode: EpisodeInfo?
    let progress: MediaProgress?
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
private struct MediaPage: Decodable { let items: [MediaTitle]; let total: Int? }
private struct SearchReply: Decodable {
    let films: [MediaTitle]
    let shows: [MediaTitle]
    let episodes: [MediaTitle]
}
private struct Season: Decodable, Identifiable { let id: Int; let number: Int; let title: String? }
private struct ShowReply: Decodable { let seasons: [Season]; let nextItem: MediaTitle? }
private struct SeasonReply: Decodable { let episodes: [MediaTitle] }
private struct PlaybackReply: Decodable {
    let id: String
    let state: String
    let mode: String?
    let position: Double?
    let offset: Double?
    let duration: Double?
    let streamUrl: String?
}
private struct ServerProblem: Decodable { let message: String? }
private struct PrismFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class PrismRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard request.url?.scheme == "https",
              request.url?.host == "prism.codystechcorner.com" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
@MainActor
private final class PrismAPI: ObservableObject {
    static let origin = URL(string: "https://prism.codystechcorner.com")!
    @Published var user: PrismUser?
    @Published var checkingSession = true
    private var csrfToken: String?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: PrismRedirectPolicy(), delegateQueue: nil)
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func url(_ path: String) -> URL? {
        guard let url = URL(string: path, relativeTo: origin)?.absoluteURL,
              url.scheme == "https", url.host == origin.host else { return nil }
        return url
    }

    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let url = Self.url(path) else { throw PrismFailure(message: "Prism returned an invalid address.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            request.setValue(Self.origin.absoluteString, forHTTPHeaderField: "Origin")
            if let csrfToken { request.setValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token") }
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PrismFailure(message: "No response from Prism.") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { user = nil; csrfToken = nil }
            let problem = try? decoder.decode(ServerProblem.self, from: data)
            throw PrismFailure(message: problem?.message ?? "Prism could not complete this request (\(http.statusCode)).")
        }
        return data
    }
    func get<T: Decodable>(_ path: String) async throws -> T {
        try decoder.decode(T.self, from: await request(path))
    }
    func playback(_ path: String, method: String, body: [String: Any]) async throws -> PlaybackReply {
        try decoder.decode(PlaybackReply.self, from: await request(path, method: method, body: body))
    }
    func restoreSession() async {
        defer { checkingSession = false }
        guard let reply: AuthReply = try? await get("/api/auth/me") else { return }
        csrfToken = reply.csrfToken
        user = reply.user
    }
    func login(name: String, password: String, code: String) async throws {
        var payload: [String: Any] = ["name": name, "password": password]
        if !code.isEmpty { payload["code"] = code }
        _ = try await request("/api/auth/login", method: "POST", body: payload)
        let reply: AuthReply = try await get("/api/auth/me")
        csrfToken = reply.csrfToken
        user = reply.user
    }
    func logout() async throws {
        _ = try await request("/api/auth/logout", method: "POST")
        user = nil
        csrfToken = nil
        for cookie in HTTPCookieStorage.shared.cookies(for: Self.origin) ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

struct PrismView: View {
    @StateObject private var api = PrismAPI()
    var body: some View {
        Group {
            if api.checkingSession {
                ProgressView("Opening Prism…")
            } else if api.user != nil {
                PrismTabs(api: api)
            } else {
                PrismLogin(api: api)
            }
        }
        .tint(.indigo)
        .task { await api.restoreSession() }
    }
}

private struct PrismLogin: View {
    @ObservedObject var api: PrismAPI
    @State private var name = ""
    @State private var password = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 52)).foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your movies.\nOne place.").font(.largeTitle.bold())
                        Text("Sign in to Prism to pick up where you left off.").foregroundStyle(.secondary)
                    }
                    VStack(spacing: 16) {
                        TextField("Username", text: $name)
                            .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(.password)
                        TextField("Two-factor code (if enabled)", text: $code)
                            .textContentType(.oneTimeCode).keyboardType(.numberPad)
                    }
                    .textFieldStyle(.roundedBorder)
                    if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("loginError") }
                    Button {
                        busy = true; error = nil
                        Task {
                            defer { busy = false }
                            do {
                                try await api.login(name: name.trimmingCharacters(in: .whitespacesAndNewlines), password: password, code: code)
                                password = ""; code = ""
                            } catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() }; Text("Sign in").bold(); Spacer() }
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || name.isEmpty || password.isEmpty)
                }
                .padding(28).frame(maxWidth: 480).frame(maxWidth: .infinity).padding(.top, 50)
            }
            .navigationTitle("Prism").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PrismTabs: View {
    @ObservedObject var api: PrismAPI
    var body: some View {
        TabView {
            LibraryScreen(api: api, title: "Watch now", path: "/api/library/recent", home: true)
                .tabItem { Label("Home", systemImage: "house") }
            LibraryScreen(api: api, title: "Movies", path: "/api/library/movies", home: false)
                .tabItem { Label("Movies", systemImage: "film") }
            LibraryScreen(api: api, title: "Shows", path: "/api/library/shows", home: false, shows: true)
                .tabItem { Label("Shows", systemImage: "tv") }
            SearchScreen(api: api).tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }
}

private struct TitleCard: View {
    let item: MediaTitle
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: item.posterUrl.flatMap { PrismAPI.url($0) }) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary).overlay { Image(systemName: "film").font(.title).foregroundStyle(.secondary) }
            }
            .frame(height: 210).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            if let year = item.year { Text(String(year)).font(.caption).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryScreen: View {
    @ObservedObject var api: PrismAPI
    let title: String
    let path: String
    let home: Bool
    var shows = false
    @State private var items: [MediaTitle] = []
    @State private var continuing: [MediaTitle] = []
    @State private var busy = false
    @State private var error: String?
    @State private var total = 0
    @State private var accountError: String?
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if home && !continuing.isEmpty {
                        Text("Continue watching").font(.title2.bold())
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(continuing) { item in
                                    NavigationLink { TitleScreen(api: api, item: item) } label: { TitleCard(item: item).frame(width: 150) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        Text("Recently added").font(.title2.bold())
                    }
                    if let error {
                        ContentUnavailableView { Label("Couldn’t load your library", systemImage: "wifi.exclamationmark") }
                        description: { Text(error) }
                        actions: { Button("Try again") { Task { await load(reset: true) } } }
                    }
                    if !busy && items.isEmpty && error == nil {
                        ContentUnavailableView("Nothing here yet", systemImage: "film", description: Text("Your available titles will appear here."))
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(items) { item in
                            NavigationLink { TitleScreen(api: api, item: item, isShow: shows) } label: { TitleCard(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                    if busy { ProgressView().frame(maxWidth: .infinity) }
                    if !home && items.count < total && !busy {
                        Button("Load more") { Task { await load(reset: false) } }.frame(maxWidth: .infinity)
                    }
                }.padding(20)
            }
            .navigationTitle(title)
            .toolbar {
                if home {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Text(api.user?.name ?? "Prism")
                            Button("Sign out", role: .destructive) {
                                Task { do { try await api.logout() } catch { accountError = error.localizedDescription } }
                            }
                        } label: { Image(systemName: "person.crop.circle") }
                    }
                }
            }
            .alert("Couldn’t sign out", isPresented: Binding(get: { accountError != nil }, set: { if !$0 { accountError = nil } })) {
                Button("OK") { accountError = nil }
            } message: { Text(accountError ?? "") }
            .refreshable { await load(reset: true) }
            .task { if items.isEmpty { await load(reset: true) } }
        }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let offset = reset ? 0 : items.count
            let route = home ? path : "\(path)?limit=40&offset=\(offset)"
            let page: MediaPage = try await api.get(route)
            if reset { items = page.items } else {
                let existing = Set(items.map(\.id))
                items += page.items.filter { !existing.contains($0.id) }
            }
            total = page.total ?? items.count
            if home {
                let page: MediaPage = try await api.get("/api/library/continue")
                continuing = page.items
            }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}

private struct SearchScreen: View {
    @ObservedObject var api: PrismAPI
    @State private var query = ""
    @State private var results: SearchReply?
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Find your next watch", systemImage: "magnifyingglass", description: Text("Search movies, shows, and episodes."))
                } else if busy { ProgressView("Searching…") }
                if let error { Text(error).foregroundStyle(.red) }
                if let results {
                    searchSection("Movies", items: results.films, shows: false)
                    searchSection("Shows", items: results.shows, shows: true)
                    searchSection("Episodes", items: results.episodes, shows: false)
                    if results.films.isEmpty && results.shows.isEmpty && results.episodes.isEmpty && !busy {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Movies, shows, episodes")
            .task(id: query) { await search() }
        }
    }
    @ViewBuilder private func searchSection(_ title: String, items: [MediaTitle], shows: Bool) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    NavigationLink { TitleScreen(api: api, item: item, isShow: shows) } label: {
                        VStack(alignment: .leading) {
                            Text(item.title)
                            if let year = item.year { Text(String(year)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
    }
    private func search() async {
        results = nil; error = nil
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { busy = false; return }
        busy = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            var components = URLComponents()
            components.queryItems = [URLQueryItem(name: "q", value: text), URLQueryItem(name: "limit", value: "30")]
            let reply: SearchReply = try await api.get("/api/search?" + (components.percentEncodedQuery ?? ""))
            try Task.checkCancellation()
            results = reply; busy = false
        } catch is CancellationError {} catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription; busy = false
        }
    }
}

private struct TitleScreen: View {
    @ObservedObject var api: PrismAPI
    let item: MediaTitle
    var isShow = false
    @State private var detail: MediaTitle?
    @State private var seasons: [Season] = []
    @State private var seasonNumber: Int?
    @State private var episodes: [MediaTitle] = []
    @State private var nextItem: MediaTitle?
    @State private var busy = true
    @State private var error: String?
    @State private var selected: MediaTitle?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AsyncImage(url: (detail?.backdropUrl ?? item.backdropUrl ?? item.posterUrl).flatMap { PrismAPI.url($0) }) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Rectangle().fill(.quaternary).overlay { Image(systemName: "play.rectangle").font(.largeTitle) } }
                .frame(height: 230).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                Text(item.title).font(.largeTitle.bold())
                if let year = item.year { Text(String(year)).foregroundStyle(.secondary) }
                if busy { ProgressView() }
                if let error {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await load() } }
                }
                if let playable = isShow ? nextItem : detail {
                    Button { selected = playable } label: {
                        Label((playable.progress?.position ?? 0) > 0 ? "Resume" : "Play", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                }
                if let overview = detail?.overview ?? item.overview { Text(overview).foregroundStyle(.secondary) }
                if isShow && !seasons.isEmpty {
                    Picker("Season", selection: $seasonNumber) {
                        ForEach(seasons) { season in Text("Season \(season.number)").tag(Optional(season.number)) }
                    }.pickerStyle(.menu)
                    ForEach(episodes) { episode in
                        Button { selected = episode } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(episode.title).font(.headline)
                                    if let number = episode.episode?.episodeNumber { Text("Episode \(number)").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer(); Image(systemName: "play.circle.fill").font(.title2)
                            }.padding(.vertical, 8)
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: seasonNumber) { await loadEpisodes() }
        .fullScreenCover(item: $selected, onDismiss: { Task { await load() } }) { item in PlaybackScreen(api: api, item: item) }
    }
    private func load() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            if isShow {
                let show: ShowReply = try await api.get("/api/shows/\(item.id)")
                seasons = show.seasons; nextItem = show.nextItem
                if seasonNumber == nil { seasonNumber = seasons.first?.number }
            } else { detail = try await api.get("/api/items/\(item.id)") }
        } catch { self.error = error.localizedDescription }
    }
    private func loadEpisodes() async {
        guard let seasonNumber else { return }
        episodes = []
        do {
            var loaded: [MediaTitle] = []
            var offset = 0
            while true {
                try Task.checkCancellation()
                let page: SeasonReply = try await api.get("/api/shows/\(item.id)/seasons/\(seasonNumber)?limit=200&offset=\(offset)")
                loaded += page.episodes
                if page.episodes.count < 200 { break }
                offset += page.episodes.count
            }
            try Task.checkCancellation()
            episodes = loaded
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

@MainActor
private final class PlaybackModel: ObservableObject {
    let player = AVPlayer()
    @Published var busy = true
    @Published var error: String?
    @Published var duration = 0.0
    @Published var position = 0.0
    private let api: PrismAPI
    private let item: MediaTitle
    private var session: PlaybackReply?
    private var statusObservation: NSKeyValueObservation?
    private var stopped = false
    init(api: PrismAPI, item: MediaTitle) { self.api = api; self.item = item }
    func run() async {
        do {
            // Conservative baseline. The server may optimize incompatible files.
            let created = try await api.playback("/api/playback/sessions", method: "POST", body: [
                "movie_id": item.id, "quality": "original", "position": item.progress?.position ?? 0,
                "capabilities": ["h264": true, "aac": true, "native_hls": true, "hevc": false, "hevc_main10": false, "ac3": false, "eac3": false]
            ])
            session = created
            if stopped || Task.isCancelled {
                _ = try? await api.request("/api/playback/sessions/\(created.id)", method: "DELETE")
                return
            }
            try Task.checkCancellation()
            try await prepare(created)
            while !Task.isCancelled && !stopped {
                try await Task.sleep(for: .seconds(10))
                try Task.checkCancellation()
                try await save()
            }
        } catch {
            if !Task.isCancelled && !stopped { self.error = error.localizedDescription; busy = false; player.pause() }
        }
    }
    private func prepare(_ initial: PlaybackReply) async throws {
        var current = initial
        for _ in 0..<60 {
            if current.state == "ready", current.streamUrl != nil { break }
            if ["failed", "error", "stopped"].contains(current.state) { throw PrismFailure(message: "Prism couldn’t prepare this video.") }
            try await Task.sleep(for: .seconds(1))
            current = try await api.get("/api/playback/sessions/\(current.id)")
            session = current
        }
        guard current.state == "ready", let path = current.streamUrl, let url = PrismAPI.url(path) else {
            throw PrismFailure(message: "The video is taking too long to prepare. Close it and try again.")
        }
        session = current
        duration = current.duration ?? item.duration ?? 0
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        let asset = AVURLAsset(url: url, options: [AVURLAssetHTTPCookiesKey: cookies])
        let playerItem = AVPlayerItem(asset: asset)
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] observed, _ in
            if observed.status == .failed {
                Task { @MainActor [weak self] in self?.error = "Couldn’t play this stream. Close the player and try again."; self?.busy = false }
            }
        }
        player.replaceCurrentItem(with: playerItem)
        // Transcoded HLS starts at the server offset. Direct streams use full-file time.
        if current.mode != "transcode", let position = current.position, position > 0 {
            await player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
        }
        try Task.checkCancellation()
        busy = false
        player.play()
    }
    private func currentPosition() -> Double {
        let time = player.currentTime().seconds
        guard time.isFinite else { return session?.position ?? item.progress?.position ?? 0 }
        return max(0, time + (session?.mode == "transcode" ? (session?.offset ?? 0) : 0))
    }
    private func save() async throws {
        guard let session else { return }
        position = currentPosition()
        _ = try await api.request("/api/playback/sessions/\(session.id)/heartbeat", method: "POST", body: ["position": position, "paused": player.rate == 0])
        if duration > 0 {
            _ = try await api.request("/api/items/\(item.id)/progress", method: "POST", body: ["position": position, "duration": duration, "completed": position >= duration - 5])
        }
    }
    func stop() async {
        guard !stopped else { return }
        stopped = true
        player.pause()
        try? await save()
        if let session { _ = try? await api.request("/api/playback/sessions/\(session.id)", method: "DELETE") }
        statusObservation = nil
        player.replaceCurrentItem(with: nil)
    }
}

private struct PlaybackScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: PlaybackModel
    let item: MediaTitle
    init(api: PrismAPI, item: MediaTitle) {
        self.item = item
        _model = StateObject(wrappedValue: PlaybackModel(api: api, item: item))
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: model.player).ignoresSafeArea(edges: .bottom)
            if model.busy { ProgressView("Preparing your video…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            if let error = model.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle").font(.largeTitle)
                    Text("Couldn’t play this title").font(.title2.bold())
                    Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Close player") { dismiss() }.buttonStyle(.borderedProminent)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
            }
            Button { dismiss() } label: {
                Label("Close", systemImage: "xmark").labelStyle(.iconOnly).font(.headline)
                    .padding(16).background(.ultraThinMaterial, in: Circle())
            }.padding(16).accessibilityLabel("Close player")
        }
        .task { await model.run() }
        .onDisappear { Task { await model.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.player.pause() } }
    }
}
