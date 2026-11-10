
//
//  ContentView.swift
//  Calendar UI
//
//  Created by Cruz Ng Kai Lun on 10/11/26.
//

import SwiftUI

// MARK: - App Theme

extension Color {
    static let appBackground = Color(
        red: 0.965, green: 0.953, blue: 1.0
    )

    static let appPurple = Color(
        red: 0.46, green: 0.39, blue: 0.85
    )

    static let appLavender = Color(
        red: 0.91, green: 0.87, blue: 1.0
    )

    static let appText = Color(
        red: 0.16, green: 0.14, blue: 0.24
    )

    static let appSecondary = Color(
        red: 0.52, green: 0.49, blue: 0.62
    )
}

// MARK: - Event Categories

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case school = "School"
    case personal = "Personal"
    case work = "Work"
    case other = "Other"

    var id: String { rawValue }

    var colour: Color {
        switch self {
        case .school: return .appPurple
        case .personal: return .teal
        case .work: return .orange
        case .other: return .pink
        }
    }

    var icon: String {
        switch self {
        case .school: return "book.closed.fill"
        case .personal: return "heart.fill"
        case .work: return "briefcase.fill"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Event Model

struct CalendarEvent: Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var category: EventCategory

    // New properties
    var duration: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        category: EventCategory,
        duration: Int = 60,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.category = category
        self.duration = duration
        self.isCompleted = isCompleted
    }

    // Supports events saved by the previous app version
    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        id = try container.decode(
            UUID.self, forKey: .id
        )

        title = try container.decode(
            String.self, forKey: .title
        )

        date = try container.decode(
            Date.self, forKey: .date
        )

        category = try container.decodeIfPresent(
            EventCategory.self, forKey: .category
        ) ?? .personal

        duration = try container.decodeIfPresent(
            Int.self, forKey: .duration
        ) ?? 60

        isCompleted = try container.decodeIfPresent(
            Bool.self, forKey: .isCompleted
        ) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, title, date, category
        case duration, isCompleted
    }

    var endDate: Date {
        date.addingTimeInterval(
            TimeInterval(duration * 60)
        )
    }
}

// MARK: - Main View

struct ContentView: View {

    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var events: [CalendarEvent] = []

    @State private var showingAddEvent = false
    @State private var draftDate = Date()

    private let calendar = Calendar.current

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    // MARK: - Calendar Calculations

    private var monthTitle: String {
        displayedMonth.formatted(
            .dateTime.month(.wide).year()
        )
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1

        return Array(symbols[offset...])
            + Array(symbols[..<offset])
    }

    private var daysInMonth: [Date?] {
        guard let interval = calendar.dateInterval(
            of: .month,
            for: displayedMonth
        ),
        let range = calendar.range(
            of: .day,
            in: .month,
            for: displayedMonth
        ) else {
            return []
        }

        let firstDay = interval.start

        let weekday = calendar.component(
            .weekday,
            from: firstDay
        )

        let spaces = (
            weekday - calendar.firstWeekday + 7
        ) % 7

        var days: [Date?] = Array(
            repeating: nil,
            count: spaces
        )

        for day in range {
            if let date = calendar.date(
                byAdding: .day,
                value: day - 1,
                to: firstDay
            ) {
                days.append(date)
            }
        }

        return days
    }

    private var selectedDayEvents: [CalendarEvent] {
        events
            .filter {
                calendar.isDate(
                    $0.date,
                    inSameDayAs: selectedDate
                )
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - FEATURE 1: Smart Slot Finder

    // Finds available 60-minute slots between 9 AM and 8 PM.
    // It considers all event times and durations.

    private var suggestedSlots: [Date] {
        guard let dayStart = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: selectedDate
        ),
        let dayEnd = calendar.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: selectedDate
        ) else {
            return []
        }

        let slotDuration: TimeInterval = 60 * 60
        let step: TimeInterval = 30 * 60

        var suggestions: [Date] = []
        var candidate = dayStart

        while candidate.addingTimeInterval(
            slotDuration
        ) <= dayEnd {

            let candidateEnd = candidate.addingTimeInterval(
                slotDuration
            )

            let hasConflict = events.contains { event in
                candidate < event.endDate
                && candidateEnd > event.date
            }

            if !hasConflict {
                // Skip slots already in the past
                if !calendar.isDateInToday(selectedDate)
                    || candidate >= Date() {
                    suggestions.append(candidate)
                }
            }

            candidate = candidate.addingTimeInterval(step)
        }

        return Array(suggestions.prefix(3))
    }

    // MARK: - FEATURE 2: Daily Momentum

    private var completedCount: Int {
        selectedDayEvents.filter {
            $0.isCompleted
        }.count
    }

    private var progress: Double {
        guard !selectedDayEvents.isEmpty else {
            return 0
        }

        return Double(completedCount)
            / Double(selectedDayEvents.count)
    }

    // MARK: - Main Layout

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    welcomeCard

                    calendarCard

                    momentumCard

                    smartSlotCard

                    scheduleSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialDate: draftDate) { event in
                events.append(event)
                saveEvents()
            }
        }
        .onAppear {
            loadEvents()
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Text("MY PERSONAL PLANNER")
                    .font(.system(
                        size: 11,
                        weight: .bold,
                        design: .rounded
                    ))
                    .tracking(2)

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3)
            }
            .foregroundStyle(.white.opacity(0.85))

            Text("Make today count.")
                .font(.system(
                    size: 29,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(.white)

            Text("A little progress, every day.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Label(
                Date().formatted(
                    .dateTime.weekday(.wide)
                        .day()
                        .month(.wide)
                ),
                systemImage: "calendar"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            .appPurple,
                            Color(
                                red: 0.67,
                                green: 0.57,
                                blue: 0.95
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(
            color: .appPurple.opacity(0.18),
            radius: 18,
            y: 8
        )
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 20) {

            HStack {
                Text(monthTitle)
                    .font(.system(
                        size: 21,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.appText)

                Spacer()

                monthButton("chevron.left", -1)
                monthButton("chevron.right", 1)
            }

            HStack(spacing: 4) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        dayCell(date)
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }

            Button {
                withAnimation {
                    selectedDate = Date()
                    displayedMonth = Date()
                }
            } label: {
                Label(
                    "Jump to Today",
                    systemImage: "arrow.uturn.backward"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color.appLavender.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
        }
        .padding(20)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func monthButton(
        _ icon: String,
        _ amount: Int
    ) -> some View {
        Button {
            changeMonth(by: amount)
        } label: {
            Image(systemName: icon)
                .font(.system(
                    size: 13,
                    weight: .bold
                ))
                .foregroundStyle(Color.appPurple)
                .frame(width: 34, height: 34)
                .background(
                    Color.appLavender.opacity(0.5),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = calendar.isDate(
            date, inSameDayAs: selectedDate
        )

        let today = calendar.isDateInToday(date)

        let hasEvents = events.contains {
            calendar.isDate(
                $0.date, inSameDayAs: date
            )
        }

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(
                        size: 15,
                        weight: selected ? .bold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        selected ? .white : Color.appText
                    )
                    .frame(width: 36, height: 36)
                    .background {
                        if selected {
                            Circle().fill(Color.appPurple)
                        } else if today {
                            Circle()
                                .stroke(
                                    Color.appPurple,
                                    lineWidth: 1.5
                                )
                        }
                    }

                Circle()
                    .fill(
                        hasEvents
                        ? Color.appPurple
                        : Color.clear
                    )
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Momentum Card

    private var momentumCard: some View {
        HStack(spacing: 16) {

            VStack(alignment: .leading, spacing: 9) {

                Label(
                    "DAILY MOMENTUM",
                    systemImage: "chart.bar.fill"
                )
                .font(.system(
                    size: 11,
                    weight: .bold
                ))
                .tracking(1)
                .foregroundStyle(Color.appPurple)

                Text(
                    progress == 1 && !selectedDayEvents.isEmpty
                    ? "All done today!"
                    : "You're making progress!"
                )
                .font(.system(
                    size: 17,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(Color.appText)

                Text(
                    "\(completedCount) of \(selectedDayEvents.count) events completed"
                )
                .font(.caption)
                .foregroundStyle(Color.appSecondary)
            }

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .stroke(
                        Color.appLavender.opacity(0.65),
                        lineWidth: 9
                    )

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.appPurple,
                        style: StrokeStyle(
                            lineWidth: 9,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.system(
                        size: 17,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.appText)
            }
            .frame(width: 78, height: 78)
            .animation(
                .easeInOut(duration: 0.45),
                value: progress
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    // MARK: - Smart Slot Finder Card

    private var smartSlotCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.appPurple)

                Text("Smart Slot Finder")
                    .font(.system(
                        size: 18,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.appText)
            }

            Text(
                "Find the perfect time for your next activity."
            )
            .font(.subheadline)
            .foregroundStyle(Color.appSecondary)

            if suggestedSlots.isEmpty {
                Text("No free 60-minute slots found between 9 AM and 8 PM.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    ForEach(suggestedSlots, id: \.self) { slot in
                        Button {
                            openAddEvent(at: slot)
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: 7
                            ) {
                                Text(
                                    slot.formatted(
                                        date: .omitted,
                                        time: .shortened
                                    )
                                )
                                .font(.system(
                                    size: 15,
                                    weight: .bold
                                ))
                                .foregroundStyle(Color.appPurple)

                                Label(
                                    "60 minutes free",
                                    systemImage: "clock"
                                )
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appSecondary)
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(14)
                            .background(
                                Color.appLavender.opacity(0.45),
                                in: RoundedRectangle(
                                    cornerRadius: 14
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 15) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your Schedule")
                        .font(.system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(Color.appText)

                    Text(
                        selectedDate.formatted(
                            .dateTime.weekday(.wide)
                                .day()
                                .month(.wide)
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                }

                Spacer()

                Button {
                    openAddEvent()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(Color.appPurple)
                        .frame(width: 44, height: 44)
                        .background(
                            Color.appLavender,
                            in: Circle()
                        )
                }
                .accessibilityLabel("Add Event")
            }

            if selectedDayEvents.isEmpty {
                emptySchedule
            } else {
                ForEach(selectedDayEvents) { event in
                    eventCard(event)
                }
            }
        }
    }

    private var emptySchedule: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(Color.appPurple)

            Text("Nothing planned yet")
                .font(.headline)
                .foregroundStyle(Color.appText)

            Text("A fresh day full of possibilities.")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondary)

            Button("Add an Event") {
                openAddEvent()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.appPurple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    // MARK: - Event Card

    private func eventCard(
        _ event: CalendarEvent
    ) -> some View {
        HStack(spacing: 13) {

            Button {
                toggleCompletion(event)
            } label: {
                Image(
                    systemName: event.isCompleted
                    ? "checkmark.circle.fill"
                    : "circle"
                )
                .font(.system(size: 25))
                .foregroundStyle(
                    event.isCompleted
                    ? Color.teal
                    : Color.appLavender
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                event.isCompleted
                ? "Mark incomplete"
                : "Mark completed"
            )

            Image(systemName: event.category.icon)
                .font(.system(size: 18))
                .foregroundStyle(event.category.colour)
                .frame(width: 43, height: 43)
                .background(
                    event.category.colour.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(event.isCompleted)
                    .foregroundStyle(
                        event.isCompleted
                        ? Color.appSecondary
                        : Color.appText
                    )

                HStack(spacing: 5) {
                    Text(
                        event.date.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )

                    Text("·")

                    Text("\(event.duration) min")

                    Text("·")

                    Text(event.category.rawValue)
                }
                .font(.system(size: 10))
                .foregroundStyle(Color.appSecondary)
            }

            Spacer(minLength: 0)

            Button(role: .destructive) {
                deleteEvent(event)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Delete \(event.title)")
        }
        .padding(14)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 19)
        )
    }

    // MARK: - Actions

    private func openAddEvent(at date: Date? = nil) {
        if let date {
            draftDate = date
        } else {
            draftDate = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: selectedDate
            ) ?? selectedDate
        }

        showingAddEvent = true
    }

    private func toggleCompletion(
        _ event: CalendarEvent
    ) {
        guard let index = events.firstIndex(
            where: { $0.id == event.id }
        ) else {
            return
        }

        withAnimation(.easeInOut) {
            events[index].isCompleted.toggle()
        }

        saveEvents()
    }

    private func changeMonth(by amount: Int) {
        guard let newMonth = calendar.date(
            byAdding: .month,
            value: amount,
            to: displayedMonth
        ) else {
            return
        }

        withAnimation {
            displayedMonth = newMonth

            if let firstDay = calendar.dateInterval(
                of: .month,
                for: newMonth
            )?.start {
                selectedDate = firstDay
            }
        }
    }

    private func deleteEvent(_ event: CalendarEvent) {
        withAnimation {
            events.removeAll { $0.id == event.id }
        }

        saveEvents()
    }

    // MARK: - Local Storage

    private func saveEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(
                data,
                forKey: "aestheticCalendarEvents"
            )
        }
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(
            forKey: "aestheticCalendarEvents"
        ),
        let saved = try? JSONDecoder().decode(
            [CalendarEvent].self,
            from: data
        ) else {
            return
        }

        events = saved
    }
}

// MARK: - Add Event Screen

struct AddEventView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date: Date
    @State private var category: EventCategory = .personal
    @State private var duration = 60

    let onSave: (CalendarEvent) -> Void

    init(
        initialDate: Date,
        onSave: @escaping (CalendarEvent) -> Void
    ) {
        _date = State(initialValue: initialDate)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 23) {

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            Text("Something exciting?")
                                .font(.system(
                                    size: 25,
                                    weight: .bold,
                                    design: .rounded
                                ))
                                .foregroundStyle(Color.appText)

                            Text("Let's add it to your calendar.")
                                .foregroundStyle(Color.appSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("EVENT NAME")

                            TextField(
                                "What's the occasion?",
                                text: $title
                            )
                            .padding(17)
                            .background(
                                .white,
                                in: RoundedRectangle(
                                    cornerRadius: 16
                                )
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("DATE & TIME")

                            DatePicker(
                                "When?",
                                selection: $date,
                                displayedComponents: [
                                    .date,
                                    .hourAndMinute
                                ]
                            )
                            .tint(.appPurple)
                            .padding(16)
                            .background(
                                .white,
                                in: RoundedRectangle(
                                    cornerRadius: 16
                                )
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("DURATION")

                            Picker(
                                "Duration",
                                selection: $duration
                            ) {
                                Text("30 min").tag(30)
                                Text("60 min").tag(60)
                                Text("90 min").tag(90)
                                Text("120 min").tag(120)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("CATEGORY")

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 12
                            ) {
                                ForEach(
                                    EventCategory.allCases
                                ) { item in
                                    categoryButton(item)
                                }
                            }
                        }

                        Button {
                            saveEvent()
                        } label: {
                            Label(
                                "Create Event",
                                systemImage: "checkmark"
                            )
                            .font(.system(
                                size: 16,
                                weight: .bold
                            ))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(
                                title.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                                ? Color.gray
                                : Color.appPurple,
                                in: RoundedRectangle(
                                    cornerRadius: 18
                                )
                            )
                        }
                        .disabled(
                            title.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        )
                        .padding(.top, 12)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.appPurple)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func sectionTitle(
        _ text: String
    ) -> some View {
        Text(text)
            .font(.system(
                size: 12,
                weight: .bold
            ))
            .tracking(1.4)
            .foregroundStyle(Color.appSecondary)
    }

    private func categoryButton(
        _ item: EventCategory
    ) -> some View {
        let selected = category == item

        return Button {
            withAnimation {
                category = item
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .foregroundStyle(item.colour)

                Text(item.rawValue)
                    .foregroundStyle(Color.appText)

                Spacer()

                if selected {
                    Image(
                        systemName: "checkmark.circle.fill"
                    )
                    .foregroundStyle(Color.appPurple)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(14)
            .background(
                selected
                ? Color.appLavender.opacity(0.5)
                : Color.white,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selected
                        ? Color.appPurple
                        : Color.clear,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func saveEvent() {
        let cleanedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedTitle.isEmpty else {
            return
        }

        let event = CalendarEvent(
            title: cleanedTitle,
            date: date,
            category: category,
            duration: duration
        )

        onSave(event)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
