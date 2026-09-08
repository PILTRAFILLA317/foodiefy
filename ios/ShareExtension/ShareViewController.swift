import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let message = UILabel()
    private let saveButton = UIButton(type: .system)
    private var urls: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        message.numberOfLines = 0
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.text = "Preparando el enlace…"
        saveButton.setTitle("Guardar enlace para Foodiefy", for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.titleLabel?.adjustsFontForContentSizeCategory = true
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cerrar", for: .normal)
        cancel.addTarget(self, action: #selector(close), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [message, saveButton, cancel]); stack.axis = .vertical; stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)])
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }.prefix(10)
        let group = DispatchGroup()
        for provider in providers {
            let type = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : UTType.plainText.identifier
            guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
                let text = (item as? URL)?.absoluteString ?? (item as? String) ?? ""
                DispatchQueue.main.async {
                    self?.urls.append(contentsOf: ShareInbox.urls(in: text)); group.leave()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.urls = Array(NSOrderedSet(array: self.urls).array as? [String] ?? []).prefix(10).map { $0 }
            self.message.text = self.urls.isEmpty ? "No hay un enlace HTTP(S). Abre Foodiefy para pegar la receta." : "Se guardarán \(self.urls.count) enlaces durante 24 horas. Abre Foodiefy después y confirma la importación. No se inicia procesamiento ni gasto aquí."
            self.saveButton.isEnabled = !self.urls.isEmpty
        }
    }
    @objc private func save() {
        do { try ShareInbox.save(urls: urls); close() }
        catch { message.text = "No se pudo guardar. Procesa los enlaces pendientes en Foodiefy o revisa el mismo App Group y firma en ambos targets." }
    }
    @objc private func close() { extensionContext?.completeRequest(returningItems: nil) }
}
