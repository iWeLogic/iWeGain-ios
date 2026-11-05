import SwiftUI

extension View {
    /// Handles [viewModel]'s events while this view is on screen; events sent meanwhile wait for it.
    func onEvents<S, A, E>(of viewModel: BaseViewModel<S, A, E>, perform: @escaping (E) -> Void) -> some View {
        onAppear { viewModel.subscribe(perform) }
            .onDisappear { viewModel.unsubscribe() }
    }
}
