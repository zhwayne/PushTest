import SwiftUI

struct ContentView: View {
    @Bindable var state: PushToolState

    var body: some View {
        NavigationSplitView {
            List(selection: selectedTabSelection) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
            .navigationTitle("PushTest")
        } detail: {
            switch state.selectedTab {
            case .send:
                SendPushView(state: state)
            case .history:
                HistoryView(state: state)
            }
        }
        .frame(minWidth: 780, minHeight: 700)
    }

    private var selectedTabSelection: Binding<AppTab?> {
        Binding(
            get: { state.selectedTab },
            set: { newValue in
                guard let newValue else { return }
                state.selectedTab = newValue
            }
        )
    }
}

#Preview {
    ContentView(state: PushToolState())
}
