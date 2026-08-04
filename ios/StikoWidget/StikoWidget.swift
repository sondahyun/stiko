import WidgetKit
import SwiftUI
import AppIntents

// Must match WidgetService.appGroupId on the Flutter side.
private let appGroupId = "group.io.github.sondahyun.stiko"
private let widgetKind = "StikoWidget"
private let inkColor = Color(red: 0.43, green: 0.37, blue: 0.09)
// Tapping the widget body (not a checkbox) opens the app via this scheme.
private let openURL = URL(string: "stiko://open")

// MARK: - Data

struct TodoItem: Identifiable {
  let id: String
  let content: String
  let done: Bool
}

struct StickerData {
  let id: String
  let name: String
  let todos: [TodoItem]
}

private func parseTodos(_ raw: [[String: Any]]) -> [TodoItem] {
  raw.compactMap { d in
    guard let id = d["id"] as? String, let content = d["content"] as? String else { return nil }
    return TodoItem(id: id, content: content, done: (d["done"] as? Bool) ?? false)
  }
}

/// The globally filtered todo list (respects the in-app "widget stickers" setting).
private func loadTodos() -> [TodoItem] {
  let defaults = UserDefaults(suiteName: appGroupId)
  guard let raw = defaults?.string(forKey: "todos"),
        let data = raw.data(using: .utf8),
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
  else { return [] }
  return parseTodos(arr)
}

/// Every sticker with its own todos, so each widget can show a different one.
private func loadStickers() -> [StickerData] {
  let defaults = UserDefaults(suiteName: appGroupId)
  guard let raw = defaults?.string(forKey: "stickers"),
        let data = raw.data(using: .utf8),
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
  else { return [] }
  return arr.compactMap { d in
    guard let id = d["id"] as? String else { return nil }
    let name = (d["name"] as? String) ?? ""
    let todos = parseTodos((d["todos"] as? [[String: Any]]) ?? [])
    return StickerData(id: id, name: name, todos: todos)
  }
}

/// Resolves what a widget should show given its configured sticker id.
/// nil id means "all" and falls back to the globally filtered list.
private func resolve(stickerId: String?) -> (title: String?, todos: [TodoItem]) {
  guard let sid = stickerId else { return (nil, loadTodos()) }
  guard let s = loadStickers().first(where: { $0.id == sid }) else { return (nil, []) }
  return (s.name.isEmpty ? nil : s.name, s.todos)
}

// MARK: - Sticker picker (widget configuration)

struct StickerEntity: AppEntity {
  let id: String
  let name: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "스티커"
  static var defaultQuery = StickerQuery()

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name.isEmpty ? "제목 없음" : name)")
  }
}

struct StickerQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [StickerEntity] {
    loadStickers()
      .filter { identifiers.contains($0.id) }
      .map { StickerEntity(id: $0.id, name: $0.name) }
  }

  func suggestedEntities() async throws -> [StickerEntity] {
    loadStickers().map { StickerEntity(id: $0.id, name: $0.name) }
  }
}

struct SelectStickerIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "스티커 선택"
  static var description = IntentDescription("이 위젯에 표시할 스티커를 고릅니다. 비워두면 전체(설정에서 고른 스티커)를 표시합니다.")

  @Parameter(title: "스티커")
  var sticker: StickerEntity?

  init() {}
  init(sticker: StickerEntity?) { self.sticker = sticker }
}

// MARK: - Toggle intent (interactive, iOS 17+)

struct ToggleTodoIntent: AppIntent {
  static var title: LocalizedStringResource = "할 일 완료"

  @Parameter(title: "id")
  var id: String

  init() {}
  init(id: String) { self.id = id }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: appGroupId)
    var newDone = true

    // Flip the tapped todo in the flat list so it gets (or loses) a
    // strikethrough in place instead of disappearing.
    if let raw = defaults?.string(forKey: "todos"),
       let data = raw.data(using: .utf8),
       var arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      for i in arr.indices where (arr[i]["id"] as? String) == id {
        newDone = !((arr[i]["done"] as? Bool) ?? false)
        arr[i]["done"] = newDone
      }
      if let out = try? JSONSerialization.data(withJSONObject: arr),
         let str = String(data: out, encoding: .utf8) {
        defaults?.set(str, forKey: "todos")
      }
    }

    // Mirror the flip into the per-sticker breakdown too.
    if let raw = defaults?.string(forKey: "stickers"),
       let data = raw.data(using: .utf8),
       var stickers = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      for i in stickers.indices {
        if var todos = stickers[i]["todos"] as? [[String: Any]] {
          for j in todos.indices where (todos[j]["id"] as? String) == id {
            newDone = !((todos[j]["done"] as? Bool) ?? false)
            todos[j]["done"] = newDone
          }
          stickers[i]["todos"] = todos
        }
      }
      if let out = try? JSONSerialization.data(withJSONObject: stickers),
         let str = String(data: out, encoding: .utf8) {
        defaults?.set(str, forKey: "stickers")
      }
    }

    // Record the change so the app persists it to the cloud on its next resume.
    var pending: [[String: Any]] = []
    if let raw = defaults?.string(forKey: "pending"),
       let data = raw.data(using: .utf8),
       let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      pending = arr.filter { ($0["id"] as? String) != id }
    }
    pending.append(["id": id, "done": newDone])
    if let out = try? JSONSerialization.data(withJSONObject: pending),
       let str = String(data: out, encoding: .utf8) {
      defaults?.set(str, forKey: "pending")
    }

    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    return .result()
  }
}

// MARK: - Timeline

struct StikoEntry: TimelineEntry {
  let date: Date
  let title: String?
  let todos: [TodoItem]
}

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> StikoEntry {
    StikoEntry(date: Date(), title: nil,
               todos: [TodoItem(id: "1", content: "할 일 미리보기", done: false)])
  }

  func snapshot(for configuration: SelectStickerIntent, in context: Context) async -> StikoEntry {
    let r = resolve(stickerId: configuration.sticker?.id)
    return StikoEntry(date: Date(), title: r.title, todos: r.todos)
  }

  func timeline(for configuration: SelectStickerIntent, in context: Context) async -> Timeline<StikoEntry> {
    let r = resolve(stickerId: configuration.sticker?.id)
    return Timeline(entries: [StikoEntry(date: Date(), title: r.title, todos: r.todos)], policy: .atEnd)
  }
}

// MARK: - Views

struct TodoRow: View {
  let todo: TodoItem

  var body: some View {
    HStack(spacing: 8) {
      Button(intent: ToggleTodoIntent(id: todo.id)) {
        Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 15))
          .foregroundStyle(todo.done ? inkColor : Color.secondary)
      }
      .buttonStyle(.plain)
      Text(todo.content)
        .font(.footnote)
        .strikethrough(todo.done)
        .foregroundStyle(todo.done ? Color.secondary : Color.primary)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}

struct StikoWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  var entry: Provider.Entry

  private var openCount: Int { entry.todos.filter { !$0.done }.count }

  private var limit: Int {
    switch family {
    case .systemSmall: return 4
    case .systemMedium: return 5
    case .systemLarge: return 12
    case .accessoryRectangular: return 2
    default: return 3
    }
  }

  private var overflow: Int { max(0, entry.todos.count - limit) }

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(entry.todos.first(where: { !$0.done })?.content ?? "할 일 없음")

    case .accessoryCircular:
      VStack(spacing: 0) {
        Text("\(openCount)").font(.headline)
        Text("할일").font(.system(size: 9))
      }

    default:
      VStack(alignment: .leading, spacing: 4) {
        if let title = entry.title, family != .accessoryRectangular {
          Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(inkColor)
            .lineLimit(1)
        }
        if entry.todos.isEmpty {
          Text("할 일 없음")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(entry.todos.prefix(limit)) { todo in
            TodoRow(todo: todo)
          }
          // iOS widgets can't scroll, so surface how many more remain; tapping
          // the widget body opens the app to see the full list.
          if overflow > 0 {
            Text("+\(overflow)개 더")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}

@main
struct StikoWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: widgetKind,
      intent: SelectStickerIntent.self,
      provider: Provider()
    ) { entry in
      StikoWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(openURL)
    }
    .configurationDisplayName("stiko 할 일")
    .description("할 일을 보고 눌러서 완료합니다. 길게 눌러 위젯을 편집하면 스티커를 고를 수 있어요.")
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .systemSmall,
      .systemMedium,
      .systemLarge,
    ])
  }
}
