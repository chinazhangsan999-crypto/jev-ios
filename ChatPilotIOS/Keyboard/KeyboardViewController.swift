import UIKit

final class KeyboardViewController: UIInputViewController {
  private let statusLabel = UILabel()
  private let summaryLabel = UILabel()
  private let stack = UIStackView()
  private var timer: Timer?
  private var connectedSession: String?
  private var renderedContextID = ""

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    statusLabel.font = .preferredFont(forTextStyle: .caption1)
    statusLabel.numberOfLines = 2
    statusLabel.adjustsFontForContentSizeCategory = true
    statusLabel.accessibilityLabel = "ChatPilot 状态"
    summaryLabel.font = .preferredFont(forTextStyle: .caption2)
    summaryLabel.numberOfLines = 2
    summaryLabel.adjustsFontForContentSizeCategory = true
    summaryLabel.textColor = .secondaryLabel
    stack.axis = .vertical
    stack.spacing = 6
    let connect = UIButton(type: .system)
    connect.setTitle("连接当前会话", for: .normal)
    connect.setImage(UIImage(systemName: "link"), for: .normal)
    connect.addTarget(self, action: #selector(connectSession), for: .touchUpInside)
    connect.accessibilityHint = "切换联系人或聊天应用后需要重新连接"
    let next = UIButton(type: .system)
    next.setImage(UIImage(systemName: "globe"), for: .normal)
    next.accessibilityLabel = "切换到下一个键盘"
    next.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
    let header = UIStackView(arrangedSubviews: [connect, next])
    header.distribution = .fill
    connect.setContentHuggingPriority(.defaultLow, for: .horizontal)
    next.setContentHuggingPriority(.required, for: .horizontal)
    let root = UIStackView(arrangedSubviews: [header, statusLabel, summaryLabel, stack])
    root.axis = .vertical
    root.spacing = 6
    root.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(root)
    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
      root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
      header.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      view.heightAnchor.constraint(greaterThanOrEqualToConstant: 270),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    timer?.invalidate()
    timer = Timer.scheduledTimer(
      timeInterval: 1, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    refresh()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
    timer = nil
    disarm()
  }

  @objc private func connectSession() {
    var control = Control()
    control.keyboardHeartbeat = Date()
    control.armedUntil = Date().addingTimeInterval(10 * 60)
    do {
      try SharedStore.write(control, to: SharedFile.control)
      connectedSession = control.session
      renderedContextID = ""
      statusLabel.text = "已连接 10 分钟。切换联系人后请重新连接。"
      refresh()
    } catch { statusLabel.text = "无法访问共享容器。请检查完全访问、App Group 与签名。" }
  }

  @objc private func refresh() {
    guard var control = SharedStore.read(SharedFile.control, as: Control.self),
      connectedSession == control.session
    else {
      show(message: "未连接。请确认允许完全访问，然后连接当前会话。", payload: nil, contextID: "")
      return
    }
    control.keyboardHeartbeat = Date()
    do { try SharedStore.write(control, to: SharedFile.control) } catch {
      show(message: "心跳写入失败，分析已停止。", payload: nil, contextID: "")
      return
    }
    let state = SharedStore.state
    guard state.isFresh(control: control) else {
      show(message: state.message, payload: nil, contextID: "")
      return
    }
    show(message: state.message, payload: state.payload, contextID: state.contextID)
  }

  private func show(message: String, payload: SuggestionPayload?, contextID: String) {
    statusLabel.text = message
    statusLabel.textColor = payload == nil ? .secondaryLabel : .systemGreen
    summaryLabel.text = payload.map { "上下文提示：\($0.summary)" } ?? ""
    renderedContextID = contextID
    for view in stack.arrangedSubviews {
      view.removeFromSuperview()
    }
    for (index, candidate) in (payload?.replies ?? []).enumerated() {
      var config = UIButton.Configuration.tinted()
      config.title = "\(index + 1). \(candidate.text)"
      config.subtitle = candidate.translation.isEmpty ? nil : "中译：\(candidate.translation)"
      config.titleLineBreakMode = .byTruncatingTail
      config.titleAlignment = .leading
      config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
      let button = UIButton(configuration: config)
      button.tag = index
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
      button.accessibilityLabel = "候选回复 \(index + 1)：\(candidate.text)"
      button.accessibilityHint = "双击填入输入框，不会自动发送"
      button.addTarget(self, action: #selector(insertCandidate(_:)), for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
  }

  @objc private func insertCandidate(_ sender: UIButton) {
    guard let control = SharedStore.read(SharedFile.control, as: Control.self),
      control.session == connectedSession
    else {
      statusLabel.text = "会话已变化，请重新连接。"
      return
    }
    let current = SharedStore.state
    guard current.isFresh(control: control), current.contextID == renderedContextID,
      let replies = current.payload?.replies, replies.indices.contains(sender.tag)
    else {
      show(message: "候选已变化或过期，请等待刷新后再选。", payload: nil, contextID: "")
      return
    }
    textDocumentProxy.insertText(replies[sender.tag].text)
    statusLabel.text = "已填入输入框；请核对并手动点击发送。"
  }

  private func disarm() {
    guard var control = SharedStore.read(SharedFile.control, as: Control.self),
      control.session == connectedSession
    else { return }
    control.armedUntil = .distantPast
    control.keyboardHeartbeat = .distantPast
    try? SharedStore.write(control, to: SharedFile.control)
  }
}
