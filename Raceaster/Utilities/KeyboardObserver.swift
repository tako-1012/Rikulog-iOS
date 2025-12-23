import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var keyboardFrame: CGRect = .zero
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo }
            .map { info -> (CGFloat, CGRect) in
                if let rect = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    return (rect.height, rect)
                }
                return (0, .zero)
            }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in (CGFloat(0), CGRect.zero) }

        willShow.merge(with: willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] pair in
                self?.keyboardHeight = pair.0
                self?.keyboardFrame = pair.1
            }
            .store(in: &cancellables)
    }
}
