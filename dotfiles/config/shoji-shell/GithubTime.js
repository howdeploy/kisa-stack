.pragma library

function unit(value, forms) {
    const hundred = value % 100;
    const ten = value % 10;
    return value + " " + forms[hundred >= 11 && hundred <= 14 ? 2 : ten === 1 ? 0 : ten >= 2 && ten <= 4 ? 1 : 2];
}

function ago(timestamp, now) {
    const date = Date.parse(timestamp);
    if (!isFinite(date)) return "—";
    let minutes = Math.max(0, Math.floor((now - date) / 60000));
    if (!minutes) return "только что";
    const days = Math.floor(minutes / 1440);
    const hours = Math.floor(minutes % 1440 / 60);
    minutes %= 60;
    const parts = [];
    if (days) parts.push(unit(days, ["день", "дня", "дней"]));
    if (hours) parts.push(unit(hours, ["час", "часа", "часов"]));
    if (!days && minutes) parts.push(unit(minutes, ["минуту", "минуты", "минут"]));
    return parts.join(" и ") + " назад";
}
