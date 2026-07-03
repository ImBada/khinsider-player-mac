import AppKit
import SwiftUI

internal struct MiniPlayerView: View {
    @EnvironmentObject private var appState: AppState

    private let onAlbumArtworkPressed: (AlbumDetail) -> Void

    internal init(onAlbumArtworkPressed: @escaping (AlbumDetail) -> Void = { _ in }) {
        self.onAlbumArtworkPressed = onAlbumArtworkPressed
    }

    internal var body: some View {
        MiniPlayerEngineView(
            appState: appState,
            engine: appState.playbackEngine,
            onAlbumArtworkPressed: onAlbumArtworkPressed
        )
            .id(ObjectIdentifier(appState.playbackEngine))
    }
}

@MainActor
internal enum MiniPlayerEngineGuard {
    internal static func isCurrent(_ engine: PlaybackEngine, in appState: AppState) -> Bool {
        appState.playbackEngine === engine
    }

    internal static func currentEngine(
        matching engine: PlaybackEngine,
        in appState: AppState
    ) -> PlaybackEngine? {
        guard isCurrent(engine, in: appState) else {
            return nil
        }

        return appState.playbackEngine
    }
}

private struct MiniPlayerEngineView: View {
    private let appState: AppState
    private let onAlbumArtworkPressed: (AlbumDetail) -> Void

    @ObservedObject private var engine: PlaybackEngine

    private var _playbackErrorMessage = State<String?>(initialValue: nil)
    private var _favoriteErrorMessage = State<String?>(initialValue: nil)
    private var _isVolumeControlPresented = State<Bool>(initialValue: false)
    private var _isCurrentTrackFavorite = State<Bool>(initialValue: false)

    init(
        appState: AppState,
        engine: PlaybackEngine,
        onAlbumArtworkPressed: @escaping (AlbumDetail) -> Void
    ) {
        self.appState = appState
        self.engine = engine
        self.onAlbumArtworkPressed = onAlbumArtworkPressed
    }

    var body: some View {
        HStack(spacing: 10) {
            MiniPlayerTransportControls(
                isPlaying: engine.isPlaying,
                hasCurrentItem: currentItem != nil,
                isShuffleEnabled: engine.isShuffleEnabled,
                repeatMode: engine.repeatMode,
                onPlayPause: {
                    engine.togglePlayPause()
                },
                onToggleShuffle: {
                    engine.isShuffleEnabled.toggle()
                },
                onNext: advanceToNextTrack,
                onCycleRepeat: cycleRepeatMode
            )

            MiniPlayerArtworkView(
                url: currentItem?.album.artworkURL,
                isEnabled: currentItem != nil,
                onPressed: showCurrentAlbum
            )

            MiniPlayerTrackInfo(
                trackTitle: trackTitle,
                albumTitle: albumTitle,
                isTrackFavorite: isCurrentTrackFavorite,
                isFavoriteEnabled: currentItem != nil,
                elapsedTime: engine.elapsedTime,
                duration: engine.duration,
                onToggleFavorite: toggleCurrentTrackFavorite,
                onSeek: { progress in
                    engine.seek(to: progress * engine.duration)
                }
            )

            MiniPlayerVolumeControl(
                volume: volumeBinding,
                isPresented: isVolumeControlPresentedBinding
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 640, minHeight: 50)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AdaptiveSystemColors.separator, lineWidth: 1)
        }
        .shadow(color: AdaptiveSystemColors.shadow.opacity(0.28), radius: 20, x: 0, y: 10)
        .onHover { isHovered in
            if !isHovered {
                isVolumeControlPresented = false
            }
        }
        .onAppear(perform: refreshCurrentTrackFavorite)
        .onChange(of: currentItem?.track.id) { _, _ in
            refreshCurrentTrackFavorite()
        }
        .onReceive(appState.libraryStore.favoriteTrackChanges) { change in
            applyFavoriteTrackChange(change)
        }
        .alert(
            "Playback Failed",
            isPresented: isPlaybackErrorPresented
        ) {
            Button("OK", role: .cancel) {
                playbackErrorMessage = nil
            }
        } message: {
            Text(playbackErrorMessage ?? "Playback could not advance.")
        }
        .alert(
            "Favorite Update Failed",
            isPresented: isFavoriteErrorPresented
        ) {
            Button("OK", role: .cancel) {
                favoriteErrorMessage = nil
            }
        } message: {
            Text(favoriteErrorMessage ?? "Favorite could not be updated.")
        }
    }

    private var currentItem: PlaybackItem? {
        engine.currentItem
    }

    private var trackTitle: String {
        currentItem?.track.title ?? "Not Playing"
    }

    private var albumTitle: String? {
        currentItem?.album.title
    }

    private var playbackErrorMessage: String? {
        get {
            _playbackErrorMessage.wrappedValue
        }
        nonmutating set {
            _playbackErrorMessage.wrappedValue = newValue
        }
    }

    private var favoriteErrorMessage: String? {
        get {
            _favoriteErrorMessage.wrappedValue
        }
        nonmutating set {
            _favoriteErrorMessage.wrappedValue = newValue
        }
    }

    private var isPlaybackErrorPresented: Binding<Bool> {
        Binding {
            playbackErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                playbackErrorMessage = nil
            }
        }
    }

    private var isFavoriteErrorPresented: Binding<Bool> {
        Binding {
            favoriteErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                favoriteErrorMessage = nil
            }
        }
    }

    private var isCurrentTrackFavorite: Bool {
        get {
            _isCurrentTrackFavorite.wrappedValue
        }
        nonmutating set {
            _isCurrentTrackFavorite.wrappedValue = newValue
        }
    }

    private var isVolumeControlPresented: Bool {
        get {
            _isVolumeControlPresented.wrappedValue
        }
        nonmutating set {
            _isVolumeControlPresented.wrappedValue = newValue
        }
    }

    private var isVolumeControlPresentedBinding: Binding<Bool> {
        Binding {
            isVolumeControlPresented
        } set: { isPresented in
            isVolumeControlPresented = isPresented
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(engine.volume)
        } set: { volume in
            engine.volume = Float(volume)
        }
    }

    private func cycleRepeatMode() {
        switch engine.repeatMode {
        case .off:
            engine.repeatMode = .all
        case .all:
            engine.repeatMode = .one
        case .one:
            engine.repeatMode = .off
        }
    }

    private func advanceToNextTrack() {
        playbackErrorMessage = nil
        let tappedEngine = engine

        Task { @MainActor [appState, tappedEngine] in
            guard let currentEngine = MiniPlayerEngineGuard.currentEngine(
                matching: tappedEngine,
                in: appState
            ) else {
                return
            }

            do {
                try await currentEngine.next()
            } catch is CancellationError {
                // A newer playback request superseded this control action.
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }

    private func showCurrentAlbum() {
        guard let album = currentItem?.album else {
            return
        }

        onAlbumArtworkPressed(album)
    }

    private func refreshCurrentTrackFavorite() {
        guard let item = currentItem else {
            isCurrentTrackFavorite = false
            return
        }

        do {
            isCurrentTrackFavorite = try appState.libraryStore.isTrackFavorite(trackID: item.track.id)
            favoriteErrorMessage = nil
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }

    private func applyFavoriteTrackChange(_ change: FavoriteTrackFavoriteChange) {
        guard currentItem?.track.id == change.trackID else {
            return
        }

        isCurrentTrackFavorite = change.isFavorite
    }

    private func toggleCurrentTrackFavorite() {
        guard let item = currentItem else {
            return
        }

        do {
            let nextValue = !isCurrentTrackFavorite
            try appState.libraryStore.setTrackFavorite(
                album: item.album,
                track: item.track,
                isFavorite: nextValue
            )
            isCurrentTrackFavorite = nextValue
            favoriteErrorMessage = nil
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }
}

private struct MiniPlayerArtworkView: View {
    let url: URL?
    let isEnabled: Bool
    let onPressed: () -> Void

    var body: some View {
        Button(action: onPressed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: MiniPlayerLayout.artworkSize, height: MiniPlayerLayout.artworkSize)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Show current album")
        .help("Show Current Album")
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MiniPlayerTrackInfo: View {
    let trackTitle: String
    let albumTitle: String?
    let isTrackFavorite: Bool
    let isFavoriteEnabled: Bool
    let elapsedTime: TimeInterval
    let duration: TimeInterval
    let onToggleFavorite: () -> Void
    let onSeek: (Double) -> Void

    @Namespace private var playbackFaderAnimation
    private var _isPlaybackFaderHovered = State<Bool>(initialValue: false)
    private var _isTrackInfoHovered = State<Bool>(initialValue: false)

    fileprivate init(
        trackTitle: String,
        albumTitle: String?,
        isTrackFavorite: Bool,
        isFavoriteEnabled: Bool,
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        onToggleFavorite: @escaping () -> Void,
        onSeek: @escaping (Double) -> Void
    ) {
        self.trackTitle = trackTitle
        self.albumTitle = albumTitle
        self.isTrackFavorite = isTrackFavorite
        self.isFavoriteEnabled = isFavoriteEnabled
        self.elapsedTime = elapsedTime
        self.duration = duration
        self.onToggleFavorite = onToggleFavorite
        self.onSeek = onSeek
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if isPlaybackFaderHovered {
                expandedPlaybackTimeline
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            } else {
                compactPlaybackTimeline
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: MiniPlayerLayout.trackInfoHeight, alignment: .bottomLeading)
        .contentShape(Rectangle())
        .onHover { isHovered in
            isTrackInfoHovered = isHovered
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: MiniPlayerLayout.favoriteTitleSpacing) {
                Text(trackTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                MiniPlayerFavoriteButton(
                    title: trackTitle,
                    isFavorite: isTrackFavorite,
                    isVisible: isTrackInfoHovered,
                    isEnabled: isFavoriteEnabled,
                    onToggleFavorite: onToggleFavorite
                )
            }

            Text(albumTitle ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityHidden(albumTitle == nil)
        }
    }

    private var compactPlaybackTimeline: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleBlock

            MiniPlayerPlaybackFader(
                progress: playbackProgress,
                isHovered: false,
                namespace: playbackFaderAnimation,
                onSeek: onSeek
            )
            .onHover { isHovered in
                onHoverChanged(isHovered)
            }
        }
    }

    private var expandedPlaybackTimeline: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
                Text(TrackFormatting.durationLabel(elapsedTime))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Spacer(minLength: 10)

                Text(TrackFormatting.durationLabel(duration))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            MiniPlayerPlaybackFader(
                progress: playbackProgress,
                isHovered: true,
                namespace: playbackFaderAnimation,
                onSeek: onSeek
            )
        }
        .onHover { isHovered in
            onHoverChanged(isHovered)
        }
    }

    private var playbackProgress: Double {
        guard duration > 0 else {
            return 0
        }

        return min(max(elapsedTime / duration, 0), 1)
    }

    private func onHoverChanged(_ isHovered: Bool) {
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 34)) {
            isPlaybackFaderHovered = isHovered
        }
    }

    private var isPlaybackFaderHovered: Bool {
        get {
            _isPlaybackFaderHovered.wrappedValue
        }
        nonmutating set {
            _isPlaybackFaderHovered.wrappedValue = newValue
        }
    }

    private var isTrackInfoHovered: Bool {
        get {
            _isTrackInfoHovered.wrappedValue
        }
        nonmutating set {
            _isTrackInfoHovered.wrappedValue = newValue
        }
    }
}

private struct MiniPlayerFavoriteButton: View {
    let title: String
    let isFavorite: Bool
    let isVisible: Bool
    let isEnabled: Bool
    let onToggleFavorite: () -> Void

    private var _isButtonHovered = State<Bool>(initialValue: false)

    init(
        title: String,
        isFavorite: Bool,
        isVisible: Bool,
        isEnabled: Bool,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.title = title
        self.isFavorite = isFavorite
        self.isVisible = isVisible
        self.isEnabled = isEnabled
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isButtonHovered ? Color.primary : Color(nsColor: .disabledControlTextColor))
                .frame(width: MiniPlayerLayout.favoriteButtonSize, height: MiniPlayerLayout.favoriteButtonSize)
                .opacity(isVisible && isEnabled ? 1 : 0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .contentShape(Rectangle())
        .onHover { isHovered in
            isButtonHovered = isHovered
        }
        .help(isFavorite ? "Remove Song from Favorites" : "Add Song to Favorites")
        .accessibilityLabel(isFavorite ? "Remove \(title) from favorites" : "Add \(title) to favorites")
    }

    private var isButtonHovered: Bool {
        get {
            _isButtonHovered.wrappedValue
        }
        nonmutating set {
            _isButtonHovered.wrappedValue = newValue
        }
    }
}

private struct MiniPlayerPlaybackFader: View {
    let progress: Double
    let isHovered: Bool
    let namespace: Namespace.ID
    let onSeek: (Double) -> Void

    var body: some View {
        MiniPlayerCapsuleFader(
            progress: progress,
            height: isHovered ? MiniPlayerLayout.playbackExpandedFaderHeight : MiniPlayerLayout.playbackCompactFaderHeight,
            onChange: onSeek,
            accessibilityLabel: "Playback position",
            accessibilityValue: "\(Int(progress * 100)) percent"
        )
        .matchedGeometryEffect(id: "playback-fader", in: namespace)
        .frame(height: isHovered ? MiniPlayerLayout.playbackExpandedFaderHeight : MiniPlayerLayout.playbackCompactFaderHeight)
    }
}

private struct MiniPlayerVolumeControl: View {
    @Binding var volume: Double
    @Binding var isPresented: Bool

    private var _volumeBeforeMute = State<Double>(initialValue: 1)

    fileprivate init(volume: Binding<Double>, isPresented: Binding<Bool>) {
        self._volume = volume
        self._isPresented = isPresented
    }

    var body: some View {
        Group {
            if isPresented {
                expandedControl
            } else {
                volumeButton
            }
        }
        .animation(.easeOut(duration: 0.16), value: isPresented)
        .onChange(of: volume) { _, newVolume in
            rememberVolumeBeforeMute(newVolume)
        }
    }

    private var expandedControl: some View {
        HStack(spacing: 8) {
            MiniPlayerVolumeFader(volume: volumeBinding)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))

            volumeButton
        }
        .padding(.horizontal, MiniPlayerLayout.volumeControlHorizontalPadding)
        .padding(.vertical, MiniPlayerLayout.volumeControlVerticalPadding)
        .frame(
            minWidth: MiniPlayerLayout.volumeControlMinWidth,
            minHeight: MiniPlayerLayout.volumeControlHeight
        )
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AdaptiveSystemColors.separator, lineWidth: 1)
        }
    }

    private var volumeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                toggleMute()
                isVolumeControlPresented = true
            }
        } label: {
            volumeIcon
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                withAnimation(.easeOut(duration: 0.16)) {
                    isVolumeControlPresented = true
                }
            }
        }
        .accessibilityLabel(volume == 0 ? "Unmute" : "Mute")
        .help(volume == 0 ? "Unmute" : "Mute")
    }

    private var volumeIcon: some View {
        Image(systemName: volumeSystemImage)
            .font(.system(size: 17, weight: .semibold))
            .symbolRenderingMode(volumeSymbolRenderingMode)
            .frame(
                width: MiniPlayerLayout.volumeButtonSize,
                height: MiniPlayerLayout.volumeButtonSize
            )
            .foregroundStyle(.primary)
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            volume
        } set: { newVolume in
            let clampedVolume = min(max(newVolume, 0), 1)
            volume = clampedVolume
            rememberVolumeBeforeMute(clampedVolume)
        }
    }

    private var isVolumeControlPresented: Bool {
        get {
            isPresented
        }
        nonmutating set {
            isPresented = newValue
        }
    }

    private var volumeBeforeMute: Double {
        get {
            _volumeBeforeMute.wrappedValue
        }
        nonmutating set {
            _volumeBeforeMute.wrappedValue = newValue
        }
    }

    private var volumeSystemImage: String {
        switch volume {
        case 0:
            "speaker.slash.fill"
        case ..<0.35:
            "speaker.wave.1.fill"
        case ..<0.75:
            "speaker.wave.2.fill"
        default:
            "speaker.wave.3.fill"
        }
    }

    private var volumeSymbolRenderingMode: SymbolRenderingMode {
        volume == 0 ? .hierarchical : .monochrome
    }

    private func toggleMute() {
        if volume == 0 {
            volume = volumeBeforeMute > 0 ? volumeBeforeMute : 1
        } else {
            volumeBeforeMute = volume
            volume = 0
        }
    }

    private func rememberVolumeBeforeMute(_ newVolume: Double) {
        if newVolume > 0 {
            volumeBeforeMute = newVolume
        }
    }
}

private struct MiniPlayerVolumeFader: View {
    @Binding var volume: Double

    var body: some View {
        MiniPlayerCapsuleFader(
            progress: volume,
            height: MiniPlayerLayout.volumeFaderHeight,
            onChange: { volume = $0 },
            accessibilityLabel: "Volume",
            accessibilityValue: "\(Int(volume * 100)) percent"
        )
        .frame(
            width: MiniPlayerLayout.volumeSliderWidth,
            height: MiniPlayerLayout.volumeFaderHeight
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                volume = min(volume + 0.05, 1)
            case .decrement:
                volume = max(volume - 0.05, 0)
            @unknown default:
                break
            }
        }
    }
}

private struct MiniPlayerCapsuleFader: View {
    let progress: Double
    let height: CGFloat
    let onChange: (Double) -> Void
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AdaptiveSystemColors.separator)

                Capsule(style: .continuous)
                    .fill(AdaptiveSystemColors.label)
                    .frame(width: fillWidth(in: geometry.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateProgress(at: value.location.x, width: geometry.size.width)
                    }
            )
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private func fillWidth(in width: CGFloat) -> CGFloat {
        width * min(max(progress, 0), 1)
    }

    private func updateProgress(at x: CGFloat, width: CGFloat) {
        guard width > 0 else {
            return
        }

        onChange(min(max(x / width, 0), 1))
    }
}

private struct MiniPlayerTransportControls: View {
    let isPlaying: Bool
    let hasCurrentItem: Bool
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let onPlayPause: () -> Void
    let onToggleShuffle: () -> Void
    let onNext: () -> Void
    let onCycleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            shuffleButton
            previousButton
            playPauseButton
            nextButton
            repeatButton
        }
        .padding(.horizontal, 12)
        .frame(height: MiniPlayerLayout.transportControlHeight)
        .fixedSize()
    }

    private var shuffleButton: some View {
        Button(action: onToggleShuffle) {
            transportIcon("shuffle", size: MiniPlayerLayout.secondaryButtonIconSize)
                .foregroundStyle(isShuffleEnabled ? Color.accentColor : Color(nsColor: .disabledControlTextColor))
                .opacity(isShuffleEnabled ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShuffleEnabled ? "Turn shuffle off" : "Turn shuffle on")
        .help(isShuffleEnabled ? "Shuffle On" : "Shuffle Off")
    }

    private var previousButton: some View {
        Button {} label: {
            transportIcon("backward.fill", size: MiniPlayerLayout.primaryButtonIconSize)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.8)
        .accessibilityLabel("Previous track unavailable")
        .help("Previous track is unavailable")
    }

    private var playPauseButton: some View {
        Button(action: onPlayPause) {
            transportIcon(
                isPlaying ? "pause.fill" : "play.fill",
                size: MiniPlayerLayout.playButtonIconSize
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasCurrentItem)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
        .help(isPlaying ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button(action: onNext) {
            transportIcon("forward.fill", size: MiniPlayerLayout.primaryButtonIconSize)
        }
        .buttonStyle(.plain)
        .disabled(!hasCurrentItem)
        .opacity(hasCurrentItem ? 1 : 0.8)
        .accessibilityLabel("Next track")
        .help("Next Track")
    }

    private var repeatButton: some View {
        Button(action: onCycleRepeat) {
            transportIcon(repeatSystemImage, size: MiniPlayerLayout.secondaryButtonIconSize)
                .foregroundStyle(repeatForegroundColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(repeatAccessibilityLabel)
        .help(repeatHelp)
    }

    private func transportIcon(_ systemName: String, size: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(
                width: MiniPlayerLayout.transportButtonSize,
                height: MiniPlayerLayout.transportButtonSize
            )
            .contentShape(Rectangle())
    }

    private var repeatForegroundColor: Color {
        repeatMode == .off ? Color(nsColor: .disabledControlTextColor) : Color.accentColor
    }

    private var repeatSystemImage: String {
        switch repeatMode {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }

    private var repeatAccessibilityLabel: String {
        switch repeatMode {
        case .off:
            "Turn repeat all on"
        case .all:
            "Turn repeat one on"
        case .one:
            "Turn repeat off"
        }
    }

    private var repeatHelp: String {
        switch repeatMode {
        case .off:
            "Repeat Off"
        case .all:
            "Repeat All"
        case .one:
            "Repeat One"
        }
    }
}

private enum MiniPlayerLayout {
    static let transportControlHeight: CGFloat = 38
    static let transportButtonSize: CGFloat = 26
    static let primaryButtonIconSize: CGFloat = 17
    static let playButtonIconSize: CGFloat = 24
    static let secondaryButtonIconSize: CGFloat = 15
    static let artworkSize: CGFloat = 34
    static let trackInfoHeight: CGFloat = 39
    static let favoriteTitleSpacing: CGFloat = 4
    static let favoriteButtonSize: CGFloat = 18
    static let playbackCompactFaderHeight: CGFloat = 3
    static let playbackExpandedFaderHeight: CGFloat = 10
    static let playbackTimeLabelWidth: CGFloat = 38
    static let volumeButtonSize: CGFloat = 26
    static let volumeSliderWidth: CGFloat = 86
    static let volumeFaderHeight: CGFloat = 10
    static let volumeControlHorizontalPadding: CGFloat = 12
    static let volumeControlVerticalPadding: CGFloat = 6
    static let volumeControlHeight: CGFloat = 38
    static let volumeControlMinWidth: CGFloat = volumeButtonSize + volumeControlHorizontalPadding * 2
}
