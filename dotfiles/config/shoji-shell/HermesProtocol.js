// JSON-RPC over Hermes's native tui_gateway.entry stdio transport.
function decode(line) {
    var frame;
    try { frame = JSON.parse(line); } catch (_) { return null; }
    if (!frame || frame.jsonrpc !== "2.0") return null;
    if (frame.method === "event" && frame.params && typeof frame.params.type === "string") {
        return { kind: "event", type: frame.params.type,
            session: frame.params.session_id || "", payload: frame.params.payload || {} };
    }
    if (typeof frame.id === "number" && (frame.result || frame.error))
        return { kind: "reply", id: frame.id, result: frame.result || {}, error: frame.error || null };
    return null;
}

function request(id, method, params) {
    return JSON.stringify({ jsonrpc: "2.0", id: id, method: method, params: params }) + "\n";
}

function text(value) { return typeof value === "string" ? value : ""; }

function sessionFor(chats, sessionId) {
    return sessionId ? chats.find(function(chat) { return chat.sessionId === sessionId; }) || null : null;
}

function questions(type, payload) {
    if (!payload || typeof payload.request_id !== "string") return [];
    if (type === "clarify.request") {
        var entries = Array.isArray(payload.questions) ? payload.questions : [payload];
        return entries.map(function(q) {
            return { type: type, id: payload.request_id, qid: text(q.qid),
                title: text(q.question), detail: Array.isArray(q.choices) ? q.choices.join(" · ") : "",
                secret: false, choices: [] };
        });
    }
    if (type === "approval.request") {
        return [{ type: type, id: payload.request_id, qid: "", title: "Разрешить действие?",
            detail: [text(payload.description), text(payload.command)].filter(Boolean).join("\n"),
            secret: false, choices: Array.isArray(payload.choices) ? payload.choices : ["once", "deny"] }];
    }
    if (type === "secret.request" || type === "sudo.request") {
        return [{ type: type, id: payload.request_id, qid: "",
            title: text(payload.prompt) || (type === "sudo.request" ? "Пароль sudo" : "Секрет"),
            detail: text(payload.env_var), secret: true, choices: [] }];
    }
    return [];
}

function response(question, value, session) {
    var params = { session_id: session, request_id: question.id };
    var key = question.type === "approval.request" ? "choice"
        : question.type === "sudo.request" ? "password"
        : question.type === "secret.request" ? "value" : "answer";
    params[key] = value;
    if (question.qid) params.question_id = question.qid;
    return { method: question.type.replace(/\.request$/, ".respond"), params: params };
}

// Optional offline protocol check; no process, credentials or model calls.
function selfCheck() {
    function check(ok) { if (!ok) throw new Error("Hermes protocol check failed"); }
    check(decode("not json") === null);
    var chats = [{ sessionId: "one" }, { sessionId: "two" }];
    check(sessionFor(chats, "two") === chats[1]);
    check(sessionFor(chats, "missing") === null && sessionFor(chats, "") === null);
    var input = 'quote " and newline\n';
    check(JSON.parse(request(1, "prompt.submit", { text: input })).params.text === input);
    check(decode('{"jsonrpc":"2.0","id":1,"error":{"code":1}}').error.code === 1);
    check(decode('{"jsonrpc":"2.0","method":"event","params":{"type":"message.delta","session_id":"s","payload":{"text":"Hi"}}}').session === "s");
    var batch = questions("clarify.request", { request_id: "q", questions: [{ qid: "a", question: "A?" }, { qid: "b", question: "B?" }] });
    check(batch.length === 2 && response(batch[1], "yes", "s").params.question_id === "b");
    var approval = questions("approval.request", { request_id: "p", command: "example", choices: ["deny"] })[0];
    check(approval.choices.indexOf("once") === -1 && response(approval, "deny", "s").params.choice === "deny");
}
