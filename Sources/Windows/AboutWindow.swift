import Cocoa

class AboutWindow: NSWindowController {
    
    override init(window: NSWindow?) {
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "About \(AppInfo.name)"
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        
        // Stack view for vertical layout
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.distribution = .fill
        stackView.spacing = 20
        stackView.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // App Icon (using emoji)
        let iconLabel = NSTextField(labelWithString: "📱")
        iconLabel.font = NSFont.systemFont(ofSize: 72)
        iconLabel.alignment = .center
        iconLabel.isEditable = false
        iconLabel.isBordered = false
        iconLabel.backgroundColor = .clear
        stackView.addArrangedSubview(iconLabel)
        
        // App Name
        let nameLabel = NSTextField(labelWithString: AppInfo.name)
        nameLabel.font = NSFont.boldSystemFont(ofSize: 28)
        nameLabel.alignment = .center
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        stackView.addArrangedSubview(nameLabel)
        
        // Version
        let versionLabel = NSTextField(labelWithString: "Version \(AppInfo.fullVersion)")
        versionLabel.font = NSFont.systemFont(ofSize: 14)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.isEditable = false
        versionLabel.isBordered = false
        versionLabel.backgroundColor = .clear
        stackView.addArrangedSubview(versionLabel)
        
        // Add spacing
        stackView.addArrangedSubview(NSView())
        
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: AppInfo.description)
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.alignment = .center
        descLabel.isEditable = false
        descLabel.isBordered = false
        descLabel.backgroundColor = .clear
        descLabel.maximumNumberOfLines = 0
        stackView.addArrangedSubview(descLabel)
        
        // GitHub Button
        let githubButton = NSButton(title: "View on GitHub", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        stackView.addArrangedSubview(githubButton)
        
        // Add flexible space
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
        
        // Copyright at bottom
        let copyrightLabel = NSTextField(labelWithString: AppInfo.copyright)
        copyrightLabel.font = NSFont.systemFont(ofSize: 11)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.isEditable = false
        copyrightLabel.isBordered = false
        copyrightLabel.backgroundColor = .clear
        stackView.addArrangedSubview(copyrightLabel)
        
        // Stack view constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        window?.contentView = contentView
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: AppInfo.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }
}