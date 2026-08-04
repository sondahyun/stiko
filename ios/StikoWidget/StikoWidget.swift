import WidgetKit
import SwiftUI
import AppIntents

// Must match WidgetService.appGroupId on the Flutter side.
private let appGroupId = "group.io.github.sondahyun.stiko"
private let widgetKind = "StikoWidget"
private let inkColor = Color(red: 0.43, green: 0.37, blue: 0.09)

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
private func resolve(stickerId: String?) -> (title: String?, key: String, todos: [TodoItem]) {
  guard let sid = stickerId else { return (nil, "all", loadTodos()) }
  guard let s = loadStickers().first(where: { $0.id == sid }) else { return (nil, sid, []) }
  return (s.name.isEmpty ? nil : s.name, sid, s.todos)
}

/// The paging offset stored per sticker key, so each widget browses independently.
private func loadPage(key: String) -> Int {
  UserDefaults(suiteName: appGroupId)?.integer(forKey: "page_\(key)") ?? 0
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

// MARK: - Interactive intents (iOS 17+)

/// Flips a todo's done state in place (strikethrough), and records it as pending
/// so the app persists the change to the cloud on its next resume.
struct ToggleTodoIntent: AppIntent {
  static var title: LocalizedStringResource = "할 일 완료"

  @Parameter(title: "id")
  var id: String

  init() {}
  init(id: String) { self.id = id }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: appGroupId)
    var newDone = true

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

/// iOS widgets can't scroll, so this pages the list on tap instead. Stores the
/// target page for the widget's sticker key and reloads.
struct PageIntent: AppIntent {
  static var title: LocalizedStringResource = "페이지 이동"

  @Parameter(title: "key")
  var key: String
  @Parameter(title: "page")
  var page: Int

  init() {}
  init(key: String, page: Int) { self.key = key; self.page = page }

  func perform() async throws -> some IntentResult {
    UserDefaults(suiteName: appGroupId)?.set(max(0, page), forKey: "page_\(key)")
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    return .result()
  }
}

// MARK: - Timeline

struct StikoEntry: TimelineEntry {
  let date: Date
  let title: String?
  let key: String
  let page: Int
  let todos: [TodoItem]
}

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> StikoEntry {
    StikoEntry(date: Date(), title: nil, key: "all", page: 0,
               todos: [TodoItem(id: "1", content: "할 일 미리보기", done: false)])
  }

  func snapshot(for configuration: SelectStickerIntent, in context: Context) async -> StikoEntry {
    let r = resolve(stickerId: configuration.sticker?.id)
    return StikoEntry(date: Date(), title: r.title, key: r.key,
                      page: loadPage(key: r.key), todos: r.todos)
  }

  func timeline(for configuration: SelectStickerIntent, in context: Context) async -> Timeline<StikoEntry> {
    let r = resolve(stickerId: configuration.sticker?.id)
    let entry = StikoEntry(date: Date(), title: r.title, key: r.key,
                           page: loadPage(key: r.key), todos: r.todos)
    return Timeline(entries: [entry], policy: .atEnd)
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
    case .systemSmall: return 3
    case .systemMedium: return 5
    case .systemLarge: return 12
    case .accessoryRectangular: return 3
    default: return 3
    }
  }

  private var pageCount: Int {
    max(1, Int(ceil(Double(entry.todos.count) / Double(limit))))
  }

  private var page: Int { min(max(0, entry.page), pageCount - 1) }

  private var slice: [TodoItem] {
    let start = page * limit
    let end = min(entry.todos.count, start + limit)
    guard start < end else { return [] }
    return Array(entry.todos[start ..< end])
  }

  // Paging controls make sense only where there's room (home screen sizes).
  private var canPage: Bool {
    pageCount > 1 && family != .accessoryRectangular
  }

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
          ForEach(slice) { todo in
            TodoRow(todo: todo)
          }
        }
        Spacer(minLength: 0)
        // Paging controls pinned to the bottom center. iOS widgets can't
        // scroll, so these step through a long list on tap. Both arrows stay
        // visible (dimmed at the ends) so the page number stays centered.
        if canPage {
          HStack(spacing: 12) {
            if page > 0 {
              Button(intent: PageIntent(key: entry.key, page: page - 1)) {
                Image(systemName: "chevron.left").font(.caption)
              }
              .buttonStyle(.plain)
            } else {
              Image(systemName: "chevron.left").font(.caption).foregroundStyle(.tertiary)
            }
            Text("\(page + 1)/\(pageCount)")
              .font(.caption2)
              .foregroundStyle(.secondary)
            if page < pageCount - 1 {
              Button(intent: PageIntent(key: entry.key, page: page + 1)) {
                Image(systemName: "chevron.right").font(.caption)
              }
              .buttonStyle(.plain)
            } else {
              Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .center)
        }
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
        .widgetURL(entry.key == "all"
                   ? URL(string: "stiko://board")
                   : URL(string: "stiko://sticker/\(entry.key)"))
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
