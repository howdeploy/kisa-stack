function fortnight(today) {
    const monday = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12);
    monday.setDate(monday.getDate() - (monday.getDay() + 6) % 7);
    return Array.from({ length: 14 }, (_, i) =>
        new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i, 12));
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

function selfCheck() {
    const days = fortnight(new Date(2026, 11, 31, 23, 59));
    if (days.length !== 14 || days[0].getDay() !== 1 || days[13].getDay() !== 0
            || !sameDay(days[0], new Date(2026, 11, 28))
            || !sameDay(days[13], new Date(2027, 0, 10))) throw new Error("Year boundary");
    if (!fortnight(new Date(2028, 1, 29)).some(d => d.getMonth() === 1 && d.getDate() === 29))
        throw new Error("Leap day");
    if (sameDay(new Date(2026, 0, 1), new Date(2027, 0, 1))) throw new Error("Year identity");
}
