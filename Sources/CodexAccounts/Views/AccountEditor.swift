import SwiftUI

struct AccountEditor: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Account
    @State private var validationMessage: String?
    @FocusState private var nameFocused: Bool
    private let isEditing: Bool

    init(account: Account?) {
        isEditing = account != nil
        _draft = State(initialValue: account ?? Account(name: ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AccountAvatar(account: draft, size: 36)
                Text(L10n.string(isEditing ? "editAccount" : "addAccount"))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 5)
            Form {
                Section {
                    TextField(L10n.string("name"), text: $draft.name).focused($nameFocused)
                        .accessibilityLabel(L10n.string("name"))
                    TextField(L10n.string("note"), text: $draft.note, prompt: Text(L10n.string("optional")))
                        .accessibilityLabel(L10n.string("note"))
                }
                Section {
                    HStack {
                        Text(L10n.string("icon"))
                        Spacer()
                        HStack(spacing: 5) {
                            ForEach(Account.symbols, id: \.self) { symbol in
                                Button { draft.symbol = symbol } label: {
                                    Image(systemName: symbol).font(.system(size: 15))
                                        .frame(width: 30, height: 28)
                                        .background(draft.symbol == symbol ? Color.accentColor.opacity(0.12) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 5))
                                        .foregroundStyle(draft.symbol == symbol ? Color.accentColor : .secondary)
                                }.buttonStyle(.plain).accessibilityLabel(L10n.string("symbol." + symbol))
                            }
                        }
                    }.accessibilityElement(children: .contain)
                    HStack {
                        Text(L10n.string("color"))
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(AccountTint.allCases) { tint in
                                Button { draft.tint = tint } label: {
                                    Circle().fill(tint.foreground.opacity(0.8)).frame(width: 16, height: 16)
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(draft.tint == tint ? Color.primary.opacity(0.5) : .clear).frame(width: 22, height: 22))
                                }.buttonStyle(.plain).accessibilityLabel(tint.title)
                            }
                        }
                    }.accessibilityElement(children: .contain)
                    Toggle(L10n.string("favorite"), isOn: $draft.isFavorite)
                }
            }.formStyle(.grouped).textFieldStyle(.roundedBorder).frame(height: 268)
            if !isEditing {
                Text(L10n.string("account.loginHint"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 14)
            }
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(.red).padding(.horizontal, 24).padding(.bottom, 10)
            }
            HStack {
                Spacer()
                Button(L10n.string("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.string(isEditing ? "save" : "addAccount.login")) {
                    if store.save(draft) { dismiss() }
                    else { validationMessage = store.errorMessage; store.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }.frame(width: 440).fixedSize(horizontal: false, vertical: true)
            .background(Theme.canvas).onAppear { nameFocused = true }
    }
}
