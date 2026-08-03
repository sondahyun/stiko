import WidgetKit
import SwiftUI
import AppIntents

// Must match WidgetService.appGroupId on the Flutter side.
private let appGroupId = "group.io.github.sondahyun.stiko"
private let widgetKind = "StikoWidget"

// MARK: - Data

struct TodoItem: Identifiable {
  let id: String
  let content: String
}

private func loadTodos() -> [TodoItem] {
  let defaults = UserDefaults(suiteName: appGroupId)
  guard let raw = defaults?.string(forKey: "todos"),
        let data = raw.data(using: .utf8),
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: String]]
  else { return [] }
  return arr.compactMap { d in
    guard let id = d["id"], let content = d["content"] else { return nil }
    return TodoItem(id: id, content: content)
  }
}

// MARK: - Toggle intent (interactive, iOS 17+)

@available(iOS 17.0, *)
struct ToggleTodoIntent: AppIntent {
  static var title: LocalizedStringResource = "할 일 완료"

  @Parameter(title: "id")
  var id: String

  init() {}
  init(id: String) { self.id = id }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: appGroupId)

    // Remove the tapped todo from the shared list so it disappears at once and
    // the remaining todos move up.
    if let raw = defaults?.string(forKey: "todos"),
       let data = raw.data(using: .utf8),
       var arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: String]] {
      arr.removeAll { $0["id"] == id }
      if let out = try? JSONSerialization.data(withJSONObject: arr),
         let str = String(data: out, encoding: .utf8) {
        defaults?.set(str, forKey: "todos")
      }
      defaults?.set(arr.count, forKey: "count")
    }

    // Remember it so the app persists the completion to the cloud next time it
    // is active.
    var pending: [String] = []
    if let raw = defaults?.string(forKey: "pending"),
       let data = raw.data(using: .utf8),
       let arr = (try? JSONSerialization.jsonObject(with: data)) as? [String] {
      pending = arr
    }
    if !pending.contains(id) { pending.append(id) }
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
  let todos: [TodoItem]
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> StikoEntry {
    StikoEntry(date: Date(), todos: [TodoItem(id: "1", content: "할 일 미리보기")])
  }

  func getSnapshot(in context: Context, completion: @escaping (StikoEntry) -> Void) {
    completion(StikoEntry(date: Date(), todos: loadTodos()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StikoEntry>) -> Void) {
    completion(Timeline(entries: [StikoEntry(date: Date(), todos: loadTodos())], policy: .atEnd))
  }
}

// MARK: - Views

struct TodoRow: View {
  let todo: TodoItem

  var body: some View {
    HStack(spacing: 8) {
      if #available(iOS 17.0, *) {
        Button(intent: ToggleTodoIntent(id: todo.id)) {
          Image(systemName: "circle")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      } else {
        Image(systemName: "circle")
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
      }
      Text(todo.content)
        .font(.footnote)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}

struct StikoWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  var entry: Provider.Entry

  private var limit: Int {
    switch family {
    case .systemMedium: return 6
    case .accessoryRectangular: return 2
    default: return 3
    }
  }

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(entry.todos.first?.content ?? "할 일 없음")

    case .accessoryCircular:
      VStack(spacing: 0) {
        Text("\(entry.todos.count)").font(.headline)
        Text("할일").font(.system(size: 9))
      }

    default:
      VStack(alignment: .leading, spacing: 5) {
        if entry.todos.isEmpty {
          Text("할 일 없음")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(entry.todos.prefix(limit)) { todo in
            TodoRow(todo: todo)
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
    StaticConfiguration(kind: widgetKind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        StikoWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        StikoWidgetEntryView(entry: entry)
          .padding()
      }
    }
    .configurationDisplayName("stiko 할 일")
    .description("할 일을 보고 눌러서 완료합니다.")
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .systemSmall,
      .systemMedium,
    ])
  }
}
