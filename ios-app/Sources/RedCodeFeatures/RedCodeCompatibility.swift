import SwiftUI

/// iOS 15 兼容容器：iOS 16+ 使用 NavigationStack，低版本回退 NavigationView。
public struct AppNavigationContainer<Content: View>: View {
    @ViewBuilder let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
        }
    }
}

/// 替代 iOS 17+ ContentUnavailableView 的空状态展示。
struct RedCodeEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let description {
                description
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// iOS 16+ LabeledContent 的 iOS 15 兼容行。
struct RedCodeLabeledValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

extension View {
    /// iOS 15 可用的昵称自动填充类型（macOS 13 无此类型，跳过）。
    @ViewBuilder
    func redcodeTextContentTypeNickname() -> some View {
        #if os(iOS)
        textContentType(.nickname)
        #else
        self
        #endif
    }

    /// iOS 15 可用的新密码自动填充类型（macOS 13 无此类型，跳过）。
    @ViewBuilder
    func redcodeTextContentTypeNewPassword() -> some View {
        #if os(iOS)
        textContentType(.newPassword)
        #else
        self
        #endif
    }

    /// iOS 16+ navigationDestination(isPresented:) 的 iOS 15 回退实现。
    @ViewBuilder
    func redcodeNavigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            navigationDestination(isPresented: isPresented, destination: destination)
        } else {
            background(
                NavigationLink(isActive: isPresented, destination: destination) {
                    EmptyView()
                }
                .hidden()
            )
        }
        #else
        background(
            NavigationLink(isActive: isPresented, destination: destination) {
                EmptyView()
            }
            .hidden()
        )
        #endif
    }

    /// iOS 16+ navigationDestination(item:) 的 iOS 15 回退实现。
    @ViewBuilder
    func redcodeNavigationDestination<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            navigationDestination(item: item, destination: destination)
        } else {
            let isActive = Binding(
                get: { item.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        item.wrappedValue = nil
                    }
                }
            )
            background(
                NavigationLink(
                    isActive: isActive,
                    destination: {
                        if let wrappedValue = item.wrappedValue {
                            destination(wrappedValue)
                        }
                    }
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        #else
        let isActive = Binding(
            get: { item.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    item.wrappedValue = nil
                }
            }
        )
        background(
            NavigationLink(
                isActive: isActive,
                destination: {
                    if let wrappedValue = item.wrappedValue {
                        destination(wrappedValue)
                    }
                }
            ) {
                EmptyView()
            }
            .hidden()
        )
        #endif
    }

    /// iOS 16+ scrollContentBackground(.hidden) 的 iOS 15 回退实现。
    @ViewBuilder
    func redcodeScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }

}
